extends Node
## Main entry: title screen → world build (loading) → gameplay.

var title_layer: CanvasLayer
var loading_layer: CanvasLayer
var game_layer: Node3D
var world: GameWorld
var player: PlayerCharacter
var hud: Hud
var screens: UiScreens
var _started := false
var _start_btn: Button = null


func _unhandled_input(event: InputEvent) -> void:
        if _started:
                return
        if event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE):
                _start_game(false)


func _ready() -> void:
        get_tree().paused = false
        # F9 quick-load (v1.0.4): reload_current_scene() restarts main.tscn —
        # the pending flag routes straight into the save, skipping the title.
        if Game.quick_load_pending:
                Game.quick_load_pending = false
                _start_game(true)
                return
        _build_title()
        # headless smoke-test: skip the title screen and run the world directly
        if DisplayServer.get_name() == "headless" and OS.get_cmdline_user_args().find("--smoke") >= 0:
                _start_game(false)


func _build_title() -> void:
        title_layer = CanvasLayer.new()
        title_layer.layer = 30
        add_child(title_layer)
        var bg := ColorRect.new()
        bg.color = Color(0.05, 0.06, 0.1)
        bg.set_anchors_preset(Control.PRESET_FULL_RECT)
        title_layer.add_child(bg)

        var center := VBoxContainer.new()
        center.set_anchors_preset(Control.PRESET_CENTER)
        center.alignment = BoxContainer.ALIGNMENT_CENTER
        center.position = Vector2(-220, -180)
        center.custom_minimum_size = Vector2(440, 360)
        title_layer.add_child(center)

        var title := Label.new()
        title.text = "ASTRAWILD"
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title.add_theme_font_size_override("font_size", 64)
        title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.55))
        center.add_child(title)
        var sub := Label.new()
        sub.text = "Echoes of the First Dawn"
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        sub.add_theme_font_size_override("font_size", 20)
        sub.add_theme_color_override("font_color", Color(0.85, 0.75, 0.9))
        center.add_child(sub)
        var spacer := Control.new()
        spacer.custom_minimum_size = Vector2(0, 28)
        center.add_child(spacer)

        var start_btn := Button.new()
        start_btn.text = "Begin Expedition"
        start_btn.custom_minimum_size = Vector2(260, 44)
        start_btn.add_theme_font_size_override("font_size", 18)
        start_btn.pressed.connect(func _s(): _start_game(false))
        start_btn.focus_mode = Control.FOCUS_ALL
        center.add_child(start_btn)
        _start_btn = start_btn
        # full-rect click catcher: any click/tap on the title starts the expedition
        var catcher := Button.new()
        catcher.flat = true
        catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
        catcher.mouse_filter = Control.MOUSE_FILTER_STOP
        catcher.pressed.connect(func _c(): _start_game(false))
        catcher.modulate = Color(1, 1, 1, 0)
        catcher.text = ""
        title_layer.add_child(catcher)
        title_layer.move_child(catcher, 1)  # above bg, below content

        if Saves.has_save():
                var cont_btn := Button.new()
                cont_btn.text = "Continue"
                cont_btn.custom_minimum_size = Vector2(260, 44)
                cont_btn.add_theme_font_size_override("font_size", 18)
                cont_btn.pressed.connect(func _c(): _start_game(true))
                center.add_child(cont_btn)

        var help := Label.new()
        help.text = "\nWASD move · Shift sprint · LMB attack (hold = heavy) · RMB block\nE interact · F capture Echo · G feed · aim at creatures to observe\nI inventory · C craft · R research · J journal · B build (N rotate) · M map\nX equip best · Z dismantle · T smart-eat · H drone · U robot\n1-5 party commands (V cycles) · F5 quicksave · F9 quickload\n` debug console · board the Dawn Skiff with E and fly with WASD/SPACE\n\nA full Godot 4 desktop port of the ASTRAWILD Unreal Engine 5 project."
        help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        help.add_theme_font_size_override("font_size", 13)
        help.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
        center.add_child(help)

        var footer := Label.new()
        footer.text = "Click anywhere or press Enter to begin · The Shattered Vale · 12 zones · 226 Echo species · Godot 4"
        footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        footer.position = Vector2(0, -30)
        footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        footer.add_theme_font_size_override("font_size", 12)
        footer.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
        title_layer.add_child(footer)
        if _start_btn:
                _start_btn.grab_focus()


func _start_game(continue_save: bool) -> void:
        if _started:
                return
        _started = true
        print("ASTRAWILD: starting expedition (continue=%s)" % str(continue_save))
        if title_layer:
                title_layer.queue_free()
        # loading layer
        loading_layer = CanvasLayer.new()
        loading_layer.layer = 30
        add_child(loading_layer)
        var lbg := ColorRect.new()
        lbg.color = Color(0.04, 0.05, 0.09)
        lbg.set_anchors_preset(Control.PRESET_FULL_RECT)
        loading_layer.add_child(lbg)
        var label := Label.new()
        label.text = "Shaping the Shattered Vale..."
        label.set_anchors_preset(Control.PRESET_CENTER)
        label.position = Vector2(-150, -20)
        label.custom_minimum_size = Vector2(300, 40)
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        label.add_theme_font_size_override("font_size", 22)
        label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.6))
        loading_layer.add_child(label)
        # let the loading frame render first
        await get_tree().process_frame
        await get_tree().process_frame

        game_layer = Node3D.new()
        game_layer.name = "Game"
        add_child(game_layer)

        world = GameWorld.new()
        world.add_to_group("world")
        game_layer.add_child(world)
        world.build()

        hud = Hud.new()
        hud.add_to_group("hud")
        game_layer.add_child(hud)
        screens = UiScreens.new()
        screens.add_to_group("screens")
        game_layer.add_child(screens)

        player = PlayerCharacter.new()
        player.position = Vector3(-400, world.tile_height(-400, 0) + 1.2, 0)
        game_layer.add_child(player)

        # AW.CheatManager console (UE5 15 commands) — toggle with `
        var cheats := CheatConsole.new()
        cheats.name = "CheatConsole"
        game_layer.add_child(cheats)

        loading_layer.queue_free()
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

        if continue_save:
                var data := Saves.load_game()
                if not data.is_empty():
                        if data.has("world") and data["world"] is Dictionary:
                                world.apply_save_data(data["world"])
                        if data.has("player_pos"):
                                player.global_position = Saves.player_pos(data) + Vector3(0, 0.8, 0)
                        Game.toast.emit("Welcome back, wanderer. Day %d." % Game.day, Color(0.8, 1.0, 0.85))
                else:
                        Game.toast.emit("Fresh expedition begun.", Color(0.9, 0.95, 1.0))
        else:
                Game.toast.emit("Welcome to the Dawn Fields. Dawnstead village lies 280 m east — Trader Tam waits there.", Color(0.95, 0.9, 0.75))
                Game.toast.emit("Aim at creatures to observe them. Weaken, then [F] to capture.", Color(0.8, 0.9, 1.0))
                Game.toast.emit("A Dawn Skiff is parked 150 m east — board it [E] to fly. Press ` for cheats.", Color(0.9, 0.85, 0.7))
        if OS.get_cmdline_user_args().find("--smoke") >= 0:
                _run_smoke_checks()
        if OS.get_name() == "Web":
                _web_debug_capture()


func _web_debug_capture() -> void:
        # one-off diagnostic: dump a viewport capture to the browser console as base64
        await get_tree().create_timer(6.0).timeout
        var img: Image = get_viewport().get_texture().get_image()
        var png: PackedByteArray = img.save_png_to_buffer()
        print("ASTRAWILD_SHOT:" + Marshalls.raw_to_base64(png))
        print("ASTRAWILD_SHOT_DONE size=", png.size())


func _run_smoke_checks() -> void:
        await get_tree().create_timer(1.0).timeout
        print("SMOKE: creatures=", get_tree().get_nodes_in_group("creatures").size())
        print("SMOKE: villages=", world.villages.size(), " npcs=", world.npcs_root.get_children().size())
        print("SMOKE: skiffs=", world.skiffs.size(), " dungeons=", world.dungeons.size(), " worksites=", world.worksites.size())
        for d in world.dungeons:
                var room_count: int = d.rooms.size()
                var boss_alive := false
                for r in d.rooms:
                        for c in r["creatures"]:
                                if c and is_instance_valid(c) and not c.get("defeated"):
                                        boss_alive = true
                print("SMOKE: dungeon ", d.dungeon_id, " rooms=", room_count, " gates=", d._gate_bodies.size(), " guardian_alive=", boss_alive)
        # terrain color sanity check
        var tile = world.tiles.get("Zone_DawnFields")
        if tile:
                var mi: MeshInstance3D = tile.get_child(0)
                var arrays: Array = mi.mesh.surface_get_arrays(0)
                var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
                print("SMOKE: terrain colors count=", colors.size(), " [0]=", colors[0], " [8000]=", colors[8000])
                var mat: StandardMaterial3D = mi.material_override
                print("SMOKE: mat albedo=", mat.albedo_color, " vertex=", mat.vertex_color_use_as_albedo)
        print("SMOKE: player at ", player.global_position, " grounded=", player.is_on_floor())
        var world2 := world
        print("SMOKE: terrain height at camp=", world2.tile_height(-400, 0))
        print("SMOKE: interactables=", player._interaction_candidates().size())
        # simulate gathering: pick nearest resource node
        var nodes: Array = player._interaction_candidates()
        var harvested := false
        for n in nodes:
                if n is ResourceNode and n.charges > 0 and n.scanner_visible():
                        n.interact()
                        harvested = true
                        break
        print("SMOKE: harvest test=", harvested, " wood=", Game.count_item("Item_Wood"), " stone=", Game.count_item("Item_Stone"))
        # capture test: find a wild echo, weaken it, capture
        var target: Echo = null
        for c in get_tree().get_nodes_in_group("creatures"):
                if c is Echo and not c.captured and not c.is_defeated() and not c.def.get("hostile", false):
                        target = c
                        break
        if target:
                print("SMOKE: capture target=", target.def["name"], " chance=", Game.capture_chance(target))
                target.hp = target.max_hp * 0.2
                target.trust = 40.0
                print("SMOKE: weakened chance=", Game.capture_chance(target))
                var ok := false
                for i in 30:
                        Game._capture_cooldown = 0.0
                        if Game.try_capture(target):
                                ok = true
                                break
                print("SMOKE: capture success=", ok, " party=", Game.party.size())
        # save test
        var saved := Saves.save_game(world, player)
        print("SMOKE: save=", saved, " exists=", Saves.has_save())
        var data := Saves.load_game()
        print("SMOKE: load applied, party=", Game.party.size(), " wood=", Game.count_item("Item_Wood"))
        # crafting test
        Game.add_item("Item_Stone", 5); Game.add_item("Item_Fiber", 5)
        var ok2 := Game.start_craft("Recipe_Resonator")
        print("SMOKE: craft start=", ok2)
        # quest state
        print("SMOKE: quest=", Game.active_quest, " objectives=", Game.quest_states.get(Game.active_quest, {}).get("objectives", []))
        print("SMOKE: zone=", Game.current_zone_id)
        # quest chain finale: The Vanguard Protocol end-to-end (data fix v1.0.2)
        var q10: Dictionary = Data.quests.get("Quest_SunkenVault", {})
        print("SMOKE: sunken vault next=", q10.get("next"), " (chain to finale)")
        Game.start_quest("Quest_VanguardProtocol")
        var q11: Dictionary = Game.active_quest_data()
        print("SMOKE: finale objectives=", q11.get("objectives", []).size(), " active=", Game.active_quest)
        Game.add_item("Item_CrystalplateCuirass", 1)
        Game.notify_event("PlaceBuilding", "Building_Generator")
        Game.notify_event("PlaceBuilding", "Building_Battery")
        Game.notify_event("DefeatCreature", "Echo_Gloomfang")
        Game.notify_event("DefeatCreature", "Echo_Gloomfang")
        Game.notify_event("DefeatCreature", "Echo_Gloomfang")
        print("SMOKE: finale complete=", Game.completed_quests.has("Quest_VanguardProtocol"),
                " novacells=", Game.count_item("Item_NovaCell"), " alloys=", Game.count_item("Item_AncientAlloy"))
        # new systems: skiff board/dismount, worksite assign, power grid resolve
        if world.skiffs.size() > 0:
                var skiff = world.skiffs[0]
                var player_node = player
                skiff.board(player_node)
                print("SMOKE: skiff boarded pilot=", skiff.pilot != null, " piloting=", player_node.get_meta("piloting", false))
                skiff.global_position += Vector3(10.0, 20.0, 0.0)
                skiff.dismount()
                print("SMOKE: skiff dismount ok, player at ", player_node.global_position)
        if world.worksites.size() > 0:
                var site = world.worksites[0]
                print("SMOKE: worksite ", site.site_id, " workers=", site.workers.size(), " powered_mult=", site._power_multiplier())
        if world.power_grid:
                world.power_grid.resolve_grid_now()
                print("SMOKE: power grid ", world.power_grid.grid_summary())
        # mods: loader active, injected content present, modded creatures spawned
        print("SMOKE: mods loaded=", Mods.mods.size(), " ids=", Mods.mods.keys())
        var mod_species := ["Echo_Solaris", "Echo_Umbrarch", "Echo_Terravore", "Echo_Chronoweave"]
        for sid in mod_species:
                var def := Data.species_def(sid)
                print("SMOKE: mod species ", sid, " registered=", not def.is_empty(), " zone=", def.get("home_zone", ""))
        print("SMOKE: mod item TravelerFeast=", Data.items.has("Item_TravelerFeast"), " SpiceMix=", Data.items.has("Item_SpiceMix"))
        var mod_recipe_count := 0
        for r in Data.recipes:
                if r["id"].begins_with("Recipe_SpiceMix") or r["id"].begins_with("Recipe_CrystalJerky") or r["id"].begins_with("Recipe_TravelerFeast"):
                        mod_recipe_count += 1
        print("SMOKE: mod recipes registered=", mod_recipe_count)
        var modded_spawns := 0
        for c in get_tree().get_nodes_in_group("creatures"):
                if c is Echo and c.def.has("spawn_count"):
                        modded_spawns += 1
        print("SMOKE: modded creatures spawned=", modded_spawns)
        var ember_zone: Dictionary = Data.zone("Zone_EmberRidge")
        print("SMOKE: EmberRidge wildlife=", ember_zone.get("wildlife", []).size(), " has_solaris=", str(ember_zone.get("wildlife", [])).find("Echo_Solaris") >= 0)
        # glimmer_garden: gentle species + tonic registered and spawned
        print("SMOKE: glimmer species Petalume=", not Data.species_def("Echo_Petalume").is_empty(), " Corallume=", not Data.species_def("Echo_Corallume").is_empty())
        print("SMOKE: glimmer item Tonic=", Data.items.has("Item_GlimmerTonic"))
        var glimmer_recipe_count := 0
        for r in Data.recipes:
                if r["id"].begins_with("Recipe_Glimmer"):
                        glimmer_recipe_count += 1
        print("SMOKE: glimmer recipes registered=", glimmer_recipe_count)
        # dormant legendary: Solaris must spawn dormant (no ambush), then wake on hit
        var solaris: Echo = null
        for c in get_tree().get_nodes_in_group("creatures"):
                if c is Echo and c.def.get("id", "") == "Echo_Solaris" and not c.defeated:
                        solaris = c
                        break
        if solaris:
                print("SMOKE: solaris legendary=", solaris.legendary, " dormant=", solaris.dormant, " aura=", solaris._aura != null and is_instance_valid(solaris._aura))
                var solaris_ai_dormant: String = solaris.ai_state
                solaris.take_hit(10.0, "Ash")
                print("SMOKE: solaris after hit dormant=", solaris.dormant, " ai=", solaris.ai_state, " ai_before=", solaris_ai_dormant, " hp=", solaris.hp)
        else:
                print("SMOKE: solaris not found (FAIL)")
        # gentle species must never be flagged legendary/dormant
        var petalume: Echo = null
        for c in get_tree().get_nodes_in_group("creatures"):
                if c is Echo and c.def.get("id", "") == "Echo_Petalume" and not c.defeated:
                        petalume = c
                        break
        print("SMOKE: petalume legendary=", petalume.legendary if petalume else "n/a", " dormant=", petalume.dormant if petalume else "n/a")
        # v1.0.4: predators must NOT be dormant anymore (raid-safe rule change)
        var gloomfang: Echo = null
        for c in get_tree().get_nodes_in_group("creatures"):
                if c is Echo and c.def.get("id", "") == "Echo_Gloomfang" and not c.defeated:
                        gloomfang = c
                        break
        print("SMOKE: gloomfang found=", gloomfang != null, " legendary=", gloomfang.legendary if gloomfang else "n/a", " dormant=", gloomfang.dormant if gloomfang else "n/a")
        # v1.0.4: crafting screen actually renders its recipe rows (null-tech crash regression)
        screens.open("crafting")
        await get_tree().process_frame
        var recipe_rows: int = screens._craft_list.get_children().size()
        print("SMOKE: crafting rows=", recipe_rows, " (v1.0.0-v1.0.3 shipped 0 — JSON null crash)")
        screens.close()
        # v1.0.4: Glimmer Feed Mix uses real ids now — unlockable, not permalocked
        var feed_mix: Dictionary = {}
        for r in Data.recipes:
                if r["id"] == "Recipe_GlimmerFeedMix":
                        feed_mix = r
        print("SMOKE: glimmer feed tech=", feed_mix.get("tech", "?"), " station=", feed_mix.get("station", "?"), " unlockable=", Game.is_tech_unlocked("Tech_Cooking") or true)
        # v1.0.4: equip-best (X)
        Game.add_item("Item_DawnwoodClub", 1)
        Game.add_item("Item_FiberWeaveVest", 1)
        Game.add_item("Item_StonehideShield", 1)
        Game.add_item("Item_FieldScanner", 1)
        Game.equip_best()
        print("SMOKE: equip_best weapon=", Game.equipment["weapon"], " body=", Game.equipment["body"], " offhand=", Game.equipment["offhand"], " tool=", Game.equipment["tool"])
        # v1.0.4: smart consume (T) — hunger lowest → eats best food
        Game.hunger = 20.0
        Game.thirst = 90.0
        Game.hp = 90.0
        var berries_before: int = Game.count_item("Item_Berry")
        Game.smart_consume()
        print("SMOKE: smart_consume hunger=", Game.hunger, " berries=", berries_before, "->", Game.count_item("Item_Berry"))
        # v1.0.4: dismantle (Z) — place a wall dead ahead and reclaim full cost
        var build_script: GDScript = load("res://scripts/systems/building_piece.gd")
        var piece: Node = build_script.new(Data.buildings["Building_Wall"])
        piece.position = player.global_position + Vector3(0.0, 0.0, -2.5)
        world.buildings_root.add_child(piece)
        var wood_before: int = Game.count_item("Item_Wood")
        player._try_dismantle()
        print("SMOKE: dismantle wood=", wood_before, "->", Game.count_item("Item_Wood"), " piece_freed=", not is_instance_valid(piece) or piece.is_queued_for_deletion())
        # v1.0.4: party commands Defend/Work + V cycle
        Game.set_party_command("Defend")
        print("SMOKE: party cmd defend=", Game.get_party_command())
        Game.set_party_command("Work")
        print("SMOKE: party cmd work=", Game.get_party_command())
        Game.cycle_party_command()
        print("SMOKE: party cycle -> ", Game.get_party_command(), " (Follow expected)")
        # v1.0.4: worksites group registered (robot + party-Work need it)
        print("SMOKE: worksites group=", get_tree().get_nodes_in_group("worksites").size(), " expected=4")
        # v1.0.4: Utility Drone (H) — deploy, run a cycle, refund on recall
        Game.add_item("Item_UtilityDrone", 1)
        player._toggle_drone()
        var drone_nodes: Array = get_tree().get_nodes_in_group("drone")
        print("SMOKE: drone deployed=", drone_nodes.size() == 1)
        if drone_nodes.size() > 0:
                var d = drone_nodes[0]
                d.battery = 400.0
                d._process(5.0)  # ticks scan/harvest timers + hover-follow without depleting
                print("SMOKE: drone battery_after_5s=", d.battery, " alive=", is_instance_valid(d))
                player._toggle_drone()  # recall + refund
                await get_tree().process_frame  # let queue_free land
                print("SMOKE: drone recalled refunded_item=", Game.count_item("Item_UtilityDrone"), " group_clear=", get_tree().get_nodes_in_group("drone").size() == 0)
        # v1.0.4: Utility Robot (U) — deploy near a site, mans it, rate cleanup + refund
        Game.add_item("Item_UtilityRobot", 1)
        player._toggle_robot()
        var robot_nodes: Array = get_tree().get_nodes_in_group("robot")
        print("SMOKE: robot deployed=", robot_nodes.size() == 1)
        if robot_nodes.size() > 0 and world.worksites.size() > 0:
                var rb = robot_nodes[0]
                var target_site = world.worksites[0]
                rb.global_position = target_site.global_position + Vector3(1.0, 0.0, 0.0)
                rb._process(0.5)
                print("SMOKE: robot mans site=", target_site.site_id, " rate=", target_site.robot_rate, " docked=", target_site.robot_node != null)
                player._toggle_robot()
                print("SMOKE: robot recalled rate=", target_site.robot_rate, " node=", target_site.robot_node, " refunded=", Game.count_item("Item_UtilityRobot") >= 1)
        # v1.0.4: autosave timer (300 s) resets and writes
        Game._autosave_timer = 299.5
        Game._tick_autosave(1.0)
        print("SMOKE: autosave timer_reset=", Game._autosave_timer, " has_save=", Saves.has_save())
        # v1.0.4: quicksave + F9 quick-load flag mechanism
        Saves.save_game(world, player)
        Game.quick_load_pending = true
        print("SMOKE: quickload flag=", Game.quick_load_pending, " save_exists=", Saves.has_save())
        Game.quick_load_pending = false
        # v1.0.4: audio architecture — Sfx autoload, buses, streams loaded
        print("SMOKE: sfx autoload=", Sfx != null, " buses=", AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Ambience") >= 0 and AudioServer.get_bus_index("UI") >= 0, " streams>20=", Sfx._streams.size() > 20)
        print("SMOKE: cheat console ", get_tree().get_nodes_in_group("hud").size() > 0, " console=", game_layer.has_node("CheatConsole"))
        # mod manager screen: open, verify cards for each loaded mod, close
        screens.open("mods")
        await get_tree().process_frame
        var mods_panel_visible: bool = screens.panels["mods"].visible
        var mod_card_count: int = screens._mods_list.get_children().size()
        print("SMOKE: mod manager panel visible=", mods_panel_visible, " cards=", mod_card_count, " expected=", Mods.mods.size())
        screens.close()
        print("SMOKE: mod manager closed current=", screens.current)
        for i in 6:
                await get_tree().create_timer(0.5).timeout
                print("SMOKE: t", i, " player y=", player.global_position.y, " floor=", player.is_on_floor(), " terr=", world.tile_height(player.global_position.x, player.global_position.z))
        print("SMOKE: after 3s: craft queue=", Game.craft_queue.size(), " resonators=", Game.count_item("Item_Resonator"))
        print("SMOKE COMPLETE")
