class_name CheatConsole
extends CanvasLayer
## Debug/cheat console (UE5 UAstrawildCheatManager — 15 commands, Batch 4).
## Toggle with ` (backquote). All commands work with or without the AW. prefix.

var _panel: PanelContainer
var _log_box: RichTextLabel
var _cmd_input: LineEdit
var _open := false


func _ready() -> void:
        layer = 50
        process_mode = Node.PROCESS_MODE_ALWAYS
        _build_ui()
        _log("ASTRAWILD debug console — type `help` for the command list.")


func _build_ui() -> void:
        _panel = PanelContainer.new()
        _panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
        _panel.position = Vector2(120, 60)
        _panel.custom_minimum_size = Vector2(640, 0)
        _panel.visible = false
        add_child(_panel)

        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.05, 0.06, 0.09, 0.94)
        style.border_color = Color(0.95, 0.75, 0.35)
        style.set_border_width_all(1)
        style.set_corner_radius_all(6)
        style.content_margin_left = 12.0
        style.content_margin_right = 12.0
        style.content_margin_top = 10.0
        style.content_margin_bottom = 10.0
        _panel.add_theme_stylebox_override("panel", style)

        var box := VBoxContainer.new()
        box.add_theme_constant_override("separation", 8)
        _panel.add_child(box)

        var title := Label.new()
        title.text = "ASTRAWILD · AW.CheatManager"
        title.add_theme_font_size_override("font_size", 13)
        title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
        box.add_child(title)

        _log_box = RichTextLabel.new()
        _log_box.bbcode_enabled = true
        _log_box.scroll_following = true
        _log_box.custom_minimum_size = Vector2(616, 220)
        _log_box.add_theme_font_size_override("normal_font_size", 12)
        box.add_child(_log_box)

        _cmd_input = LineEdit.new()
        _cmd_input.placeholder_text = "AW.GiveItem Item_Resonator 5   ·   help"
        _cmd_input.add_theme_font_size_override("font_size", 13)
        _cmd_input.text_submitted.connect(func cmd(text: String): _run(text))
        box.add_child(_cmd_input)


func _input(event: InputEvent) -> void:
        if event is InputEventKey and event.pressed and not event.echo:
                if event.keycode == KEY_QUOTELEFT or event.physical_keycode == KEY_QUOTELEFT:
                        _toggle()
                        get_viewport().set_input_as_handled()


func _toggle() -> void:
        _open = not _open
        _panel.visible = _open
        if _open:
                _cmd_input.grab_focus()
                _cmd_input.call_deferred("grab_focus")
                if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
                        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        else:
                if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
                        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _log(text: String, color: Color = Color(0.85, 0.88, 0.92)) -> void:
        if _log_box:
                _log_box.append_text("[color=#%s]%s[/color]\n" % [color.to_html(false), text])


func _run(text: String) -> void:
        _cmd_input.clear()
        var raw := text.strip_edges()
        if raw == "":
                return
        _log("> " + raw, Color(0.95, 0.75, 0.35))
        var parts := raw.replace("AW.", "").split(" ", false)
        if parts.is_empty():
                return
        var cmd: String = parts[0].to_lower()
        var args: Array = parts.slice(1)
        match cmd:
                "help":
                        _log("SpawnEcho <species> | GiveItem <item> [qty] | BuyItem <item> [qty]")
                        _log("SellItem <item> [qty] | EquipItem <item> | SetTime <h> [m] | SetWeather <name>")
                        _log("God | HealAll | ResearchPoints <n> | UnlockTech <tech> | SaveNow | LoadNow")
                        _log("CaptureAll | TeleportForward <m> | ListSpecies | ListItems | ListTech")
                "spawnecho":
                        _cmd_spawn_echo(args)
                "giveitem":
                        _cmd_give_item(args)
                "buyitem":
                        _cmd_buy_item(args)
                "sellitem":
                        _cmd_sell_item(args)
                "equipitem":
                        _cmd_equip_item(args)
                "settime":
                        _cmd_set_time(args)
                "setweather":
                        _cmd_set_weather(args)
                "god":
                        Game.god_mode = not Game.god_mode
                        _log("God mode %s" % ("ON" if Game.god_mode else "OFF"), Color(0.6, 1.0, 0.6))
                "healall":
                        Game.full_restore()
                        for e in Game.party:
                                e["hp"] = Data.species_def(e["species_id"]).get("stats", {}).get("hp", 100)
                        _log("Player + party fully restored.", Color(0.6, 1.0, 0.6))
                "researchpoints", "rp":
                        var n := int(args[0]) if args.size() > 0 and args[0].is_valid_int() else 10
                        Game.add_research_points(n)
                        _log("+%d research points (total %d)" % [n, Game.research_points], Color(0.7, 0.85, 1.0))
                "unlocktech":
                        if args.size() > 0:
                                if Game.is_tech_unlocked(str(args[0])):
                                        _log("Already unlocked: %s" % args[0], Color(1.0, 0.7, 0.5))
                                else:
                                        Game.force_unlock_tech(str(args[0]))
                                        _log("Force-unlocked %s" % args[0], Color(0.7, 0.85, 1.0))
                "savenow":
                        var world := get_tree().get_first_node_in_group("world")
                        var player := get_tree().get_first_node_in_group("player")
                        Saves.save_game(world, player)
                        _log("Saved.", Color(0.6, 1.0, 0.6))
                "loadnow":
                        if Saves.has_save():
                                var world := get_tree().get_first_node_in_group("world")
                                var player := get_tree().get_first_node_in_group("player")
                                var data := Saves.load_game()
                                if not data.is_empty():
                                        Saves._apply(data)
                                        var pos := Saves.player_pos(data)
                                        if player and world:
                                                player.global_position = pos
                                        _log("Loaded.", Color(0.6, 1.0, 0.6))
                        else:
                                _log("No save found.", Color(1.0, 0.7, 0.5))
                "captureall":
                        _cmd_capture_all()
                "teleportforward":
                        var d := float(args[0]) if args.size() > 0 and args[0].is_valid_float() else 10.0
                        _cmd_teleport(d)
                "listspecies":
                        var ids := []
                        for s in Data.species.keys():
                                ids.append(s)
                        _log("%d species — try: AW.SpawnEcho Echo_Gloomfang | Echo_Sprigling | Echo_Auroraling ..." % ids.size())
                "listitems":
                        var names := []
                        for k in Game.inventory.keys():
                                names.append("%s x%d" % [k, Game.inventory[k]])
                        _log("Carried: %s" % ", ".join(names))
                "listtech":
                        var t := []
                        for k in Data.techs.keys():
                                t.append("%s%s" % ["[x] " if Game.is_tech_unlocked(k) else "[ ] ", k])
                        _log(" · ".join(t))
                _:
                        _log("Unknown command: %s (try `help`)" % cmd, Color(1.0, 0.7, 0.5))


func _cmd_spawn_echo(args: Array) -> void:
        if args.is_empty():
                _log("Usage: AW.SpawnEcho <EchoDefinitionId>", Color(1.0, 0.7, 0.5))
                return
        var def: Dictionary = Data.species_def(str(args[0]))
        if def.is_empty():
                _log("AW.SpawnEcho: unknown Echo id %s." % args[0], Color(1.0, 0.7, 0.5))
                return
        var world := get_tree().get_first_node_in_group("world")
        var player: Node3D = get_tree().get_first_node_in_group("player")
        if world == null or player == null:
                return
        var rng := RandomNumberGenerator.new()
        rng.seed = hash("cheat-%d" % Time.get_ticks_msec())
        var fwd: Vector3 = -player.global_basis.z
        var pos: Vector3 = player.global_position + fwd * 6.0
        pos.y = world.tile_height(pos.x, pos.z)
        var echo = world._spawn_creature(def, pos, rng)
        _log("Spawned %s ahead." % def.get("name", args[0]), Color(0.6, 1.0, 0.6))


func _cmd_give_item(args: Array) -> void:
        if args.is_empty():
                _log("Usage: AW.GiveItem <ItemId> [Quantity]", Color(1.0, 0.7, 0.5))
                return
        var qty := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 1
        if Data.item(str(args[0])).is_empty():
                _log("AW.GiveItem: unknown item %s." % args[0], Color(1.0, 0.7, 0.5))
                return
        Game.add_item(str(args[0]), qty)
        _log("Gave %d x %s." % [qty, Data.item_name(str(args[0]))], Color(0.6, 1.0, 0.6))


func _cmd_buy_item(args: Array) -> void:
        if args.is_empty():
                _log("Usage: AW.BuyItem <ItemId> [Quantity] — needs a vendor within 6 m", Color(1.0, 0.7, 0.5))
                return
        var qty := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 1
        var item: Dictionary = Data.item(str(args[0]))
        if item.is_empty():
                _log("AW.BuyItem: unknown item %s." % args[0], Color(1.0, 0.7, 0.5))
                return
        var price := int(item.get("vendor_price", 2)) * qty
        if Game.count_item("Item_DawnShard") < price:
                _log("AW.BuyItem: need %d Dawn Shards." % price, Color(1.0, 0.7, 0.5))
                return
        Game.remove_item("Item_DawnShard", price)
        Game.add_item(str(args[0]), qty)
        _log("Bought %d x %s for %d shards." % [qty, Data.item_name(str(args[0])), price], Color(0.6, 1.0, 0.6))


func _cmd_sell_item(args: Array) -> void:
        if args.is_empty():
                _log("Usage: AW.SellItem <ItemId> [Quantity]", Color(1.0, 0.7, 0.5))
                return
        var qty := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 1
        var item: Dictionary = Data.item(str(args[0]))
        if item.is_empty() or Game.count_item(str(args[0])) < qty:
                _log("AW.SellItem: you don't carry %d x %s." % [qty, args[0]], Color(1.0, 0.7, 0.5))
                return
        var price := maxi(1, int(item.get("vendor_price", 2)) / 2) * qty
        Game.remove_item(str(args[0]), qty)
        Game.add_item("Item_DawnShard", price)
        _log("Sold %d x %s for %d shards." % [qty, Data.item_name(str(args[0])), price], Color(0.6, 1.0, 0.6))


func _cmd_equip_item(args: Array) -> void:
        if args.is_empty():
                _log("Usage: AW.EquipItem <ItemId>", Color(1.0, 0.7, 0.5))
                return
        var item: Dictionary = Data.item(str(args[0]))
        if item.is_empty() or not item.has("slot"):
                _log("AW.EquipItem failed — item missing or not equipment: %s" % args[0], Color(1.0, 0.7, 0.5))
                return
        Game.equip(str(item["slot"]), str(args[0]))
        _log("Equipped %s." % Data.item_name(str(args[0])), Color(0.6, 1.0, 0.6))


func _cmd_set_time(args: Array) -> void:
        if args.is_empty() or not args[0].is_valid_int():
                _log("Usage: AW.SetTime <Hour> [Minute]", Color(1.0, 0.7, 0.5))
                return
        var h := clampi(int(args[0]), 0, 23)
        var m := clampi(int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 0, 0, 59)
        Game.time_minutes = float(h * 60 + m)
        Game.time_changed.emit(Game.day, int(Game.time_minutes))
        _log("World clock set to %02d:%02d." % [h, m], Color(0.6, 1.0, 0.6))


func _cmd_set_weather(args: Array) -> void:
        if args.is_empty():
                _log("Usage: AW.SetWeather clear|cloudy|rain|heavyrain|storm|fog|heat|cold", Color(1.0, 0.7, 0.5))
                return
        var wname := str(args[0]).to_lower()
        var map := {"clear": "Clear", "cloudy": "Cloudy", "rain": "Rain", "heavyrain": "HeavyRain",
                "storm": "Storm", "fog": "Fog", "heat": "Heatwave", "cold": "ColdSnap"}
        var wid: String = map.get(wname, "")
        var valid := false
        for w in Data.weather_states:
                if w["id"] == wid:
                        valid = true
        if wid == "" or not valid:
                _log("AW.SetWeather: unknown weather %s (clear/cloudy/rain/heavyrain/storm/fog/heat/cold)." % wname, Color(1.0, 0.7, 0.5))
                return
        Game.weather_id = wid
        Game.weather_changed.emit(wid)
        _log("Weather set to %s." % wid, Color(0.6, 1.0, 0.6))


func _cmd_capture_all() -> void:
        var world := get_tree().get_first_node_in_group("world")
        if world == null or world.get("creatures_root") == null:
                return
        var count := 0
        for c in world.creatures_root.get_children():
                if c.get("def") == null or c.get("captured", false) or c.get("defeated", false):
                        continue
                if c.def.get("hostile", false):
                        continue
                if Game.party.size() >= Game.MAX_PARTY:
                        break
                Game.party.append({
                        "species_id": c.def["id"], "name": c.def["name"], "level": 1, "xp": 0.0,
                        "trust": 10.0, "bond": 0.0, "mood": 70.0, "hunger": 60.0, "energy": 80.0,
                        "hp": c.def["stats"]["hp"], "passive": str(c.def.get("passive", ""))})
                c.become_captured(get_tree().get_first_node_in_group("player"))
                count += 1
        Game.party_changed.emit()
        _log("CaptureAll: tamed %d nearby Echoes into the party." % count, Color(0.6, 1.0, 0.6))


func _cmd_teleport(distance: float) -> void:
        var player: Node3D = get_tree().get_first_node_in_group("player")
        var world := get_tree().get_first_node_in_group("world")
        if player == null or world == null:
                return
        var fwd: Vector3 = -player.global_basis.z
        var pos: Vector3 = player.global_position + fwd * distance
        pos.y = world.tile_height(pos.x, pos.z) + 0.5
        player.global_position = pos
        player.velocity = Vector3.ZERO
        _log("Teleported %d m forward." % int(distance), Color(0.6, 1.0, 0.6))
