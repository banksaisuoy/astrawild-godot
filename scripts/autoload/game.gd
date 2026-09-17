extends Node
## Game — central run-state: time, weather, player survival, inventory,
## research, journal, quests, party roster. Also hosts the shared event bus.

signal stats_changed
signal inventory_changed
signal equipment_changed
signal weather_changed(state_id: String)
signal zone_changed(zone_id: String)
signal time_changed(day: int, minute: int)
signal toast(text: String, color: Color)
signal quest_changed
signal research_changed
signal journal_changed(species_id: String)
signal party_changed
signal capture_attempt(species_id: String, success: bool)
signal echo_defeated(species_id: String, loot: Array)
signal building_placed(building_id: String)
signal screen_requested(screen: String)
signal crafting_done(recipe_id: String)
signal game_saved
signal game_loaded

const MINUTES_PER_REAL_SECOND := 1.0
const MAX_PARTY := 3
const CAPTURE_COOLDOWN := 1.0
const TRUST_STAGES := [
        {"name": "Stranger", "min": 0.0},
        {"name": "Acquainted", "min": 10.0},
        {"name": "Familiar", "min": 30.0},
        {"name": "Trusted", "min": 50.0},
        {"name": "Bonded", "min": 70.0},
        {"name": "Partner", "min": 90.0},
]

# ---- world state ----
var world_seed: int = 1337
var day: int = 1
var time_minutes: float = 480.0
var weather_id: String = "Clear"
var weather_timer: float = 90.0
var current_zone_id: String = ""
var discovered_zones := {}

# ---- player survival ----
var hp: float = 100.0
var max_hp: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0
var hunger: float = 100.0
var thirst: float = 100.0
var temperature: float = 20.0
var dead := false
var respawn_timer := 0.0
var status_effects := {}   # id -> {remaining, dps, speed_mult}

# ---- inventory / equipment ----
var inventory := {}        # item_id -> qty
var equipment := {"weapon": "", "offhand": "", "body": "", "head": "", "tool": ""}
var carry_bonus := 0.0

# ---- progression ----
var research_points := 0
var unlocked_tech := {}
var journal := {}          # species_id -> {progress, milestones}
var quest_states := {}     # quest_id -> {objectives: [progress]}
var active_quest := ""
var completed_quests := {}
var god_mode := false      # cheat AW.God — damage disabled
var forced_weather := ""   # world-event / cheat override (Storm Surge etc.)

# ---- party ----
var party := []            # array of echo state dicts (active field team)
var echo_box := []         # benched echoes
var _capture_cooldown := 0.0

# ---- crafting ----
var craft_queue := []      # {recipe_id, remaining, station_pos}


func _enter_tree() -> void:
        _setup_input_actions()


func _ready() -> void:
        reset_run()


func reset_run() -> void:
        day = 1
        time_minutes = 480.0
        weather_id = "Clear"
        weather_timer = 90.0
        current_zone_id = ""
        discovered_zones = {}
        hp = 100.0
        stamina = 100.0
        hunger = 100.0
        thirst = 100.0
        temperature = 20.0
        dead = false
        status_effects = {}
        inventory = {"Item_Berry": 3, "Item_Resonator": 1}
        equipment = {"weapon": "", "offhand": "", "body": "", "head": "", "tool": ""}
        carry_bonus = 0.0
        research_points = 0
        unlocked_tech = {"Tech_BasicCrafting": true}
        journal = {}
        quest_states = {}
        active_quest = ""
        completed_quests = {}
        party = []
        echo_box = []
        craft_queue = []
        start_quest("Quest_FirstLight")


func _setup_input_actions() -> void:
        var map := {
                "move_forward": [KEY_W], "move_back": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
                "sprint": [KEY_SHIFT], "jump": [KEY_SPACE], "dodge": [KEY_Q],
                "interact": [KEY_E], "capture": [KEY_F], "feed": [KEY_G],
                "inventory": [KEY_I], "crafting": [KEY_C], "research": [KEY_R],
                "journal": [KEY_J], "build": [KEY_B], "map": [KEY_M], "pause": [KEY_ESCAPE],
                "mods": [KEY_F7],
                "party_follow": [KEY_1], "party_stay": [KEY_2], "party_attack": [KEY_3],
                "rotate_left": [KEY_COMMA], "rotate_right": [KEY_PERIOD],
                "ui_up": [KEY_UP], "ui_down": [KEY_DOWN], "ui_left": [KEY_LEFT], "ui_right": [KEY_RIGHT],
        }
        for action in map:
                if not InputMap.has_action(action):
                        InputMap.add_action(action)
                for key in map[action]:
                        var ev := InputEventKey.new()
                        ev.physical_keycode = key
                        InputMap.action_add_event(action, ev)
        var mouse_actions := {
                "light_attack": MOUSE_BUTTON_LEFT, "heavy_attack": MOUSE_BUTTON_RIGHT,
        }
        for action in mouse_actions:
                if not InputMap.has_action(action):
                        InputMap.add_action(action)
                var ev := InputEventMouseButton.new()
                ev.button_index = mouse_actions[action]
                InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
        _advance_clock(delta)
        _advance_weather(delta)
        _tick_survival(delta)
        _tick_status(delta)
        _tick_crafting(delta)
        if _capture_cooldown > 0.0:
                _capture_cooldown -= delta


# ------------------------------------------------------------------ clock --
func _advance_clock(delta: float) -> void:
        time_minutes += delta * MINUTES_PER_REAL_SECOND
        if time_minutes >= 1440.0:
                time_minutes -= 1440.0
                day += 1
        time_changed.emit(day, int(time_minutes))


func hour() -> float:
        return time_minutes / 60.0


func is_night() -> bool:
        var h := hour()
        return h < 5.5 or h >= 19.5


func clock_text() -> String:
        var h := int(time_minutes / 60.0)
        var m := int(time_minutes) % 60
        return "%02d:%02d" % [h, m]


# ---------------------------------------------------------------- weather --
func _advance_weather(delta: float) -> void:
        weather_timer -= delta * MINUTES_PER_REAL_SECOND
        if weather_timer <= 0.0:
                weather_timer = 90.0
                if forced_weather == "" or forced_weather == weather_id:
                        _roll_weather()
                else:
                        # world-event forced weather holds until the event ends
                        weather_id = forced_weather
                        weather_changed.emit(weather_id)


func _roll_weather() -> void:
        if forced_weather != "" and forced_weather != weather_id:
                weather_id = forced_weather
                weather_changed.emit(weather_id)
                return
        var states: Array = Data.weather_states
        var total := 0.0
        for w in states:
                var weight: float = w["weight"]
                if w["id"] == weather_id:
                        weight *= 0.25
                total += weight
        var roll := randf() * total
        for w in states:
                var weight: float = w["weight"]
                if w["id"] == weather_id:
                        weight *= 0.25
                roll -= weight
                if roll <= 0.0:
                        weather_id = w["id"]
                        weather_changed.emit(weather_id)
                        return


func weather() -> Dictionary:
        for w in Data.weather_states:
                if w["id"] == weather_id:
                        return w
        return {"id": "Clear", "temp": 0, "vis": 1.0}


func visibility() -> float:
        return weather().get("vis", 1.0)


# --------------------------------------------------------------- survival --
func _tick_survival(delta: float) -> void:
        if dead:
                respawn_timer -= delta
                if respawn_timer <= 0.0:
                        revive()
                return
        temperature = 20.0 + weather().get("temp", 0)
        # hunger / thirst decay (0.083/s)
        hunger = max(0.0, hunger - 0.083 * delta)
        thirst = max(0.0, thirst - 0.083 * delta)
        # starvation / dehydration damage
        var empty_vitals := 0
        if hunger <= 0.0:
                empty_vitals += 1
        if thirst <= 0.0:
                empty_vitals += 1
        if empty_vitals > 0:
                take_damage(1.5 * empty_vitals * delta, "None", false)
        # exposure damage
        if temperature <= 4.0 or temperature >= 36.0:
                take_damage(1.0 * delta, "None", false)
        stats_changed.emit()


func _tick_status(delta: float) -> void:
        var dirty := false
        for sid in status_effects.keys():
                var st: Dictionary = status_effects[sid]
                st["remaining"] = st.get("remaining", 0.0) - delta
                if st.get("dps", 0.0) > 0.0:
                        take_damage(st["dps"] * delta, "None", false)
                        dirty = true
                if st["remaining"] <= 0.0:
                        status_effects.erase(sid)
                        dirty = true
        if dirty:
                stats_changed.emit()


func apply_status(sid: String, duration: float, dps: float, speed_mult: float) -> void:
        if status_effects.has(sid):
                status_effects[sid]["remaining"] = duration
        else:
                status_effects[sid] = {"remaining": duration, "dps": dps, "speed_mult": speed_mult}


func status_speed_mult() -> float:
        var mult := 1.0
        for sid in status_effects:
                mult *= status_effects[sid].get("speed_mult", 1.0)
        return mult


func take_damage(amount: float, element: String = "None", check_dodge: bool = true) -> float:
        if dead or god_mode:
                return 0.0
        if check_dodge and get_meta("dodging", false):
                return 0.0
        var mitigated := amount
        if get_meta("blocking", false):
                var mit := 0.45
                if equipment["offhand"] != "" and Data.item(equipment["offhand"]).has("block"):
                        mit = Data.item(equipment["offhand"])["block"]
                mitigated = amount * (1.0 - clampf(mit, 0.0, 0.8))
        if element != "None" and _player_elemental(element) > 1.0:
                mitigated *= _player_elemental(element)
        mitigated -= armor_rating() * mitigated / (armor_rating() + 100.0)
        hp = max(0.0, hp - max(0.0, mitigated))
        if hp <= 0.0:
                die()
        stats_changed.emit()
        return max(0.0, mitigated)


func _player_elemental(_element: String) -> float:
        return 1.0  # player has no elemental resistance (matches UE5)


func armor_rating() -> float:
        var total := 0.0
        for slot in ["body", "head"]:
                if equipment[slot] != "":
                        total += Data.item(equipment[slot]).get("armor", 0)
        return total


func heal(amount: float) -> void:
        hp = minf(max_hp, hp + amount)
        stats_changed.emit()


func restore_stamina(amount: float) -> void:
        stamina = minf(max_stamina, stamina + amount)


func drain_stamina(amount: float) -> bool:
        if stamina < amount:
                return false
        stamina -= amount
        stats_changed.emit()
        return true


func full_restore() -> void:
        hp = max_hp
        stamina = max_stamina
        hunger = 100.0
        thirst = 100.0
        status_effects.clear()
        dead = false
        stats_changed.emit()


func die() -> void:
        if dead:
                return
        dead = true
        respawn_timer = 5.0
        # drop some loose resources on defeat
        for drop in [["Item_Wood", 2], ["Item_Stone", 2]]:
                var have: int = inventory.get(drop[0], 0)
                if have > 0:
                        inventory[drop[0]] = maxi(0, have - drop[1])
        inventory_changed.emit()
        toast.emit("You collapse... the dawn will wait.", Color(1, 0.4, 0.4))


func revive() -> void:
        full_restore()
        var player := get_tree().get_first_node_in_group("player")
        if player and player.has_method("respawn_at_camp"):
                player.respawn_at_camp()
        toast.emit("You wake at the campfire.", Color(1, 0.85, 0.6))


# -------------------------------------------------------------- inventory --
func add_item(id: String, qty: int = 1) -> void:
        inventory[id] = inventory.get(id, 0) + qty
        inventory_changed.emit()
        _notify_quest_counters("CollectItem", id)


func remove_item(id: String, qty: int = 1) -> bool:
        var have: int = inventory.get(id, 0)
        if have < qty:
                return false
        inventory[id] = have - qty
        if inventory[id] <= 0:
                inventory.erase(id)
        inventory_changed.emit()
        _notify_quest_counters("CollectItem", id)
        return true


func count_item(id: String) -> int:
        return inventory.get(id, 0)


func consume_item(id: String) -> bool:
        var def := Data.item(id)
        if def.is_empty() or not remove_item(id, 1):
                return false
        if def.has("food"):
                hunger = minf(100.0, hunger + def["food"])
        if def.has("water"):
                thirst = minf(100.0, thirst + def["water"])
        if def.has("heal"):
                heal(def["heal"])
        stats_changed.emit()
        toast.emit("Used %s" % def.get("name", id), Color(0.8, 1.0, 0.8))
        return true


func carry_weight() -> float:
        var w := 0.0
        for id in inventory:
                w += Data.item(id).get("weight", 0.0) * inventory[id]
        return w


func carry_limit() -> float:
        return 60.0 + carry_bonus


func equip(slot: String, id: String) -> void:
        if equipment[slot] == id:
                equipment[slot] = ""
        else:
                equipment[slot] = id
        carry_bonus = 0.0
        if equipment["body"] == "Item_DawnstriderExosuit":
                carry_bonus = 40.0
        equipment_changed.emit()
        stats_changed.emit()


func weapon_damage() -> int:
        var base := 0
        if equipment["weapon"] != "":
                base += int(Data.item(equipment["weapon"]).get("atk", 0))
        return base


func weapon_element() -> String:
        if equipment["weapon"] != "":
                return Data.item(equipment["weapon"]).get("element", "None")
        return "None"


func stamina_regen_rate() -> float:
        var rate := 14.0
        if equipment["body"] == "Item_DawnstriderExosuit":
                rate += 6.0
        for e in party:
                if e.get("passive") == "PlayerStamina":
                        rate += 2.0
        return rate


func speed_bonus() -> float:
        if equipment["body"] == "Item_DawnstriderExosuit":
                return 1.15
        return 1.0


# ---------------------------------------------------------------- crafting --
func can_craft(recipe: Dictionary) -> bool:
        if recipe["tech"] != null and not recipe["tech"] == "" and not unlocked_tech.has(recipe["tech"]):
                return false
        for inp in recipe["inputs"]:
                if count_item(inp["item"]) < inp["qty"]:
                        return false
        return true


func start_craft(recipe_id: String, station_pos: Vector3 = Vector3.ZERO) -> bool:
        var recipe: Dictionary
        for r in Data.recipes:
                if r["id"] == recipe_id:
                        recipe = r
                        break
        if recipe.is_empty() or not can_craft(recipe):
                return false
        for inp in recipe["inputs"]:
                remove_item(inp["item"], inp["qty"])
        craft_queue.append({"recipe_id": recipe_id, "remaining": recipe["time"], "station_pos": station_pos})
        return true


func _tick_crafting(delta: float) -> void:
        if craft_queue.is_empty():
                return
        var job: Dictionary = craft_queue[0]
        job["remaining"] -= delta
        if job["remaining"] <= 0.0:
                craft_queue.pop_front()
                var recipe: Dictionary
                for r in Data.recipes:
                        if r["id"] == job["recipe_id"]:
                                recipe = r
                                break
                for out in recipe["outputs"]:
                        add_item(out["item"], out["qty"])
                toast.emit("Crafted %s" % recipe["name"], Color(0.7, 0.95, 1.0))
                notify_event("CraftRecipe", recipe["id"])
                crafting_done.emit(recipe["id"])



# ---------------------------------------------------------------- research --
func add_research_points(amount: int) -> void:
        research_points += amount
        research_changed.emit()


func can_unlock_tech(tech_id: String) -> bool:
        var t: Dictionary = Data.techs.get(tech_id, {})
        if t.is_empty() or unlocked_tech.has(tech_id):
                return false
        for p in t.get("prereqs", []):
                if not unlocked_tech.has(p):
                        return false
        return research_points >= int(t.get("cost", 0))


func unlock_tech(tech_id: String) -> bool:
        if not can_unlock_tech(tech_id):
                return false
        research_points -= int(Data.techs[tech_id]["cost"])
        unlocked_tech[tech_id] = true
        toast.emit("Research complete: %s" % Data.techs[tech_id]["name"], Color(0.9, 0.8, 1.0))
        research_changed.emit()
        _notify_quest_counters("UnlockTechnology", tech_id)
        return true


func is_tech_unlocked(tech_id: String) -> bool:
        return unlocked_tech.has(tech_id)


func force_unlock_tech(tech_id: String) -> void:
        ## Dungeon-clear unique reward path (UE5 ForceUnlockTech — free, prereq-free, once).
        if unlocked_tech.has(tech_id):
                return
        unlocked_tech[tech_id] = true
        var t: Dictionary = Data.techs.get(tech_id, {})
        toast.emit("ANCIENT KNOWLEDGE — %s force-unlocked" % t.get("name", tech_id), Color(1.0, 0.85, 0.4))
        research_changed.emit()
        _notify_quest_counters("UnlockTechnology", tech_id)


# ------------------------------------------------------------------ journal --
func observe_progress(species_id: String) -> float:
        if journal.has(species_id):
                return journal[species_id]["progress"]
        return 0.0


func add_observation(species_id: String, delta_progress: float) -> void:
        if not journal.has(species_id):
                journal[species_id] = {"progress": 0.0, "milestones": [false, false, false, false]}
        var j: Dictionary = journal[species_id]
        j["progress"] = minf(100.0, j["progress"] + delta_progress)
        _check_milestones(species_id)


func _check_milestones(species_id: String) -> void:
        var j: Dictionary = journal[species_id]
        var p: float = j["progress"]
        var thresholds := [25.0, 50.0, 75.0, 100.0]
        var texts := [
                "scanned — added to the field journal",
                "food discovered",
                "weakness discovered",
                "habitat discovered",
        ]
        for i in 4:
                if not j["milestones"][i] and p >= thresholds[i]:
                        j["milestones"][i] = true
                        add_research_points(2)
                        var sname: String = Data.species_def(species_id).get("name", species_id)
                        toast.emit("%s: %s (+2 RP)" % [sname, texts[i]], Color(0.75, 0.9, 1.0))
                        if i == 0:
                                notify_event("ObserveEcho", species_id)
        journal_changed.emit(species_id)


func journal_bonus(species_id: String) -> float:
        # +15% capture chance at full observation
        if observe_progress(species_id) >= 100.0:
                return 0.15
        return 0.0


# ------------------------------------------------------------------ quests --
func start_quest(quest_id: String) -> void:
        if quest_states.has(quest_id) or completed_quests.has(quest_id):
                return
        var q: Dictionary = Data.quests.get(quest_id, {})
        if q.is_empty():
                return
        quest_states[quest_id] = {"objectives": []}
        for _o in q.get("objectives", []):
                quest_states[quest_id]["objectives"].append(0)
        active_quest = quest_id
        toast.emit("New quest: %s" % q.get("title", quest_id), Color(1.0, 0.95, 0.7))
        quest_changed.emit()
        _refresh_collect_objectives()


func quest_progress(quest_id: String, obj_index: int) -> int:
        if quest_states.has(quest_id):
                return quest_states[quest_id]["objectives"][obj_index]
        return 0


func _notify_quest_counters(obj_type: String, target: String) -> void:
        var changed := false
        for qid in quest_states.keys():
                var q: Dictionary = Data.quests[qid]
                var state: Dictionary = quest_states[qid]
                for i in q.get("objectives", []).size():
                        var obj: Dictionary = q["objectives"][i]
                        if obj["type"] != obj_type or obj["target"] != target:
                                continue
                        if obj_type == "CollectItem":
                                state["objectives"][i] = count_item(target)
                        changed = true
                _check_quest_complete(qid)
        if changed:
                quest_changed.emit()


func _refresh_collect_objectives() -> void:
        for qid in quest_states.keys():
                var q: Dictionary = Data.quests[qid]
                for i in q.get("objectives", []).size():
                        var obj: Dictionary = q["objectives"][i]
                        if obj["type"] == "CollectItem":
                                quest_states[qid]["objectives"][i] = count_item(obj["target"])


func notify_event(event_type: String, target: String, count: int = 1) -> void:
        # event_type: CaptureEcho / DefeatCreature / PlaceBuilding / ObserveEcho / UnlockTechnology
        for qid in quest_states.keys():
                var q: Dictionary = Data.quests[qid]
                for i in q.get("objectives", []).size():
                        var obj: Dictionary = q["objectives"][i]
                        if obj["type"] == event_type and obj["target"] == target:
                                quest_states[qid]["objectives"][i] += count
                                quest_changed.emit()
                _check_quest_complete(qid)


func _check_quest_complete(qid: String) -> void:
        if completed_quests.has(qid) or not quest_states.has(qid):
                return
        var q: Dictionary = Data.quests[qid]
        var state: Dictionary = quest_states[qid]
        var all_done := true
        for i in q.get("objectives", []).size():
                if state["objectives"][i] < int(q["objectives"][i]["count"]):
                        all_done = false
                        break
        if not all_done:
                return
        # retire the quest BEFORE granting rewards — reward items re-enter
        # _notify_quest_counters, which must never see this quest as active
        # again or completion recurs infinitely (stack overflow)
        completed_quests[qid] = true
        quest_states.erase(qid)
        # rewards
        for reward in q.get("rewards", []):
                add_item(reward["item"], reward["qty"])
        add_research_points(int(q.get("research_points", 0)))
        toast.emit("Quest complete: %s" % q.get("title", qid), Color(0.6, 1.0, 0.7))
        # advance chain
        var nxt = q.get("next")
        if nxt != null and str(nxt) != "":
                start_quest(str(nxt))
        quest_changed.emit()


func active_quest_data() -> Dictionary:
        return Data.quests.get(active_quest, {})


# ------------------------------------------------------------- party cmds --
var party_command := "Follow"


func get_party_command() -> String:
        return party_command


func set_party_command(cmd: String) -> void:
        party_command = cmd
        match cmd:
                "Follow": toast.emit("Party: follow me", Color(0.7, 0.9, 1.0))
                "Stay": toast.emit("Party: hold position", Color(0.7, 0.9, 1.0))
                "Attack": toast.emit("Party: attack!", Color(1.0, 0.7, 0.6))
        party_changed.emit()


func feed_party() -> void:
        # feed every active echo with its preferred food, else any feed item
        var fed := 0
        var order := ["Item_FeedMix", "Item_Berry", "Item_RawMeat", "Item_CookedMeat"]
        for e in party:
                var s := Data.species_def(e["species_id"])
                var chosen := ""
                for f in s.get("foods", []):
                        if count_item(f) > 0:
                                chosen = f
                                break
                if chosen == "":
                        for f in order:
                                if count_item(f) > 0:
                                        chosen = f
                                        break
                if chosen != "":
                        feed_echo(e, chosen)
                        fed += 1
        if fed == 0:
                toast.emit("Nothing to feed them with.", Color(1, 0.7, 0.5))


# ------------------------------------------------------------------- party --
func capture_chance(echo) -> float:
        if echo == null or echo.captured or echo.is_defeated():
                return 0.0
        var s: Dictionary = echo.def
        var diff: float = s.get("capture_difficulty", 0.35)
        var resilience: float = clampf(diff * 0.8, 0.05, 0.95)
        var base := 0.05 * (1.0 - 0.5 * diff)
        var weaken: float = (1.0 - echo.health_fraction()) * (1.0 - resilience) * (1.0 - 0.5 * diff)
        var trust := clampf(echo.trust / 100.0, 0.0, 1.0) * 0.5
        var situational := 0.0
        var pref_weather: String = s.get("preferred_weather", "")
        if pref_weather == "" or pref_weather == weather_id:
                situational += 0.10
        if _in_activity_window(s):
                situational += 0.05
        var chance: float = base + weaken + trust + situational + journal_bonus(s["id"])
        if echo.is_tracked():
                chance += 0.05
        return clampf(chance, 0.02, 0.95)


func _in_activity_window(s: Dictionary) -> bool:
        var act: String = s.get("activity", "Diurnal")
        var night := is_night()
        match act:
                "Nocturnal": return night
                "Diurnal": return not night
                "Crepuscular": return hour() >= 5.0 and hour() <= 8.0 or hour() >= 17.0 and hour() <= 20.0
        return true


func try_capture(echo) -> bool:
        if _capture_cooldown > 0.0:
                return false
        if count_item("Item_Resonator") <= 0:
                toast.emit("No Echo Resonators left — craft more at a workbench.", Color(1, 0.7, 0.5))
                return false
        if party.size() + echo_box.size() >= 12:
                toast.emit("Your roster is full (12).", Color(1, 0.7, 0.5))
                return false
        remove_item("Item_Resonator", 1)
        _capture_cooldown = CAPTURE_COOLDOWN
        var chance: float = capture_chance(echo)
        var success := randf() <= chance
        capture_attempt.emit(echo.def["id"], success)
        if success:
                var entry := {
                        "species_id": echo.def["id"], "name": echo.def["name"],
                        "level": 1, "xp": 0.0, "trust": 10.0, "bond": 0.0,
                        "mood": 70.0, "hunger": 60.0, "energy": 80.0,
                        "hp": echo.def["stats"]["hp"], "passive": str(echo.def.get("passive", "")),
                }
                if party.size() < MAX_PARTY:
                        party.append(entry)
                        echo.become_captured(get_tree().get_first_node_in_group("player"))
                else:
                        echo_box.append(entry)
                        echo.queue_free()
                toast.emit("Captured %s! (%d%% chance)" % [echo.def["name"], int(chance * 100)], Color(0.6, 1.0, 0.8))
                party_changed.emit()
                notify_event("CaptureEcho", echo.def["id"])
        else:
                toast.emit("%s resisted the resonator... (%d%% chance)" % [echo.def["name"], int(chance * 100)], Color(1, 0.75, 0.5))
        return success


func feed_echo(entry: Dictionary, item_id: String) -> void:
        var def := Data.item(item_id)
        var s := Data.species_def(entry["species_id"])
        var preferred: bool = item_id in s.get("foods", [])
        var mult := 2.0 if preferred else 1.0
        var feed_value: float = def.get("feed_value", 5.0)
        var trust_gain := 8.0 * mult * (0.01 * feed_value) if preferred else 4.0 * (0.01 * feed_value)
        entry["trust"] = minf(100.0, entry["trust"] + trust_gain)
        entry["bond"] = minf(100.0, entry["bond"] + trust_gain * 0.25)
        entry["hunger"] = minf(100.0, entry["hunger"] + 30.0 * mult)
        entry["mood"] = minf(100.0, entry["mood"] + 10.0 * mult)
        remove_item(item_id, 1)
        toast.emit("%s enjoyed the %s (+%d trust)" % [entry["name"], def.get("name", item_id), int(trust_gain)], Color(0.7, 1.0, 0.7))
        party_changed.emit()


func trust_stage(trust: float) -> String:
        var stage := TRUST_STAGES[0]["name"]
        for t in TRUST_STAGES:
                if trust >= t["min"]:
                        stage = t["name"]
        return stage


func add_party_xp(entry: Dictionary, amount: float) -> void:
        entry["xp"] += amount
        var needed: float = 100.0 * entry["level"]
        while entry["xp"] >= needed:
                entry["xp"] -= needed
                entry["level"] += 1
                var s := Data.species_def(entry["species_id"])
                entry["hp"] = s["stats"]["hp"] * (1.0 + 0.1 * (entry["level"] - 1))
                toast.emit("%s reached level %d!" % [entry["name"], entry["level"]], Color(1.0, 0.9, 0.5))
                check_evolution(entry)
        party_changed.emit()


func check_evolution(entry: Dictionary) -> void:
        var s := Data.species_def(entry["species_id"])
        var evo: Dictionary = s.get("evolves_to", {})
        if evo.is_empty() or s.has("base_species"):
                return
        if entry["level"] >= int(evo["level"]) and entry["bond"] >= float(evo["bond"]):
                var evolved := Data.species_def(evo["id"])
                entry["species_id"] = evo["id"]
                entry["name"] = evolved["name"] + " ✦"
                toast.emit("%s evolved into %s!" % [s["name"], evolved["name"]], Color(1.0, 0.7, 1.0))
                party_changed.emit()


# ------------------------------------------------------------------ zones ---
func notify_zone(zone_id: String) -> void:
        if zone_id == current_zone_id:
                return
        current_zone_id = zone_id
        if not discovered_zones.has(zone_id) and zone_id != "":
                discovered_zones[zone_id] = true
                var z := Data.zone(zone_id)
                toast.emit("Discovered %s — %s" % [z.get("name", zone_id), z.get("subtitle", "")], Color(1.0, 0.95, 0.7))
                add_research_points(1)
        zone_changed.emit(zone_id)
