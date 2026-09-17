class_name Hud
extends CanvasLayer
## In-game HUD: vitals, clock/zone/weather, quest tracker, party cards,
## interact prompts, capture chance, observation ring, boss bar, toasts.

var root: Control
var bars := {}
var clock_label: Label
var zone_label: Label
var weather_label: Label
var quest_box: VBoxContainer
var party_box: HBoxContainer
var prompt_label: Label
var capture_label: Label
var toast_box: VBoxContainer
var crosshair: Control
var observe_ring: Control
var boss_bar: ProgressBar
var boss_label: Label
var hint_label: Label
var _toast_timers := []


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	Game.toast.connect(_add_toast)
	Game.stats_changed.connect(_refresh_bars)
	Game.inventory_changed.connect(func _s(): pass)
	Game.time_changed.connect(_refresh_clock)
	Game.zone_changed.connect(func _z(_id): _refresh_clock(0, 0))
	Game.weather_changed.connect(func _w(_id): _refresh_clock(0, 0))
	Game.quest_changed.connect(_refresh_quest)
	Game.party_changed.connect(_refresh_party)
	Game.capture_attempt.connect(_on_capture_flash)
	_build()


func _build() -> void:
	# --- vitals panel (top-left) ---
	var vitals := _panel(Vector2(16, 16), Vector2(260, 128))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 12
	vb.offset_top = 10
	vb.add_theme_constant_override("separation", 6)
	vitals.add_child(vb)
	bars["hp"] = _bar_row(vb, "HP", Color(0.89, 0.37, 0.33), 100)
	bars["stamina"] = _bar_row(vb, "Stamina", Color(0.55, 0.85, 0.5), 100)
	bars["hunger"] = _bar_row(vb, "Hunger", Color(0.95, 0.72, 0.35), 100)
	bars["thirst"] = _bar_row(vb, "Thirst", Color(0.45, 0.75, 0.85), 100)

	# --- clock panel (top-center) ---
	var clock_panel := _panel(Vector2(0, 16), Vector2(320, 74))
	clock_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	clock_panel.position = Vector2(-160, 16)
	var cb := VBoxContainer.new()
	cb.set_anchors_preset(Control.PRESET_FULL_RECT)
	cb.offset_left = 10
	cb.offset_top = 6
	cb.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_panel.add_child(cb)
	zone_label = Label.new()
	zone_label.add_theme_font_size_override("font_size", 18)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cb.add_child(zone_label)
	var clock_row := HBoxContainer.new()
	clock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	clock_row.add_theme_constant_override("separation", 10)
	cb.add_child(clock_row)
	clock_label = Label.new()
	clock_label.add_theme_font_size_override("font_size", 15)
	clock_row.add_child(clock_label)
	weather_label = Label.new()
	weather_label.add_theme_font_size_override("font_size", 15)
	weather_label.modulate = Color(0.8, 0.85, 0.95)
	clock_row.add_child(weather_label)

	# --- quest tracker (top-right) ---
	var quest_panel := _panel(Vector2(-316, 16), Vector2(300, 150))
	quest_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quest_panel.position = Vector2(-316, 16)
	quest_box = VBoxContainer.new()
	quest_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	quest_box.offset_left = 10
	quest_box.offset_top = 8
	quest_box.add_theme_constant_override("separation", 3)
	quest_panel.add_child(quest_box)

	# --- party cards (bottom-left) ---
	party_box = HBoxContainer.new()
	party_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	party_box.position = Vector2(16, -80)
	party_box.add_theme_constant_override("separation", 8)
	root.add_child(party_box)

	# --- prompt (bottom-center) ---
	prompt_label = Label.new()
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-200, -110)
	prompt_label.custom_minimum_size = Vector2(400, 26)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_outline", Color(0, 0, 0, 0.8))
	prompt_label.add_theme_constant_override("outline_size", 6)
	root.add_child(prompt_label)

	capture_label = Label.new()
	capture_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	capture_label.position = Vector2(-260, -84)
	capture_label.custom_minimum_size = Vector2(520, 24)
	capture_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capture_label.add_theme_font_size_override("font_size", 15)
	capture_label.add_theme_color_override("font_outline", Color(0, 0, 0, 0.8))
	capture_label.add_theme_constant_override("outline_size", 6)
	root.add_child(capture_label)

	# --- crosshair + observation ring (center) ---
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.custom_minimum_size = Vector2(8, 8)
	crosshair.draw.connect(func _draw(): crosshair.draw_circle(Vector2(4, 4), 2.5, Color(1, 1, 1, 0.75)))
	root.add_child(crosshair)

	observe_ring = Control.new()
	observe_ring.set_anchors_preset(Control.PRESET_CENTER)
	observe_ring.custom_minimum_size = Vector2(48, 48)
	observe_ring.position = Vector2(-24, -24)
	observe_ring.draw.connect(_draw_observe_ring)
	root.add_child(observe_ring)

	# --- boss bar (upper-center) ---
	boss_bar = ProgressBar.new()
	boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_bar.position = Vector2(-220, 96)
	boss_bar.custom_minimum_size = Vector2(440, 18)
	boss_bar.min_value = 0
	boss_bar.max_value = 600
	boss_bar.show_percentage = false
	_style_progress(boss_bar, Color(0.85, 0.25, 0.2))
	root.add_child(boss_bar)
	boss_label = Label.new()
	boss_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_label.position = Vector2(-160, 118)
	boss_label.custom_minimum_size = Vector2(320, 22)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.add_theme_font_size_override("font_size", 15)
	boss_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
	root.add_child(boss_label)
	boss_bar.visible = false
	boss_label.visible = false

	# --- toasts (bottom-center stack) ---
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast_box.position = Vector2(-260, -160)
	toast_box.custom_minimum_size = Vector2(520, 0)
	toast_box.alignment = BoxContainer.ALIGNMENT_END
	toast_box.add_theme_constant_override("separation", 4)
	root.add_child(toast_box)

	# --- controls hint (bottom-right) ---
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_label.position = Vector2(-330, -130)
	hint_label.custom_minimum_size = Vector2(316, 120)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9, 0.85))
	hint_label.add_theme_color_override("font_outline", Color(0, 0, 0, 0.7))
	hint_label.add_theme_constant_override("outline_size", 4)
	hint_label.text = "WASD move · Shift sprint · Space jump · Q dodge\nLMB light / hold heavy · RMB block\nE interact · F capture · G feed\nI inv · C craft · R research · J journal\nB build · M map · 1/2/3 party · Esc menu"
	root.add_child(hint_label)

	_refresh_bars()
	_refresh_clock(1, 480)
	_refresh_quest()
	_refresh_party()


func _panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.82)
	style.set_border_width_all(1)
	style.set_border_color(Color(0.25, 0.32, 0.42, 0.9))
	style.set_corner_radius_all(6)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", style)
	p.position = pos
	p.custom_minimum_size = size
	root.add_child(p)
	return p


func _bar_row(parent: Control, label: String, color: Color, max_val: float) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(64, 18)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color.lightened(0.25))
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 14)
	bar.min_value = 0
	bar.max_value = max_val
	bar.show_percentage = false
	_style_progress(bar, color)
	row.add_child(bar)
	return bar


func _style_progress(bar: ProgressBar, color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.12, 0.16, 0.9)
	bg.set_corner_radius_all(4)
	bg.set_border_width_all(1)
	bg.set_border_color(Color(0.2, 0.25, 0.33))
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)


func _refresh_bars() -> void:
	if bars.is_empty():
		return
	bars["hp"].value = Game.hp
	bars["stamina"].value = Game.stamina
	bars["hunger"].value = Game.hunger
	bars["thirst"].value = Game.thirst


func _refresh_clock(_day: int, _min: int) -> void:
	clock_label.text = "Day %d  %s" % [Game.day, Game.clock_text()]
	weather_label.text = Game.weather_id
	var z := Data.zone(Game.current_zone_id)
	zone_label.text = z.get("name", "—")
	_refresh_bars()


func _refresh_quest() -> void:
	for c in quest_box.get_children():
		c.queue_free()
	var q: Dictionary = Game.active_quest_data()
	if q.is_empty():
		return
	var title := Label.new()
	title.text = "✦ %s" % q.get("title", "")
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	quest_box.add_child(title)
	var state: Dictionary = Game.quest_states.get(Game.active_quest, {})
	var objs: Array = q.get("objectives", [])
	for i in objs.size():
		var progress: int = state.get("objectives", [])[i] if not state.is_empty() else 0
		var need: int = int(objs[i]["count"])
		var l := Label.new()
		var done := progress >= need
		l.text = "%s %s %d/%d" % ["✔" if done else "•", objs[i]["text"], mini(progress, need), need]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8) if done else Color(0.85, 0.85, 0.9))
		quest_box.add_child(l)


func _refresh_party() -> void:
	for c in party_box.get_children():
		c.queue_free()
	for entry in Game.party:
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.06, 0.08, 0.12, 0.82)
		card_style.set_border_width_all(1)
		card_style.set_border_color(Color(0.25, 0.32, 0.42, 0.9))
		card_style.set_corner_radius_all(6)
		card_style.content_margin_left = 4
		card_style.content_margin_right = 4
		card_style.content_margin_top = 4
		card_style.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", card_style)
		card.custom_minimum_size = Vector2(150, 64)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.offset_left = 8
		vb.offset_top = 4
		card.add_child(vb)
		var name_l := Label.new()
		name_l.text = "%s Lv%d" % [entry.get("name", "?"), int(entry.get("level", 1))]
		name_l.add_theme_font_size_override("font_size", 13)
		name_l.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
		vb.add_child(name_l)
		var stage_l := Label.new()
		stage_l.text = Game.trust_stage(float(entry.get("trust", 0.0)))
		stage_l.add_theme_font_size_override("font_size", 11)
		stage_l.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
		vb.add_child(stage_l)
		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(120, 8)
		hp_bar.min_value = 0
		hp_bar.max_value = Data.species_def(entry.get("species_id", "")).get("stats", {}).get("hp", 100)
		hp_bar.value = entry.get("hp", 100)
		hp_bar.show_percentage = false
		_style_progress(hp_bar, Color(0.6, 1.0, 0.7))
		vb.add_child(hp_bar)
		party_box.add_child(card)


func _process(_delta: float) -> void:
	_update_prompt()
	_update_boss()


func _update_prompt() -> void:
	var screens := get_tree().get_first_node_in_group("screens")
	if screens and screens.has_method("is_open") and screens.is_open():
		prompt_label.text = ""
		capture_label.text = ""
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	# interact prompt
	var prompt := ""
	if player.has_method("in_build_mode") and player.in_build_mode():
		var build_def: Dictionary = player.get("build_def") if player.get("build_def") != null else {}
		prompt = "Place: %s · [/] cycle · [,][.] rotate · [E] place · [B] exit" % build_def.get("name", "")
	else:
		var target = null
		if player.has_method("_nearest_interactable"):
			target = player.call("_nearest_interactable")
		if target and target.has_method("prompt"):
			prompt = target.prompt()
	prompt_label.text = prompt
	# capture chance
	var text := ""
	if player.has_method("observed_echo"):
		var echo: Echo = player.observed_echo()
		if echo and not echo.captured and not echo.is_defeated():
			var chance: float = Game.capture_chance(echo)
			var trust: int = int(echo.trust)
			text = "%s — capture %d%% · trust %d · [F] resonator" % [echo.def.get("name", "Echo"), int(chance * 100), trust]
			if Game.count_item("Item_Resonator") <= 0:
				text += " (no resonators!)"
	capture_label.text = text


func _update_boss() -> void:
	var boss: Echo = null
	for c in get_tree().get_nodes_in_group("creatures"):
		if c is Echo and c.boss_mode and not c.is_defeated():
			var player := get_tree().get_first_node_in_group("player")
			if player and c.global_position.distance_to(player.global_position) < 60.0:
				boss = c
				break
	if boss:
		boss_bar.visible = true
		boss_label.visible = true
		boss_bar.max_value = boss.max_hp
		boss_bar.value = boss.hp
		boss_label.text = "☠ %s — Phase %d" % [boss.def.get("name", "Boss"), boss._phase]
	else:
		boss_bar.visible = false
		boss_label.visible = false


func _draw_observe_ring() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var echo: Echo = player.observed_echo() if player.has_method("observed_echo") else null
	if echo == null:
		return
	var p: float = Game.observe_progress(echo.def["id"])
	if p <= 0.0:
		return
	observe_ring.draw_arc(Vector2(24, 24), 20.0, -PI / 2.0, -PI / 2.0 + TAU * p / 100.0, 24, Color(0.75, 0.95, 1.0, 0.9), 3.0)


func _add_toast(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(520, 22)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	toast_box.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(3.2)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_capture_flash(_species_id: String, success: bool) -> void:
	var flash := ColorRect.new()
	flash.color = Color(0.7, 1.0, 0.8, 0.25) if success else Color(1.0, 0.7, 0.5, 0.18)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.5)
	tw.tween_callback(flash.queue_free)
