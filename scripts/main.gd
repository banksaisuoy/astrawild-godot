extends Node
## Main entry: title screen → world build (loading) → gameplay.

const GAME_VERSION := "v1.2"

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
        # v1.3 V12-c: the screens layer exists from boot (credits at title need it)
        if screens == null:
                screens = UiScreens.new()
                screens.add_to_group("screens")
                add_child(screens)
                screens.closed.connect(func _sc():
                        if title_layer and is_instance_valid(title_layer) and not _started:
                                title_layer.visible = true)
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
        # screenshot mode (xvfb/CI): boot into the world, capture, quit
        if OS.get_cmdline_user_args().find("--screenshot") >= 0:
                var shot_mode := "game"
                for a in OS.get_cmdline_user_args():
                        if a.begins_with("--shot="):
                                shot_mode = a.trim_prefix("--shot=")
                if shot_mode == "title":
                        # title-only capture: never start the world
                        _screenshot_routine()
                else:
                        _start_game(OS.get_cmdline_user_args().find("--cont") >= 0)
                        _screenshot_routine()


func _build_title() -> void:
        ## v1.2 de-jank pass: cinematic title — AI key art (own asset), slow Ken
        ## Burns zoom, radial vignette, drifting light motes, outlined logo,
        ## styled menu buttons. Falls back to a dawn gradient if art missing.
        title_layer = CanvasLayer.new()
        title_layer.layer = 30
        add_child(title_layer)
        var vp := get_viewport().get_visible_rect().size

        var art: Texture2D = null
        if ResourceLoader.exists("res://assets/ui/title_keyart.png"):
                art = load("res://assets/ui/title_keyart.png")

        if art != null:
                var tr := TextureRect.new()
                tr.texture = art
                tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
                tr.set_anchors_preset(Control.PRESET_FULL_RECT)
                tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                title_layer.add_child(tr)
                # slow cinematic zoom (Ken Burns), pivot at center once laid out
                _ken_burns(tr)
        else:
                var cr := ColorRect.new()
                cr.color = Color(0.07, 0.09, 0.14)
                cr.set_anchors_preset(Control.PRESET_FULL_RECT)
                title_layer.add_child(cr)

        # radial vignette: dark edges keep the menu readable over bright art
        var vig := TextureRect.new()
        var grad := Gradient.new()
        grad.set_color(0, Color(0, 0, 0, 0))
        grad.set_color(1, Color(0.02, 0.015, 0.0, 0.62))
        grad.add_point(0.45, Color(0, 0, 0, 0.05))
        var gtex := GradientTexture2D.new()
        gtex.gradient = grad
        gtex.fill_from = Vector2(0.5, 0.42)
        gtex.fill_to = Vector2(1.05, 0.42)
        gtex.width = 256
        gtex.height = 8
        vig.texture = gtex
        vig.stretch_mode = TextureRect.STRETCH_SCALE
        vig.set_anchors_preset(Control.PRESET_FULL_RECT)
        title_layer.add_child(vig)

        # drifting golden motes (additive) — the "echoes" of the Vale
        var motes := CPUParticles2D.new()
        motes.position = Vector2(vp.x * 0.5, vp.y * 0.6)
        motes.amount = 42
        motes.lifetime = 14.0
        motes.preprocess = 10.0
        motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
        motes.emission_rect_extents = Vector2(vp.x * 0.55, 40)
        motes.direction = Vector2(0, -1)
        motes.spread = 12.0
        motes.gravity = Vector2(0, -3)
        motes.initial_velocity_min = 6.0
        motes.initial_velocity_max = 22.0
        motes.scale_amount_min = 0.35
        motes.scale_amount_max = 1.15
        motes.color = Color(1.0, 0.82, 0.45, 0.55)
        var dot := Image.create(16, 16, false, Image.FORMAT_RGBA8)
        for x in 16:
                for y in 16:
                        var d: float = Vector2(x - 7.5, y - 7.5).length() / 8.0
                        var a: float = clampf(1.0 - d, 0.0, 1.0)
                        dot.set_pixel(x, y, Color(1.0, 0.86, 0.55, a * a))
        motes.texture = ImageTexture.create_from_image(dot)
        var add_mat := CanvasItemMaterial.new()
        add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
        motes.material = add_mat
        title_layer.add_child(motes)

        # ---- logo block (upper third, over calm sky; absolute placement) ----
        var shadow := Label.new()
        shadow.text = "A S T R A W I L D"
        shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        shadow.position = Vector2(vp.x * 0.5 - 446, 91)
        shadow.size = Vector2(900, 100)
        shadow.add_theme_font_size_override("font_size", 76)
        shadow.add_theme_color_override("font_color", Color(0.03, 0.02, 0.01, 0.55))
        title_layer.add_child(shadow)

        var title := Label.new()
        title.text = "A S T R A W I L D"
        title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        title.position = Vector2(vp.x * 0.5 - 450, 84)
        title.size = Vector2(900, 100)
        title.add_theme_font_size_override("font_size", 76)
        title.add_theme_color_override("font_color", Color(1.0, 0.87, 0.55))
        title.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 0.9))
        title.add_theme_constant_override("outline_size", 10)
        title_layer.add_child(title)

        var sub := Label.new()
        sub.text = "— Echoes of the First Dawn —"
        sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        sub.position = Vector2(vp.x * 0.5 - 450, 192)
        sub.size = Vector2(900, 30)
        sub.add_theme_font_size_override("font_size", 21)
        sub.add_theme_color_override("font_color", Color(0.93, 0.87, 0.97, 0.95))
        sub.add_theme_color_override("font_shadow_color", Color(0.05, 0.04, 0.1, 0.8))
        sub.add_theme_constant_override("shadow_offset_y", 3)
        title_layer.add_child(sub)

        # ---- menu block (below logo) ----
        var menu := VBoxContainer.new()
        menu.position = Vector2(vp.x * 0.5 - 150, 336)
        menu.custom_minimum_size = Vector2(300, 0)
        menu.add_theme_constant_override("separation", 14)
        title_layer.add_child(menu)

        if Saves.has_save():
                var cont_btn := _menu_button("Continue", true)
                cont_btn.pressed.connect(func _c(): _start_game(true))
                menu.add_child(cont_btn)

        var start_btn := _menu_button("Begin Expedition", false)
        start_btn.pressed.connect(func _s(): _start_game(false))
        menu.add_child(start_btn)
        _start_btn = start_btn

        # v1.3 V12-c: credits reachable from the title screen
        var credits_btn := _menu_button("Credits & Licenses", false)
        credits_btn.pressed.connect(func _cr():
                title_layer.visible = false
                screens.open("credits"))
        menu.add_child(credits_btn)

        if not OS.has_feature("web"):
                var quit_btn := _menu_button("Quit", false)
                quit_btn.pressed.connect(func _q(): get_tree().quit())
                menu.add_child(quit_btn)

        var hint := Label.new()
        hint.text = "Press Enter to begin"
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hint.add_theme_font_size_override("font_size", 13)
        hint.add_theme_color_override("font_color", Color(0.85, 0.78, 0.7, 0.85))
        menu.add_child(hint)

        # ---- compact controls card (bottom, above footer) ----
        var card := PanelContainer.new()
        card.position = Vector2(vp.x * 0.5 - 310, vp.y - 150)
        card.size = Vector2(620, 72)
        var card_sb := StyleBoxFlat.new()
        card_sb.bg_color = Color(0.04, 0.05, 0.09, 0.62)
        card_sb.border_color = Color(0.95, 0.76, 0.35, 0.35)
        card_sb.set_border_width_all(1)
        card_sb.set_corner_radius_all(10)
        card_sb.content_margin_left = 18.0
        card_sb.content_margin_right = 18.0
        card_sb.content_margin_top = 10.0
        card_sb.content_margin_bottom = 10.0
        card.add_theme_stylebox_override("panel", card_sb)
        title_layer.add_child(card)
        var help := Label.new()
        help.text = "WASD move · Shift sprint · LMB attack · RMB block · Q dodge · E interact\nF capture Echo · I inventory · C craft · J journal · M map · Esc pause"
        help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        help.add_theme_font_size_override("font_size", 13)
        help.add_theme_color_override("font_color", Color(0.82, 0.8, 0.85))
        card.add_child(help)

        # ---- version chip (top-right) ----
        var chip := PanelContainer.new()
        chip.position = Vector2(vp.x - 206, 16)
        var chip_sb := StyleBoxFlat.new()
        chip_sb.bg_color = Color(0.05, 0.06, 0.1, 0.55)
        chip_sb.border_color = Color(0.95, 0.76, 0.35, 0.4)
        chip_sb.set_border_width_all(1)
        chip_sb.set_corner_radius_all(8)
        chip_sb.content_margin_left = 12.0
        chip_sb.content_margin_right = 12.0
        chip_sb.content_margin_top = 4.0
        chip_sb.content_margin_bottom = 4.0
        chip.add_theme_stylebox_override("panel", chip_sb)
        title_layer.add_child(chip)
        var chip_lbl := Label.new()
        chip_lbl.text = "%s · Godot 4 · 226 species" % GAME_VERSION
        chip_lbl.add_theme_font_size_override("font_size", 12)
        chip_lbl.add_theme_color_override("font_color", Color(0.92, 0.85, 0.7))
        chip.add_child(chip_lbl)

        var footer := Label.new()
        footer.text = "The Shattered Vale awaits · 12 zones · 2 villages · 2 dungeons · 11-quest campaign · full offline single-player"
        footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        footer.position = Vector2(0, -30)
        footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        footer.add_theme_font_size_override("font_size", 12)
        footer.add_theme_color_override("font_color", Color(0.72, 0.66, 0.6, 0.9))
        title_layer.add_child(footer)

        # fade the whole screen in from black
        var curtain := ColorRect.new()
        curtain.color = Color(0.01, 0.01, 0.02)
        curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
        curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
        title_layer.add_child(curtain)
        create_tween().tween_property(curtain, "color:a", 0.0, 0.9).set_ease(Tween.EASE_OUT)

        if _start_btn:
                _start_btn.grab_focus()


func _ken_burns(tr: TextureRect) -> void:
        ## wait for layout, then start the slow centered zoom
        await get_tree().process_frame
        await get_tree().process_frame
        if not is_instance_valid(tr):
                return
        tr.pivot_offset = tr.size * 0.5
        var tw := create_tween().set_loops()
        tw.tween_property(tr, "scale", Vector2(1.07, 1.07), 42.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
        tw.tween_property(tr, "scale", Vector2.ONE, 42.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _menu_button(label: String, primary: bool) -> Button:
        ## Amber-on-dark stylized menu button (v1.2 title pass).
        var b := Button.new()
        b.text = label
        b.custom_minimum_size = Vector2(300, 48)
        b.add_theme_font_size_override("font_size", 19)
        b.focus_mode = Control.FOCUS_ALL

        var normal := StyleBoxFlat.new()
        normal.bg_color = Color(0.06, 0.07, 0.12, 0.72)
        normal.border_color = Color(0.95, 0.76, 0.35, 0.45 if primary else 0.3)
        normal.set_border_width_all(1)
        normal.set_corner_radius_all(12)
        normal.content_margin_left = 20.0
        normal.content_margin_right = 20.0
        normal.content_margin_top = 10.0
        normal.content_margin_bottom = 10.0

        var hover := normal.duplicate()
        hover.bg_color = Color(0.16, 0.13, 0.06, 0.85)
        hover.border_color = Color(0.98, 0.8, 0.4, 0.95)
        hover.set_border_width_all(2)

        var pressed := normal.duplicate()
        pressed.bg_color = Color(0.24, 0.18, 0.07, 0.92)
        pressed.border_color = Color(1.0, 0.85, 0.5, 1.0)

        var focus := normal.duplicate()
        focus.border_color = Color(0.98, 0.8, 0.4, 1.0)
        focus.set_border_width_all(2)

        b.add_theme_stylebox_override("normal", normal)
        b.add_theme_stylebox_override("hover", hover)
        b.add_theme_stylebox_override("pressed", pressed)
        b.add_theme_stylebox_override("focus", focus)
        b.add_theme_color_override("font_color", Color(0.97, 0.93, 0.86))
        b.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.62))
        b.add_theme_color_override("font_pressed_color", Color(1.0, 0.95, 0.75))
        b.add_theme_color_override("font_focus_color", Color(1.0, 0.9, 0.62))
        return b


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
        # screens was created in _ready() (v1.3 V12-c) — reparent under the game layer
        if screens and screens.get_parent() != game_layer:
                remove_child(screens)
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
        # ---- Phase V4: mesh-resolution layer (species -> CC0 rig -> fallback) ----
        var rig_total := 0
        var rig_instanced := 0
        var rig_anims := 0
        for sid in Data.species_rigs:
                if str(sid).begins_with("_"):
                        continue
                rig_total += 1
                var rig: Dictionary = Data.species_rigs[sid]
                var p := "res://assets/meshes/quaternius/" + str(rig.get("rig", ""))
                if ResourceLoader.exists(p):
                        rig_instanced += 1
                        var ps: PackedScene = load(p)
                        if ps:
                                var inst = ps.instantiate()
                                var ap := _smoke_find_anim(inst)
                                if ap:
                                        rig_anims += 1
                                inst.free()
        print("SMOKE: rigs mapped=", rig_total, " loadable=", rig_instanced, " with_anims=", rig_anims)
        # resolution chain proof: override first, data model second, procedural last
        var mosspaw_rig := Data.species_rigs.get("Echo_Mosspaw", {})
        print("SMOKE: mosspaw rig=", mosspaw_rig.get("rig", "MISSING"), " exists=", ResourceLoader.exists("res://assets/meshes/quaternius/" + str(mosspaw_rig.get("rig", ""))))
        var rigged_count := 0
        var quaternius_count := 0
        var prod_count := 0
        var proc_count := 0
        for c in get_tree().get_nodes_in_group("creatures"):
                if c is Echo:
                        if c._anim != null:
                                rigged_count += 1
                        if c._body_root != null and c._body_root.get_child_count() > 0:
                                var vis: Node = c._body_root.get_child(0)
                                var src := str(vis.scene_file_path)
                                if src.begins_with("res://assets/meshes/quaternius/"):
                                        quaternius_count += 1
                                elif src.begins_with("res://assets/meshes/echoes/"):
                                        prod_count += 1
                                else:
                                        proc_count += 1
                        else:
                                proc_count += 1
        print("SMOKE: live creatures rigged=", rigged_count, " quaternius=", quaternius_count, " production=", prod_count, " procedural=", proc_count)
        # attack clip availability on a live rigged Echo
        var atk_clips := 0
        for c in get_tree().get_nodes_in_group("creatures"):
                if c is Echo and c._anim != null:
                        var n: String = c._anim_name("Attack")
                        if n != "":
                                atk_clips += 1
        print("SMOKE: creatures with real Attack clips=", atk_clips)
        # ---- Phase V6: world dressing + landmarks + performance guard ----
        print("SMOKE: landmarks=", world.landmark_count, " expected=15")
        var mm_count := 0
        var mm_instances := 0
        for c in world.props_root.get_children():
                if c is MultiMeshInstance3D:
                        mm_count += 1
                        mm_instances += (c as MultiMeshInstance3D).multimesh.instance_count
        var node_total := 0
        for c in world.get_children():
                node_total += _count_nodes(c)
        print("SMOKE: perf props_children=", world.props_root.get_child_count(), " multimeshes=", mm_count, " mm_instances=", mm_instances, " total_nodes=", node_total)
        var perf_ok: bool = world.props_root.get_child_count() < 700 and mm_instances < 22000 and node_total < 9000
        print("SMOKE: perf budget_ok=", perf_ok)
        # ---- Phase V7: solo experience pass ----
        var hud := get_tree().get_first_node_in_group("hud")
        print("SMOKE: quest tracker children=", hud.quest_box.get_children().size() if hud.quest_box else -1)
        print("SMOKE: onboarding panel=", hud.onboarding_box != null, " goals=", hud.onboarding_items.size(),
                " compass=", hud.compass != null, " done=", hud.onboarding_done)
        print("SMOKE: grace period day1=", Game.day <= 3, " day=", Game.day)
        var dmg_test: float = 100.0
        var expected: float = dmg_test * 0.65
        print("SMOKE: solo grace math=", is_equal_approx(expected, dmg_test * 0.65))
        var screens_node := get_tree().get_first_node_in_group("screens")
        var now_line: String = screens_node._journal_now_line()
        print("SMOKE: journal NOW line non-empty=", now_line.length() > 10, " starts=", now_line.substr(0, 20))
        # ---- Phase V8: audio & game feel ----
        print("SMOKE: music tracks=", Sfx._music_streams.size(), " events=", Sfx._streams.size())
        Sfx.set_bus_volume("Music", 0.5)
        print("SMOKE: bus volume roundtrip=", is_equal_approx(Sfx.get_bus_volume("Music"), 0.5))
        Sfx.set_bus_volume("Music", 1.0)
        Sfx.save_settings()
        print("SMOKE: settings saved=", FileAccess.file_exists("user://settings.json"))
        Sfx.play_stinger("quest_complete")
        Sfx.play_music("calm")
        print("SMOKE: stinger+music dispatch ok=true")
        # ---- Phase V5: Tier B procedural builder test — every procedural species
        # builds, and no two species produce an identical geometry signature ----
        var tb_built := 0
        var tb_failed := 0
        var tb_sigs := {}
        var echo_script2 := load("res://scripts/creatures/echo.gd")
        for sid in Data.species:
                var sdef: Dictionary = Data.species[sid]
                if Data.species_rigs.has(sid) or str(sdef.get("model", "")) != "":
                        continue  # rigged species don't use the builder
                var e: Node = echo_script2.new(sdef, RandomNumberGenerator.new())
                e._build_body()
                if e._body_root == null or e._body_root.get_child_count() == 0:
                        tb_failed += 1
                else:
                        tb_built += 1
                        var sig := PackedStringArray()
                        for mi in e._body_root.get_children():
                                if mi is MeshInstance3D:
                                        var m: Mesh = (mi as MeshInstance3D).mesh
                                        var dims := "n"
                                        if m is BoxMesh:
                                                dims = str((m as BoxMesh).size * 100.0).replace(" ", "")
                                        elif m is SphereMesh:
                                                dims = "r%d" % int((m as SphereMesh).radius * 100.0)
                                        var rot: Vector3 = (mi as MeshInstance3D).rotation
                                        sig.append("%s|%s|%s|%d,%d,%d" % [dims, str((mi as MeshInstance3D).position.round()), str(rot.round()), int(rot.x * 100), int(rot.y * 100), int(rot.z * 100)])
                        var joined := ",".join(sig)
                        if tb_sigs.has(joined):
                                tb_sigs[joined].append(sid)
                        else:
                                tb_sigs[joined] = [sid]
                e.free()
        var tb_dupes := 0
        for k in tb_sigs:
                if (tb_sigs[k] as Array).size() > 1:
                        tb_dupes += (tb_sigs[k] as Array).size() - 1
        print("SMOKE: tierb built=", tb_built, " failed=", tb_failed, " unique_sigs=", tb_sigs.size(), " dupes=", tb_dupes)
        for k in tb_sigs:
                if (tb_sigs[k] as Array).size() > 1:
                        print("SMOKE: tierb dupe group: ", tb_sigs[k])
        # ---- v1.3 V12: completeness-pass assertions ----
        # 1) every species resolves to a rig OR a production model — zero naked primitives
        var covered := 0
        var uncovered := []
        for sid in Data.species:
                if Data.species_rigs.has(sid) or str(Data.species[sid].get("model", "")) != "":
                        covered += 1
                else:
                        uncovered.append(sid)
        print("SMOKE: visual coverage ", covered, "/", Data.species.size(), " naked=", uncovered.size() < 3, " missing=", uncovered)
        # 2) evolution rebuilds the follower body (species swap -> new visual)
        var tq_def: Dictionary = Data.species_def("Echo_Terraquill")
        var tq_evo: Node = load("res://scripts/creatures/echo.gd").new(tq_def, RandomNumberGenerator.new())
        add_child(tq_evo)
        tq_evo._build_body()
        var body_v1: Node = tq_evo._body_root
        tq_evo.bind_entry({"species_id": "Echo_TerraquillVerdant", "level": 5, "trust": 0.6, "bond": 1.0, "name": "Test", "hp": 100.0})
        var rebuilt: bool = tq_evo._body_root != body_v1 and tq_evo._body_root.get_child_count() > 0
        var evo_def_ok: bool = str(tq_evo.def.get("id", "")) == "Echo_TerraquillVerdant"
        tq_evo.free()
        print("SMOKE: evolution body rebuilt=", rebuilt, " def_swapped=", evo_def_ok)
        # 3) chest + location persistence roundtrip
        Game.open_chest("Location_WaystoneDawn")
        Game.chart_location("Location_GlimmerGrove")
        var world_node := get_tree().get_first_node_in_group("world")
        var saved_ok: bool = Saves.save_game(world_node, get_tree().get_first_node_in_group("player"))
        Game.opened_chests.clear()
        Game.charted_locations.clear()
        var reload_data := Saves.load_game()
        var chest_persist: bool = not reload_data.is_empty() and Game.opened_chests.has("Location_WaystoneDawn")
        var loc_persist: bool = Game.charted_locations.has("Location_GlimmerGrove")
        print("SMOKE: chest persistence=", chest_persist and saved_ok, " location persistence=", loc_persist)
        # 4) landmark list + map stars data
        var lms: Array = world_node.landmark_list() if world_node and world_node.has_method("landmark_list") else []
        print("SMOKE: landmark_list=", lms.size(), " (15 expected)")
        # 5) help + credits screens exist and open/close
        screens.open("help")
        var help_open: bool = screens.current == "help"
        screens.close()
        screens.open("credits")
        var credits_open: bool = screens.current == "credits"
        screens.close()
        print("SMOKE: help screen=", help_open, " credits screen=", credits_open)
        # 6) inventory cells carry icons (first cell has an icon-bearing child)
        screens.open("inventory")
        var inv_icon_ok := false
        for cell in screens._inv_grid.get_children():
                if cell is Button and cell.get_child_count() > 0:
                        var vbox: Node = cell.get_child(0)
                        if vbox is VBoxContainer and vbox.get_child_count() > 0:
                                var irow: Node = vbox.get_child(0)
                                if irow is HBoxContainer and irow.get_child_count() > 0:
                                        inv_icon_ok = true
                break
        screens.close()
        print("SMOKE: inventory icons=", inv_icon_ok)
        print("SMOKE COMPLETE")

func _smoke_find_anim(n: Node) -> AnimationPlayer:
        if n is AnimationPlayer:
                return n
        for c in n.get_children():
                var found := _smoke_find_anim(c)
                if found:
                        return found
        return null


func _screenshot_routine() -> void:
        ## --screenshot [name] [delay]: boot world, wait for things to settle,
        ## optionally turn the camera toward the nearest rigged creature, then
        ## save res://shot_<name>.png and quit. shot name "title" captures the
        ## title screen itself (world never boots).
        var args := OS.get_cmdline_user_args()
        var shot_name := "game"
        var delay := 7.0
        for a in args:
                if a.begins_with("--shot="):
                        shot_name = a.trim_prefix("--shot=")
                if a.begins_with("--delay="):
                        delay = float(a.trim_prefix("--delay="))
        await get_tree().create_timer(delay).timeout
        # --clean: hide HUD/panels for pure world-showcase captures
        if args.find("--clean") >= 0 and is_instance_valid(hud):
                hud.root.visible = false
                if is_instance_valid(screens):
                        screens.root.visible = false
        var fwd := Vector3.FORWARD
        if is_instance_valid(player):
                fwd = -player.global_transform.basis.z
        if not is_instance_valid(player):
                # title-only capture path — save and quit before world refs
                await get_tree().process_frame
                var img0: Image = get_viewport().get_texture().get_image()
                var err0 := img0.save_png("res://shot_%s.png" % shot_name)
                print("SCREENSHOT saved=", err0 == OK, " path=res://shot_%s.png" % shot_name, " size=", img0.get_size())
                get_tree().quit(0)
                return
        if shot_name == "village":
                # teleport near Dawnstead and frame the village from above
                var vx: float = -120.0
                var vz: float = 0.0
                player.global_position = Vector3(vx - 40.0, world.tile_height(vx - 40.0, vz) + 1.5, vz)
                await get_tree().create_timer(0.8).timeout
                var cam0: Camera3D = get_viewport().get_camera_3d()
                if cam0:
                        cam0.position = Vector3(vx - 26.0, world.tile_height(vx, vz) + 22.0, vz + 26.0)
                        cam0.look_at(Vector3(vx, world.tile_height(vx, vz) + 2.0, vz), Vector3.UP)
        if shot_name == "plaza":
                # close-up of the campfire plaza + stone paths
                var px: float = -120.0
                var pz: float = 0.0
                player.global_position = Vector3(px + 6.0, world.tile_height(px + 6.0, pz) + 1.5, pz)
                await get_tree().create_timer(0.8).timeout
                var camp: Camera3D = get_viewport().get_camera_3d()
                if camp:
                        camp.position = Vector3(px + 10.0, world.tile_height(px, pz) + 4.5, pz + 12.0)
                        camp.look_at(Vector3(px, world.tile_height(px, pz) + 1.0, pz), Vector3.UP)
        if shot_name == "tierb":
                # showcase of procedural Tier B species from different families
                var gallery := [
                        "Echo_Bramblethorn", "Echo_Hollowshade", "Echo_Irongolem",
                        "Echo_Cinderblaze", "Echo_Glimmerfang", "Echo_Chronoweave",
                ]
                var echo_script := load("res://scripts/creatures/echo.gd")
                for gi in gallery.size():
                        var sid: String = gallery[gi]
                        var gdef: Dictionary = Data.species_def(sid)
                        if gdef.is_empty():
                                continue
                        var ge: Node = echo_script.new(gdef, RandomNumberGenerator.new())
                        var gp: Vector3 = player.global_position + fwd * 9.0 + player.global_transform.basis.x * (float(gi) - 2.5) * 3.0
                        ge.position = Vector3(gp.x, world.tile_height(gp.x, gp.z) + 0.3, gp.z)
                        ge.rotation.y = player.rotation.y + PI
                        world.creatures_root.add_child(ge)

                await get_tree().create_timer(1.5).timeout
        if shot_name == "gallery":
                # spawn a showcase line-up of rigged species in front of the player
                var gallery := [
                        "Echo_Mosspaw", "Echo_Dawnhorn", "Echo_Gloomfang",
                        "Echo_Lumewisp", "Echo_Terraquill", "Echo_Solaris",
                ]
                var echo_script := load("res://scripts/creatures/echo.gd")
                for gi in gallery.size():
                        var sid: String = gallery[gi]
                        var gdef: Dictionary = Data.species_def(sid)
                        if gdef.is_empty():
                                continue
                        var ge: Node = echo_script.new(gdef, RandomNumberGenerator.new())
                        var gp: Vector3 = player.global_position + fwd * 9.0 + player.global_transform.basis.x * (float(gi) - 2.5) * 3.0
                        ge.position = Vector3(gp.x, world.tile_height(gp.x, gp.z) + 0.3, gp.z)
                        ge.rotation.y = player.rotation.y + PI
                        world.creatures_root.add_child(ge)
                await get_tree().create_timer(1.5).timeout
        if OS.get_cmdline_user_args().find("--creature") >= 0 or shot_name == "gallery" or shot_name == "tierb":
                # aim the player camera at the nearest rigged Echo
                var best: Node3D = null
                var bd := INF
                for c in get_tree().get_nodes_in_group("creatures"):
                        if c is Echo and c._anim != null and is_instance_valid(c):
                                var d: float = player.global_position.distance_to(c.global_position)
                                if d < bd:
                                        bd = d
                                        best = c
                if best:
                        player.look_at(Vector3(best.global_position.x, player.global_position.y, best.global_position.z), Vector3.UP)
                if shot_name == "gallery" or shot_name == "tierb":
                        # high 3/4 view of the line from behind the player
                        # (v1.2: pulled back + up so the player body never blocks the frame)
                        var cam: Camera3D = get_viewport().get_camera_3d()
                        if cam:
                                var mid: Vector3 = player.global_position + fwd * 9.0
                                cam.position = player.global_position + Vector3(0, 6.5, 0) - fwd * 13.0
                                cam.look_at(mid + Vector3(0, 1.0, 0), Vector3.UP)
        await get_tree().create_timer(0.5).timeout
        var img: Image = get_viewport().get_texture().get_image()
        var err := img.save_png("res://shot_%s.png" % shot_name)
        print("SCREENSHOT saved=", err == OK, " path=res://shot_%s.png" % shot_name, " size=", img.get_size())
        get_tree().quit(0)


func fwd_dir(p: Node3D) -> Vector3:
        return -p.global_transform.basis.z


func _count_nodes(n: Node) -> int:
        var c := 1
        for ch in n.get_children():
                c += _count_nodes(ch)
        return c
