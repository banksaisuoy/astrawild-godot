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
# PS-9: phase pips (3 diamonds under the bar) + smooth drain + phase colour
var boss_pips: Array = []
var _boss_id := 0
var _boss_shown_hp := -1.0
var _boss_phase_seen := 0
const BOSS_PHASE_COLORS := [
        Color(0.82, 0.32, 0.22),
        Color(1.0, 0.45, 0.16),
        Color(1.0, 0.16, 0.12),
]
const BOSS_PIP_LIT := [Color(1.0, 0.82, 0.35), Color(1.0, 0.62, 0.25), Color(1.0, 0.3, 0.22)]
const BOSS_PIP_DIM := Color(0.16, 0.14, 0.12)
var hint_label: Label
var _toast_timers := []
# PS-1: damage vignette (red edge flash when the player takes a hit)
var _dmg_vignette: ColorRect
var _dmg_vignette_a := 0.0
var _last_hp_seen := -1.0
# v1.1 Phase V7: onboarding + compass
var onboarding_box: VBoxContainer
var onboarding_items := {}
var onboarding_icons := {}
var onboarding_done := false
var compass: Control
var compass_width := 340.0
# PS-8: corner radar minimap (blips + landmarks + zone name)
var minimap: Control
var minimap_zone: Label
const MINIMAP_R := 92.0
const MINIMAP_RANGE := 70.0


func _ready() -> void:
        layer = 10
        root = Control.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.mouse_filter = Control.MOUSE_FILTER_IGNORE
        add_child(root)
        # PS-1: full-screen damage vignette (edge flash), fades in _process
        _dmg_vignette = ColorRect.new()
        _dmg_vignette.color = Color(0.55, 0.04, 0.04, 0.0)
        _dmg_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
        _dmg_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(_dmg_vignette)
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
        var vitals := _panel(Vector2(16, 16), Vector2(268, 128))
        var vb := VBoxContainer.new()
        vb.set_anchors_preset(Control.PRESET_FULL_RECT)
        vb.offset_left = 12
        vb.offset_top = 10
        vb.add_theme_constant_override("separation", 6)
        vitals.add_child(vb)
        bars["hp"] = _bar_row(vb, "HP", Color(0.89, 0.37, 0.33), 100, "heart")
        bars["stamina"] = _bar_row(vb, "Stamina", Color(0.55, 0.85, 0.5), 100, "bolt")
        bars["hunger"] = _bar_row(vb, "Hunger", Color(0.95, 0.72, 0.35), 100, "meat")
        bars["thirst"] = _bar_row(vb, "Thirst", Color(0.45, 0.75, 0.85), 100, "drop")

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
        quest_panel.offset_left = -316
        quest_panel.offset_right = -16
        quest_panel.offset_top = 16
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

        # --- v1.1 Phase V7: FIRST STEPS onboarding (bottom-right) ---
        var ob_panel := _panel(Vector2(0, 0), Vector2(238, 136))
        ob_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        ob_panel.offset_left = -248
        ob_panel.offset_top = -196
        ob_panel.offset_right = -10
        ob_panel.offset_bottom = -60
        onboarding_box = VBoxContainer.new()
        onboarding_box.set_anchors_preset(Control.PRESET_FULL_RECT)
        onboarding_box.offset_left = 8
        onboarding_box.offset_top = 6
        onboarding_box.offset_right = -8
        onboarding_box.offset_bottom = -6
        onboarding_box.add_theme_constant_override("separation", 2)
        var ob_head := HBoxContainer.new()
        ob_head.add_theme_constant_override("separation", 6)
        ob_head.add_child(GameIcons.make("star", Color(1.0, 0.85, 0.5), 14))
        var ob_title := Label.new()
        ob_title.text = "FIRST STEPS"
        ob_title.add_theme_font_size_override("font_size", 12)
        ob_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
        ob_head.add_child(ob_title)
        onboarding_box.add_child(ob_head)
        ob_panel.add_child(onboarding_box)
        onboarding_items = {
                "gather": Label.new(), "observe": Label.new(), "capture": Label.new(),
                "craft": Label.new(), "village": Label.new(),
        }
        var ob_icons := {
                "gather": "backpack", "observe": "eye", "capture": "paw",
                "craft": "gear", "village": "map",
        }
        var ob_texts := {
                "gather": "Gather wood or stone (LMB a node)",
                "observe": "Observe a wild Echo (aim at it)",
                "capture": "Capture your first Echo (F)",
                "craft": "Craft anything (C)",
                "village": "Visit Dawnstead village (east)",
        }
        for k in onboarding_items:
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 6)
                var ic := GameIcons.make(ob_icons[k], Color(0.75, 0.8, 0.88), 13)
                onboarding_icons[k] = ic
                row.add_child(ic)
                var l: Label = onboarding_items[k]
                l.text = ob_texts[k]
                l.add_theme_font_size_override("font_size", 11)
                l.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
                row.add_child(l)
                onboarding_box.add_child(row)

        # --- v1.1 Phase V7: compass strip (top-center, under the clock) ---
        compass = Control.new()
        compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
        compass.position = Vector2(-compass_width * 0.5, 96)
        compass.custom_minimum_size = Vector2(compass_width, 34)
        compass.draw.connect(func _draw(): _draw_compass())
        root.add_child(compass)
        root.add_child(crosshair)

        observe_ring = Control.new()
        observe_ring.set_anchors_preset(Control.PRESET_CENTER)
        observe_ring.custom_minimum_size = Vector2(48, 48)
        observe_ring.position = Vector2(-24, -24)
        observe_ring.draw.connect(_draw_observe_ring)
        root.add_child(observe_ring)

        _build_minimap()

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
        # PS-9: three diamond pips — one gutters each time the boss phases
        var pip_row := HBoxContainer.new()
        pip_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
        pip_row.position = Vector2(-32, 144)
        pip_row.add_theme_constant_override("separation", 10)
        root.add_child(pip_row)
        for i in 3:
                var pip := ColorRect.new()
                pip.custom_minimum_size = Vector2(13, 13)
                pip.pivot_offset = Vector2(6.5, 6.5)
                pip.rotation = PI / 4.0
                pip.color = BOSS_PIP_DIM
                pip_row.add_child(pip)
                boss_pips.append(pip)
        boss_bar.visible = false
        boss_label.visible = false
        pip_row.visible = false

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


func _bar_row(parent: Control, label: String, color: Color, max_val: float, icon := "") -> ProgressBar:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 6)
        parent.add_child(row)
        if icon != "":
                row.add_child(GameIcons.make(icon, color, 16))
        var l := Label.new()
        l.text = label
        l.custom_minimum_size = Vector2(56, 18)
        l.add_theme_font_size_override("font_size", 12)
        l.add_theme_color_override("font_color", color.lightened(0.25))
        row.add_child(l)
        var bar := ProgressBar.new()
        bar.custom_minimum_size = Vector2(142, 14)
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
        # PS-1: red edge flash on hp loss (heals flash soft green instead)
        if _last_hp_seen >= 0.0 and Game.hp < _last_hp_seen - 0.5:
                _dmg_vignette_a = 0.4
                if _dmg_vignette:
                        _dmg_vignette.color = Color(0.55, 0.04, 0.04, 0.4)
        elif _last_hp_seen >= 0.0 and Game.hp > _last_hp_seen + 2.0:
                _dmg_vignette_a = 0.22
                if _dmg_vignette:
                        _dmg_vignette.color = Color(0.25, 0.5, 0.3, 0.22)
        _last_hp_seen = Game.hp
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
                var name_row := HBoxContainer.new()
                name_row.add_theme_constant_override("separation", 6)
                vb.add_child(name_row)
                name_row.add_child(GameIcons.make("paw", Color(0.8, 0.95, 1.0), 14))
                var name_l := Label.new()
                name_l.text = "%s Lv%d" % [entry.get("name", "?"), int(entry.get("level", 1))]
                name_l.add_theme_font_size_override("font_size", 13)
                name_l.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
                name_row.add_child(name_l)
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


func _process(delta: float) -> void:
        _update_prompt()
        _update_boss(delta)
        _update_onboarding()
        # PS-1: damage vignette fade-out
        if _dmg_vignette_a > 0.001 and _dmg_vignette:
                _dmg_vignette_a = maxf(0.0, _dmg_vignette_a - delta * 1.6)
                _dmg_vignette.color.a = _dmg_vignette_a
        if compass:
                compass.queue_redraw()
        # PS-8: live minimap redraw + zone chip
        if minimap:
                minimap.queue_redraw()
                if minimap_zone:
                        var zname := "—"
                        if Game.current_zone_id != "":
                                zname = str(Data.zone(Game.current_zone_id).get("name", "—"))
                        if minimap_zone.text != zname:
                                minimap_zone.text = zname


func _update_onboarding() -> void:
        if onboarding_done:
                return
        var player := get_tree().get_first_node_in_group("player")
        if player == null:
                return
        var goals := {
                "gather": Game.count_item("Item_Wood") + Game.count_item("Item_Stone") >= 5,
                "observe": Game.journal.size() >= 1,
                "capture": Game.party.size() >= 1,
                "craft": Game.crafted_count > 0,
                "village": player.global_position.distance_to(Vector3(-120, player.global_position.y, 0)) < 40.0,
        }
        var labels := {
                "gather": "Gather wood or stone (LMB a node)",
                "observe": "Observe a wild Echo (aim at it)",
                "capture": "Capture your first Echo (F)",
                "craft": "Craft anything (C)",
                "village": "Visit Dawnstead village (east)",
        }
        var done_count := 0
        for k in goals:
                var l: Label = onboarding_items.get(k, null)
                if l == null:
                        continue
                var ic: Control = onboarding_icons.get(k, null)
                if goals[k]:
                        done_count += 1
                        l.text = labels[k]
                        l.add_theme_color_override("font_color", Color(0.55, 0.9, 0.65))
                        if ic:
                                GameIcons.set_icon(ic, "check", Color(0.55, 0.9, 0.65))
                else:
                        l.text = labels[k]
                        l.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
        if done_count == goals.size():
                onboarding_done = true
                if onboarding_box:
                        var tw := onboarding_box.create_tween()
                        tw.tween_interval(2.5)
                        tw.tween_property(onboarding_box, "modulate:a", 0.0, 1.2)
                Game.add_research_points(10)
                Game.toast.emit("THE VALE KNOWS YOU — expedition established (+10 RP)", Color(1.0, 0.85, 0.5))
                Sfx.play_event("ui_confirm")


func _draw_compass() -> void:
        ## Cardinal ticks + a golden diamond pointing at the active quest objective.
        var player := get_tree().get_first_node_in_group("player")
        if player == null:
                return
        var w: float = compass_width
        var h := 30.0
        # backdrop
        compass.draw_rect(Rect2(0, 0, w, h), Color(0.03, 0.04, 0.07, 0.45))
        var yaw: float = player.rotation.y
        var dirs := {"N": PI, "E": PI * 0.5, "S": 0.0, "W": PI * 1.5}
        for d in dirs:
                var rel: float = angle_difference(yaw, dirs[d])
                var x: float = w * 0.5 + rel / PI * w * 0.5
                if x < 8.0 or x > w - 8.0:
                        continue
                var major: bool = d == "N"
                compass.draw_string(_compass_font(), Vector2(x - 5, 20), d, HORIZONTAL_ALIGNMENT_LEFT, -1, 13 if major else 11,
                                Color(1.0, 0.95, 0.8, 0.95 if major else 0.65))
        # objective marker
        var obj_pos: Vector3 = _objective_world_pos()
        if obj_pos != Vector3.INF:
                var to_obj: Vector3 = obj_pos - player.global_position
                var bearing: float = atan2(to_obj.x, to_obj.z)
                var rel: float = angle_difference(yaw, bearing)
                var x: float = clampf(w * 0.5 + rel / PI * w * 0.5, 10.0, w - 10.0)
                var c := Vector2(x, 24)
                compass.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 1), c + Vector2(0, 8), c + Vector2(-5, 1)]),
                                Color(1.0, 0.82, 0.35, 0.95))
                compass.draw_string(_compass_font(), Vector2(w * 0.5 - 52, 12), "objective", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1.0, 0.82, 0.35, 0.5))


func _compass_font() -> Font:
        return ThemeDB.fallback_font


func _objective_world_pos() -> Vector3:
        ## Resolve the current quest objective to a world position for the compass.
        var q: Dictionary = Game.active_quest_data()
        if q.is_empty():
                return Vector3.INF
        var state: Dictionary = Game.quest_states.get(Game.active_quest, {})
        var objs: Array = q.get("objectives", [])
        var world := get_tree().get_first_node_in_group("world")
        for i in objs.size():
                var prog: int = state.get("objectives", [])[i] if not state.is_empty() else 0
                if prog >= int(objs[i]["count"]):
                        continue
                var t: String = String(objs[i].get("target", ""))
                var kind: String = String(objs[i].get("type", ""))
                match kind:
                        "ReachLocation":
                                for m in get_tree().get_nodes_in_group("interactables"):
                                        if m.get_meta("location_id", "") == t:
                                                return m.global_position
                        "VisitZone":
                                var zone: Dictionary = Data.zone(t)
                                if not zone.is_empty():
                                        var c: Array = zone.get("center", [0, 0])
                                        return Vector3(c[0], 0, c[1])
                        "ObserveEcho", "DefeatCreature", "CaptureEcho":
                                for c2 in get_tree().get_nodes_in_group("creatures"):
                                        if c2 is Echo and c2.def.get("id", "") == t and not c2.is_defeated():
                                                return c2.global_position
                        "CollectItem":
                                if world and world.get("nodes_root"):
                                        for n2 in world.nodes_root.get_children():
                                                if n2.get_meta("loot", "").find(t) >= 0 or t in str(n2.get_meta("loot", [])):
                                                        return n2.global_position
                break  # first incomplete objective only
        # fallback: guide toward Dawnstead (people = answers)
        return Vector3(-120, 0, 0)


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


func _update_boss(delta: float) -> void:
        var boss: Echo = null
        for c in get_tree().get_nodes_in_group("creatures"):
                if c is Echo and c.boss_mode and not c.is_defeated():
                        var player := get_tree().get_first_node_in_group("player")
                        if player and c.global_position.distance_to(player.global_position) < 60.0:
                                boss = c
                                break
        if boss:
                var pid := boss.get_instance_id()
                if pid != _boss_id:
                        # a new boss steps up — snap the bar, no slow-fill theatre
                        _boss_id = pid
                        _boss_shown_hp = boss.hp
                        _boss_phase_seen = boss._phase
                        _style_progress(boss_bar, BOSS_PHASE_COLORS[clampi(boss._phase, 1, 3) - 1])
                boss_bar.visible = true
                boss_label.visible = true
                boss_bar.max_value = boss.max_hp
                # PS-9: smooth drain — the bar bleeds down instead of snapping
                _boss_shown_hp = move_toward(_boss_shown_hp, boss.hp, delta * maxf(boss.max_hp * 0.5, 40.0))
                boss_bar.value = maxf(_boss_shown_hp, boss.hp)
                boss_label.text = "☠ %s — Phase %d" % [boss.def.get("name", "Boss"), boss._phase]
                if boss._phase != _boss_phase_seen:
                        _boss_phase_seen = boss._phase
                        _style_progress(boss_bar, BOSS_PHASE_COLORS[clampi(boss._phase, 1, 3) - 1])
                # pips: one per remaining phase (3 lit at phase 1 … 1 lit at phase 3)
                var lit: int = clampi(4 - boss._phase, 1, 3)
                for i in 3:
                        (boss_pips[i] as ColorRect).color = BOSS_PIP_LIT[i] if i < lit else BOSS_PIP_DIM
                if boss_pips.size() > 0 and boss_pips[0].get_parent() != null:
                        (boss_pips[0].get_parent() as Control).visible = true
        else:
                _boss_id = 0
                _boss_shown_hp = -1.0
                boss_bar.visible = false
                boss_label.visible = false
                if boss_pips.size() > 0 and boss_pips[0].get_parent() != null:
                        (boss_pips[0].get_parent() as Control).visible = false


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


# --------------------------------------------------------------- PS-8 map --
func _build_minimap() -> void:
        ## corner radar: north-locked circle, player arrow up, live blips,
        ## landmark diamonds, zone-name chip underneath.
        minimap = Control.new()
        minimap.custom_minimum_size = Vector2(MINIMAP_R * 2.0 + 8.0, MINIMAP_R * 2.0 + 8.0)
        minimap.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        minimap.position = Vector2(-MINIMAP_R * 2.0 - 26.0, -MINIMAP_R * 2.0 - 52.0)
        minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
        minimap.draw.connect(_draw_minimap)
        root.add_child(minimap)
        # zone chip rides directly under the radar — child of the minimap so
        # they can never drift apart regardless of anchor math
        minimap_zone = Label.new()
        minimap_zone.position = Vector2(0, MINIMAP_R * 2.0 + 10.0)
        minimap_zone.custom_minimum_size = Vector2(MINIMAP_R * 2.0 + 8.0, 20)
        minimap_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        minimap_zone.add_theme_font_size_override("font_size", 12)
        minimap_zone.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
        minimap_zone.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
        minimap_zone.add_theme_constant_override("shadow_offset_y", 1)
        minimap_zone.text = "—"
        minimap.add_child(minimap_zone)


func _draw_minimap() -> void:
        var player := get_tree().get_first_node_in_group("player") as Node3D
        var world := get_tree().get_first_node_in_group("world")
        if player == null or world == null:
                return
        var center := Vector2(MINIMAP_R + 4.0, MINIMAP_R + 4.0)
        # disc + rings
        minimap.draw_circle(center, MINIMAP_R + 3.0, Color(0.04, 0.05, 0.08, 0.82))
        minimap.draw_arc(center, MINIMAP_R + 3.0, 0.0, TAU, 40, Color(0.75, 0.7, 0.55, 0.55), 1.5)
        minimap.draw_arc(center, MINIMAP_R * 0.55, 0.0, TAU, 32, Color(0.6, 0.62, 0.6, 0.18), 1.0)
        # heading: rotate world offsets so the player's facing points UP
        var f3 := -player.global_transform.basis.z
        var phi := atan2(f3.z, f3.x)
        var rot := -PI / 2.0 - phi
        # north marker (true north = -Z)
        var north := Vector2(0.0, -1.0).rotated(rot) * (MINIMAP_R - 10.0)
        var font := minimap.get_theme_default_font()
        minimap.draw_string(font, center + north + Vector2(-4.0, 4.0), "N", HORIZONTAL_ALIGNMENT_LEFT, 10, 11, Color(0.85, 0.9, 1.0, 0.9))
        # landmark diamonds (chartable, gold)
        if world.has_method("landmark_list"):
                for lm in world.landmark_list():
                        var d := Vector2(float(lm["pos"].x) - player.global_position.x, float(lm["pos"].z) - player.global_position.z)
                        if d.length() > MINIMAP_RANGE * 2.0:
                                continue
                        var lp := center + d.rotated(rot).limit_length(MINIMAP_R - 4.0) * (MINIMAP_R / maxf(1.0, MINIMAP_RANGE)) * (1.0 if d.length() <= MINIMAP_RANGE else 1.0)
                        var dd: float = minf(1.0, d.length() / MINIMAP_RANGE)
                        var gold := Color(1.0, 0.84, 0.35, 0.35 + 0.6 * dd)
                        var dia := PackedVector2Array([lp + Vector2(0, -4), lp + Vector2(4, 0), lp + Vector2(0, 4), lp + Vector2(-4, 0)])
                        minimap.draw_colored_polygon(dia, gold)
        # creature blips: party gold · hostile red · passive soft green
        # (v1.5.1 fix: `is Echo` — damage-number Label3Ds also live in
        # creatures_root and used to crash this draw every combat frame)
        for c in world.creatures_root.get_children():
                if not (c is Echo) or c.get("defeated"):
                        continue
                var dxz := Vector2(c.global_position.x - player.global_position.x, c.global_position.z - player.global_position.z)
                if dxz.length() > MINIMAP_RANGE:
                        continue
                var bp := center + dxz.rotated(rot) * (MINIMAP_R / MINIMAP_RANGE)
                if c.get("captured"):
                        minimap.draw_circle(bp, 3.5, Color(1.0, 0.85, 0.35))
                elif c.def.get("hostile", false):
                        minimap.draw_circle(bp, 3.0, Color(1.0, 0.32, 0.28))
                else:
                        minimap.draw_circle(bp, 2.5, Color(0.55, 0.85, 0.6, 0.9))
        # player arrow (always up)
        var arrow := PackedVector2Array([center + Vector2(0, -7), center + Vector2(5, 6), center + Vector2(0, 3), center + Vector2(-5, 6)])
        minimap.draw_colored_polygon(arrow, Color(1.0, 0.95, 0.75))
