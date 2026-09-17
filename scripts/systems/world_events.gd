class_name WorldEventSystem
extends Node
## World events — 9 data-driven archetypes (UE5 AstrawildWorldEventSubsystem +
## ProductionContent, Master Plan §19). Weighted random scheduler rolls events on
## a cadence, each runs for a duration in world-hours with a cooldown, and applies
## its effect: forced weather, species boosts, bonus nodes, loot drops, research,
## night raids. Every event announces itself on the HUD.

var active_event := ""             # event id
var active_timer := 0.0            # remaining world-minutes
var cooldowns := {}                # event id -> world-minutes remaining
var _roll_timer := 20.0            # world-minutes between scheduler rolls
var _world: Node3D = null


const EVENTS := [
        {"id": "Event_StormSurge", "name": "Storm Surge", "weight": 1.2, "duration": 10.0, "cooldown": 90,
                "forced_weather": "Storm", "rp": 2,
                "desc": "A storm cell parks over the vale — visibility drops, pulse energy crackles."},
        {"id": "Event_GreatMigration", "name": "Great Migration", "weight": 1.0, "duration": 24.0, "cooldown": 120,
                "species_boost": "Echo_Sprigling", "boost_count": 4, "zone": "Zone_VerdantReach",
                "desc": "Sprigling herds flow through the Verdant Reach."},
        {"id": "Event_ResourceSurge", "name": "Resource Surge", "weight": 1.0, "duration": 16.0, "cooldown": 60,
                "bonus_nodes": ["Node_DawnCrystal", "Node_DawnCrystal", "Node_DawnCrystal"], "rp": 1,
                "desc": "The Glimwood spits out crystal clusters overnight."},
        {"id": "Event_SupplyDrop", "name": "Supply Drop", "weight": 0.8, "duration": 20.0, "cooldown": 90,
                "loot": [{"item": "Item_EnergyCell", "qty": 6}, {"item": "Item_Bandage", "qty": 2}, {"item": "Item_DawnShard", "qty": 1}],
                "desc": "An orbital cache falls somewhere near camp — the crate's contents land in your pack."},
        {"id": "Event_AncientSignal", "name": "Ancient Signal", "weight": 0.9, "duration": 12.0, "cooldown": 90,
                "rp": 5,
                "desc": "The old tower under the Hollow Approach hums — the journal fills itself."},
        {"id": "Event_NightRaid", "name": "Night Raid", "weight": 1.0, "duration": 8.0, "cooldown": 120, "night_only": true,
                "species_boost": "Echo_Gloomfang", "boost_count": 2, "zone": "Zone_DawnFields",
                "desc": "Gloomfangs test the camp perimeter — keep the fires high."},
        {"id": "Event_MeteorFall", "name": "Meteor Fall", "weight": 0.7, "duration": 36.0, "cooldown": 150,
                "bonus_nodes": ["Node_StormSilver", "Node_StormSilver", "Node_DuneGlass"],
                "loot": [{"item": "Item_StormSilver", "qty": 3}, {"item": "Item_DuneGlass", "qty": 2}],
                "desc": "A star falls into the Frostveil — rare metals scatter with the impact."},
        {"id": "Event_RareEchoBloom", "name": "Rare Echo Bloom", "weight": 0.5, "duration": 12.0, "cooldown": 120,
                "species_boost": "Echo_Auroraling", "boost_count": 1, "zone": "Zone_Glimmerwood", "rp": 3,
                "desc": "An Auroraling shows itself in the deep Glimmerwood — briefly."},
        {"id": "Event_BossStirring", "name": "Boss Stirring", "weight": 0.5, "duration": 36.0, "cooldown": 90,
                "rp": 4,
                "desc": "The Underlight Warden shifts in its sleep — the whole zone holds its breath."},
]


func _process(delta: float) -> void:
        if _world == null:
                _world = get_tree().get_first_node_in_group("world")
                if _world == null:
                        return
        # world minutes advance at 1 real second = 1 world minute
        var wmin := delta
        if active_event != "":
                active_timer -= wmin
                if active_timer <= 0.0:
                        _end_event()
        _roll_timer -= wmin
        for k in cooldowns:
                cooldowns[k] = maxf(0.0, cooldowns[k] - wmin)
        if _roll_timer <= 0.0:
                _roll_timer = 20.0
                _roll_event()


func _roll_event() -> void:
        if active_event != "":
                return
        var candidates: Array = []
        for e in EVENTS:
                if cooldowns.get(e["id"], 0.0) > 0.0:
                        continue
                if e.get("night_only", false) and not Game.is_night():
                        continue
                for i in int(e.get("weight", 1.0) * 10.0):
                        candidates.append(e)
        if candidates.is_empty():
                return
        var pick: Dictionary = candidates[randi() % candidates.size()]
        _start_event(pick)


func _start_event(e: Dictionary) -> void:
        active_event = e["id"]
        active_timer = float(e.get("duration", 10.0))
        cooldowns[e["id"]] = float(e.get("cooldown", 90))
        Game.toast.emit("WORLD EVENT — %s" % e["name"].to_upper(), Color(1.0, 0.9, 0.4))
        Game.toast.emit(e["desc"], Color(0.9, 0.9, 0.8))
        # effects
        if e.has("forced_weather"):
                Game.forced_weather = str(e["forced_weather"])
                Game.weather_changed.emit(str(e["forced_weather"]))
        if e.has("rp"):
                Game.add_research_points(int(e["rp"]))
        if e.has("loot"):
                for drop in e["loot"]:
                        Game.add_item(drop["item"], int(drop["qty"]))
        if e.has("species_boost"):
                _spawn_boost_creatures(str(e["species_boost"]), int(e.get("boost_count", 2)), str(e.get("zone", "")))
        if e.has("bonus_nodes"):
                _spawn_bonus_nodes(e["bonus_nodes"])


func _end_event() -> void:
        var e := _find_event(active_event)
        if not e.is_empty():
                Game.toast.emit("%s fades..." % e["name"], Color(0.8, 0.85, 0.9))
                if e.has("forced_weather"):
                        Game.forced_weather = ""
        else:
                Game.toast.emit("The vale settles...", Color(0.8, 0.85, 0.9))
        active_event = ""
        active_timer = 0.0


func _find_event(eid: String) -> Dictionary:
        for e in EVENTS:
                if e["id"] == eid:
                        return e
        return {}


func _spawn_boost_creatures(species_id: String, count: int, zone_id: String) -> void:
        if _world == null:
                return
        var def: Dictionary = Data.species_def(species_id)
        if def.is_empty():
                return
        var zone: Dictionary = Data.zone(zone_id)
        var rng := RandomNumberGenerator.new()
        rng.seed = hash("event-%s-%d" % [species_id, Time.get_ticks_msec()])
        for i in count:
                var pos: Vector3 = _world._scatter(rng, 1, zone, 0.5)[0] if not zone.is_empty() else _world._camp_pos
                _world._spawn_creature(def, pos, rng)


func _spawn_bonus_nodes(node_ids: Array) -> void:
        if _world == null:
                return
        var player := get_tree().get_first_node_in_group("player")
        var origin: Vector3 = player.global_position if player else _world._camp_pos
        var rng := RandomNumberGenerator.new()
        rng.seed = hash("nodes-event-%d" % Time.get_ticks_msec())
        for nid in node_ids:
                var nd: Dictionary = Data.resource_nodes.get(nid, {})
                if nd.is_empty():
                        continue
                var ang := rng.randf() * TAU
                var dist := 18.0 + rng.randf() * 30.0
                var pos := origin + Vector3(cos(ang) * dist, 0, sin(ang) * dist)
                pos.y = _world.tile_height(pos.x, pos.z)
                var node: Node3D = load("res://scripts/world/resource_node.gd").new(nd)
                node.position = pos
                node.rotation.y = rng.randf() * TAU
                node.set_meta("event_node", true)
                _world.nodes_root.add_child(node)


# --------------------------------------------------------------------- save --
func get_save_data() -> Dictionary:
        return {"active": active_event, "timer": active_timer, "cooldowns": cooldowns}


func apply_save_data(data: Dictionary) -> void:
        var e := _find_event(str(data.get("active", "")))
        if not e.is_empty():
                active_event = e["id"]
                active_timer = float(data.get("timer", 10.0))
                if e.has("forced_weather"):
                        Game.forced_weather = str(e["forced_weather"])
        cooldowns = data.get("cooldowns", {})
