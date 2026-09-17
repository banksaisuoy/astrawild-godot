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
        help.text = "\nWASD move · Shift sprint · LMB attack (hold = heavy) · RMB block\nE interact · F capture Echo · G feed · aim at creatures to observe\nI inventory · C craft · R research · J journal · B build · M map\n` debug console · board the Dawn Skiff with E and fly with WASD/SPACE\n\nA full Godot 4 desktop port of the ASTRAWILD Unreal Engine 5 project."
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
        print("SMOKE: cheat console ", get_tree().get_nodes_in_group("hud").size() > 0, " console=", game_layer.has_node("CheatConsole"))
        for i in 6:
                await get_tree().create_timer(0.5).timeout
                print("SMOKE: t", i, " player y=", player.global_position.y, " floor=", player.is_on_floor(), " terr=", world.tile_height(player.global_position.x, player.global_position.z))
        print("SMOKE: after 3s: craft queue=", Game.craft_queue.size(), " resonators=", Game.count_item("Item_Resonator"))
        print("SMOKE COMPLETE")
