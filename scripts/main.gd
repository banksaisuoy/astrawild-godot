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
	center.add_child(start_btn)

	if Saves.has_save():
		var cont_btn := Button.new()
		cont_btn.text = "Continue"
		cont_btn.custom_minimum_size = Vector2(260, 44)
		cont_btn.add_theme_font_size_override("font_size", 18)
		cont_btn.pressed.connect(func _c(): _start_game(true))
		center.add_child(cont_btn)

	var help := Label.new()
	help.text = "\nWASD move · Shift sprint · LMB attack (hold = heavy) · RMB block\nE interact · F capture Echo · G feed · aim at creatures to observe\nI inventory · C craft · R research · J journal · B build · M map\n\nA Godot port of the ASTRAWILD Unreal Engine 5 project."
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	center.add_child(help)

	var footer := Label.new()
	footer.text = "The Shattered Vale · 12 zones · 226 Echo species · Godot 4"
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.position = Vector2(0, -30)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.5, 0.55, 0.65))
	title_layer.add_child(footer)


func _start_game(continue_save: bool) -> void:
	if _started:
		return
	_started = true
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
		Game.toast.emit("Welcome to the Dawn Fields. Follow the quest ✦ top-right.", Color(0.95, 0.9, 0.75))
		Game.toast.emit("Aim at creatures to observe them. Weaken, then [F] to capture.", Color(0.8, 0.9, 1.0))
	if OS.get_cmdline_user_args().find("--smoke") >= 0:
		_run_smoke_checks()


func _run_smoke_checks() -> void:
	await get_tree().create_timer(1.0).timeout
	print("SMOKE: creatures=", get_tree().get_nodes_in_group("creatures").size())
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
	for i in 6:
		await get_tree().create_timer(0.5).timeout
		print("SMOKE: t", i, " player y=", player.global_position.y, " floor=", player.is_on_floor(), " terr=", world.tile_height(player.global_position.x, player.global_position.z))
	print("SMOKE: after 3s: craft queue=", Game.craft_queue.size(), " resonators=", Game.count_item("Item_Resonator"))
	print("SMOKE COMPLETE")
