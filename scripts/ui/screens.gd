class_name UiScreens
extends CanvasLayer
## Full-screen game screens: inventory, crafting, research, journal, map,
## pause, dialogue, shop. One panel visible at a time; ESC closes.

const ERAS := ["Primitive", "Electrical", "Mechanical", "Eco", "AdvancedEnergy", "Ancient"]

var root: Control
var dim: ColorRect
var panels := {}
var current := ""
var _station_context := ""
var _dialogue_npc := ""


func _ready() -> void:
        layer = 20
        process_mode = Node.PROCESS_MODE_ALWAYS
        root = Control.new()
        root.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.visible = false
        add_child(root)
        dim = ColorRect.new()
        dim.color = Color(0.02, 0.03, 0.05, 0.68)
        dim.set_anchors_preset(Control.PRESET_FULL_RECT)
        root.add_child(dim)
        for key in ["inventory", "crafting", "research", "journal", "map", "pause", "dialogue", "shop", "mods"]:
                var p := Control.new()
                p.set_anchors_preset(Control.PRESET_FULL_RECT)
                p.visible = false
                root.add_child(p)
                panels[key] = p
        Game.screen_requested.connect(open)
        _build_inventory()
        _build_crafting()
        _build_research()
        _build_journal()
        _build_map()
        _build_pause()
        _build_dialogue()
        _build_shop()
        _build_mods()


func is_open() -> bool:
        return current != ""


func open(screen: String) -> void:
        if current == screen:
                close()
                return
        if screen == "dialogue" or screen == "shop":
                pass  # opened programmatically too
        current = screen
        root.visible = true
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        for k in panels:
                panels[k].visible = k == screen
        match screen:
                "inventory": _refresh_inventory()
                "crafting": _refresh_crafting()
                "research": _refresh_research()
                "journal": _refresh_journal()
                "map": _refresh_map()
                "mods": _refresh_mods()
                "pause":
                        get_tree().paused = true
                        _refresh_pause()
        if screen == "dialogue" or screen == "shop":
                current = screen


func close() -> void:
        current = ""
        root.visible = false
        get_tree().paused = false
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        _station_context = ""


func _input(event: InputEvent) -> void:
        if event.is_action_pressed("pause") and is_open():
                close()
                get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
        if what == NOTIFICATION_WM_CLOSE_REQUEST:
                pass


# ---------------------------------------------------------------- helpers --
func _panel_style() -> StyleBoxFlat:
        var s := StyleBoxFlat.new()
        s.bg_color = Color(0.07, 0.09, 0.13, 0.96)
        s.set_border_width_all(1)
        s.set_border_color(Color(0.3, 0.38, 0.5))
        s.set_corner_radius_all(8)
        s.content_margin_left = 14
        s.content_margin_right = 14
        s.content_margin_top = 12
        s.content_margin_bottom = 12
        return s


func _center_panel(key: String, size: Vector2) -> PanelContainer:
        var p := PanelContainer.new()
        p.add_theme_stylebox_override("panel", _panel_style())
        p.custom_minimum_size = size
        p.set_anchors_preset(Control.PRESET_CENTER)
        p.position = -size / 2.0
        panels[key].add_child(p)
        return p


func _title(parent: Control, text: String, subtitle: String = "") -> Label:
        var l := Label.new()
        l.text = text
        l.add_theme_font_size_override("font_size", 24)
        l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
        parent.add_child(l)
        if subtitle != "":
                var s := Label.new()
                s.text = subtitle
                s.add_theme_font_size_override("font_size", 12)
                s.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
                parent.add_child(s)
        return l


func _btn(text: String, cb: Callable, color: Color = Color(0.95, 0.85, 0.55)) -> Button:
        var b := Button.new()
        b.text = text
        b.add_theme_font_size_override("font_size", 14)
        b.add_theme_color_override("font_color", color)
        b.add_theme_color_override("font_hover_color", color.lightened(0.2))
        b.mouse_entered.connect(func _h(): Sfx.play("ui_hover", -16.0))
        b.pressed.connect(func _c(): Sfx.play("ui_click", -12.0))
        b.pressed.connect(cb)
        return b


func _tab_bar(parent: Control, tabs: Array, cb: Callable) -> TabBar:
        var tb := TabBar.new()
        for t in tabs:
                tb.add_tab(str(t))
        tb.select(0)
        tb.tab_changed.connect(cb)
        parent.add_child(tb)
        return tb


# -------------------------------------------------------------- inventory --
var _inv_grid: GridContainer
var _inv_detail: VBoxContainer
var _inv_weight: ProgressBar
var _inv_equip_box: HBoxContainer
var _inv_filter := "all"


func _build_inventory() -> void:
        var p := _center_panel("inventory", Vector2(880, 560))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 8)
        p.add_child(vb)
        _title(vb, "Inventory", "[Esc] close · click an item for actions")
        var filter_row := HBoxContainer.new()
        vb.add_child(filter_row)
        for f in [["all", "All"], ["material", "Materials"], ["consumable", "Consumables"], ["weapon", "Weapons"], ["armor", "Armor"], ["tool", "Tools"]]:
                var b := _btn(f[1], func _f(): _set_inv_filter(f[0]))
                b.add_theme_font_size_override("font_size", 12)
                filter_row.add_child(b)
        var columns := HBoxContainer.new()
        columns.add_theme_constant_override("separation", 16)
        columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
        vb.add_child(columns)
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(460, 380)
        scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        columns.add_child(scroll)
        _inv_grid = GridContainer.new()
        _inv_grid.columns = 4
        _inv_grid.add_theme_constant_override("h_separation", 6)
        _inv_grid.add_theme_constant_override("v_separation", 6)
        scroll.add_child(_inv_grid)
        var right := VBoxContainer.new()
        right.custom_minimum_size = Vector2(340, 380)
        right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        columns.add_child(right)
        _inv_detail = VBoxContainer.new()
        _inv_detail.add_theme_constant_override("separation", 6)
        right.add_child(_inv_detail)
        var equip_title := Label.new()
        equip_title.text = "Equipment"
        equip_title.add_theme_font_size_override("font_size", 15)
        right.add_child(equip_title)
        _inv_equip_box = HBoxContainer.new()
        _inv_equip_box.add_theme_constant_override("separation", 6)
        right.add_child(_inv_equip_box)
        var weight_label := Label.new()
        weight_label.text = "Carry weight"
        weight_label.add_theme_font_size_override("font_size", 12)
        right.add_child(weight_label)
        _inv_weight = ProgressBar.new()
        _inv_weight.custom_minimum_size = Vector2(320, 12)
        _inv_weight.show_percentage = false
        right.add_child(_inv_weight)


func _set_inv_filter(f: String) -> void:
        _inv_filter = f
        _refresh_inventory()


func _refresh_inventory() -> void:
        if _inv_grid == null:
                return
        for c in _inv_grid.get_children():
                c.queue_free()
        for c in _inv_detail.get_children():
                c.queue_free()
        var ids: Array = Game.inventory.keys()
        ids.sort_custom(func(x, y): return String(x) < String(y))
        var shown := 0
        for id in ids:
                var def := Data.item(id)
                if def.is_empty():
                        continue
                if _inv_filter != "all" and String(def.get("category", "")) != _inv_filter:
                        continue
                shown += 1
                var b := Button.new()
                b.custom_minimum_size = Vector2(108, 64)
                var qty: int = Game.inventory[id]
                b.text = "%s\n×%d" % [def.get("name", id), qty]
                b.add_theme_font_size_override("font_size", 12)
                var equipped: bool = id in Game.equipment.values()
                b.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55) if equipped else Color(0.88, 0.9, 0.95))
                var item_id: String = id
                b.pressed.connect(func _c(): _show_item_detail(item_id))
                _inv_grid.add_child(b)
        if shown == 0:
                var empty := Label.new()
                empty.text = "Nothing here yet — go gather!"
                empty.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
                _inv_grid.add_child(empty)
        # equipment summary
        for c in _inv_equip_box.get_children():
                c.queue_free()
        for slot in ["weapon", "offhand", "body", "head", "tool"]:
                var l := Label.new()
                var eq: String = Game.equipment[slot]
                var txt := "%s\n%s" % [slot.capitalize(), Data.item(eq).get("name", "—")]
                l.text = txt
                l.add_theme_font_size_override("font_size", 11)
                l.custom_minimum_size = Vector2(62, 40)
                l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                l.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0) if eq != "" else Color(0.5, 0.55, 0.6))
                _inv_equip_box.add_child(l)
        _inv_weight.max_value = Game.carry_limit()
        _inv_weight.value = Game.carry_weight()


func _show_item_detail(id: String) -> void:
        for c in _inv_detail.get_children():
                c.queue_free()
        var def := Data.item(id)
        if def.is_empty():
                return
        var name_l := Label.new()
        name_l.text = def.get("name", id)
        name_l.add_theme_font_size_override("font_size", 18)
        name_l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
        _inv_detail.add_child(name_l)
        var cat := Label.new()
        cat.text = "%s · %.1f kg · stack %d" % [def.get("category", "?"), def.get("weight", 0.0), def.get("stack", 1)]
        cat.add_theme_font_size_override("font_size", 11)
        cat.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
        _inv_detail.add_child(cat)
        var desc := Label.new()
        desc.text = def.get("desc", "")
        desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        desc.custom_minimum_size = Vector2(330, 48)
        desc.add_theme_font_size_override("font_size", 12)
        desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
        _inv_detail.add_child(desc)
        var stats := ""
        if def.has("atk"):
                stats += "Attack +%d" % int(def["atk"])
                if def.get("ranged", false):
                        stats += " · ranged · ammo: %s" % Data.item_name(def.get("ammo", ""))
        if def.has("armor"):
                stats += "Armor %d" % int(def["armor"])
        if def.has("block"):
                stats += "Block %d%%" % int(float(def["block"]) * 100)
        if def.has("element") and def["element"] != "None":
                stats += "\nElement: %s" % def["element"]
        if def.has("food"):
                stats += "\nFood +%d" % int(def["food"])
        if def.has("water"):
                stats += " · Water +%d" % int(def["water"])
        if def.has("heal"):
                stats += " · Heal +%d" % int(def["heal"])
        if stats != "":
                var sl := Label.new()
                sl.text = stats
                sl.add_theme_font_size_override("font_size", 12)
                sl.add_theme_color_override("font_color", Color(0.75, 0.9, 0.8))
                _inv_detail.add_child(sl)
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        _inv_detail.add_child(row)
        var item_id: String = id
        if def.get("category", "") == "consumable":
                row.add_child(_btn("Use", func _u(): Game.consume_item(item_id); _refresh_inventory()))
        if def.get("category", "") in ["weapon", "armor", "offhand", "tool"]:
                var slot: String = {"weapon": "weapon", "offhand": "offhand", "armor": "body", "tool": "tool"}.get(def.get("category", ""), "body")
                if def.has("slot"):
                        slot = def["slot"]
                var s := slot
                var equipped: bool = Game.equipment[s] == item_id
                row.add_child(_btn("Unequip" if equipped else "Equip", func _e(): Game.equip(s, item_id); _refresh_inventory()))
        row.add_child(_btn("Drop 1", func _d(): Game.remove_item(item_id, 1); _refresh_inventory(), Color(0.9, 0.6, 0.5)))


# --------------------------------------------------------------- crafting --
var _craft_list: VBoxContainer
var _craft_station_tab := "Field"
var _craft_queue_label: Label


func _build_crafting() -> void:
        var p := _center_panel("crafting", Vector2(760, 580))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 8)
        p.add_child(vb)
        _title(vb, "Crafting", "[Esc] close · craft anywhere for field recipes")
        _craft_list = VBoxContainer.new()
        _craft_list.add_theme_constant_override("separation", 4)
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(700, 430)
        vb.add_child(scroll)
        scroll.add_child(_craft_list)
        _craft_queue_label = Label.new()
        _craft_queue_label.add_theme_font_size_override("font_size", 13)
        _craft_queue_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
        vb.add_child(_craft_queue_label)


func open_crafting(station: String) -> void:
        _station_context = station
        match station:
                "Station_Workbench": _craft_station_tab = "Workbench"
                "Station_Campfire": _craft_station_tab = "Campfire"
                _: _craft_station_tab = "Field"
        open("crafting")


func _near_station(station: String) -> bool:
        if _station_context == station:
                return true
        var player := get_tree().get_first_node_in_group("player")
        var world := get_tree().get_first_node_in_group("world")
        if player == null or world == null:
                return false
        var target_station := station
        for root_name in ["npcs_root", "buildings_root"]:
                var root: Node = world.get(root_name)
                if root == null:
                        continue
                for c in root.get_children():
                        if c is Node3D and c.has_method("prompt"):
                                var pr: String = c.prompt()
                                if target_station == "Station_Workbench" and (pr.find("Workbench") >= 0 or pr.find("workbench") >= 0):
                                        if player.global_position.distance_to(c.global_position) < 5.0:
                                                return true
                                if target_station == "Station_Campfire" and (pr.find("Campfire") >= 0 or pr.find("cook") >= 0):
                                        if player.global_position.distance_to(c.global_position) < 5.0:
                                                return true
        return false


func _refresh_crafting() -> void:
        if _craft_list == null:
                return
        for c in _craft_list.get_children():
                c.queue_free()
        # station availability
        var avail := {"Field": true, "Workbench": _near_station("Station_Workbench"), "Campfire": _near_station("Station_Campfire")}
        for tab in ["Field", "Workbench", "Campfire"]:
                var head := Label.new()
                var suffix := "" if avail[tab] else "  (stand near a station)"
                head.text = "— %s%s —" % [tab, suffix]
                head.add_theme_font_size_override("font_size", 15)
                head.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95) if avail[tab] else Color(0.5, 0.55, 0.6))
                _craft_list.add_child(head)
                for r in Data.recipes:
                        # v1.0.4 fix: JSON null values (base recipes and mods ship
                        # "tech": null / "station": null) crashed the typed String
                        # conversion below — the recipe list NEVER rendered. Read
                        # null-safely instead.
                        var station_v: Variant = r.get("station", "")
                        var station: String = station_v if station_v is String else ""
                        if station == "":
                                station = "Field"
                        var tab_key: String = {"Station_Workbench": "Workbench", "Station_Campfire": "Campfire"}.get(station, "Field")
                        if tab_key != tab:
                                continue
                        var row := HBoxContainer.new()
                        row.add_theme_constant_override("separation", 10)
                        _craft_list.add_child(row)
                        var name_l := Label.new()
                        name_l.text = "%s" % r["name"]
                        name_l.custom_minimum_size = Vector2(180, 20)
                        name_l.add_theme_font_size_override("font_size", 13)
                        row.add_child(name_l)
                        var ing := Label.new()
                        ing.custom_minimum_size = Vector2(300, 20)
                        ing.add_theme_font_size_override("font_size", 12)
                        var parts := []
                        var can := true
                        for inp in r["inputs"]:
                                var have: int = Game.count_item(inp["item"])
                                var ok: bool = have >= inp["qty"]
                                if not ok:
                                        can = false
                                parts.append("%s×%d" % [Data.item_name(inp["item"]), inp["qty"]])
                        ing.text = "  ".join(parts)
                        ing.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7) if can else Color(0.85, 0.6, 0.55))
                        row.add_child(ing)
                        var tech_v: Variant = r.get("tech", "")
                        var tech: String = tech_v if tech_v is String else ""
                        var tech_ok: bool = tech == "" or Game.unlocked_tech.has(tech)
                        if not avail[tab] or not tech_ok:
                                var lock := Label.new()
                                lock.text = "🔒" if not tech_ok else "station"
                                lock.add_theme_font_size_override("font_size", 11)
                                lock.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
                                row.add_child(lock)
                        else:
                                var rid: String = r["id"]
                                var b := _btn("Craft (%ss)" % r["time"], func _c():
                                        if Game.start_craft(rid, Vector3.ZERO):
                                                Game.toast.emit("Crafting %s..." % rid, Color(0.8, 0.9, 1.0))
                                        _refresh_crafting())
                                b.add_theme_font_size_override("font_size", 12)
                                if not can:
                                        b.disabled = true
                                        b.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.55))
                                row.add_child(b)
                        var out_l := Label.new()
                        out_l.text = "→ %s×%d" % [Data.item_name(r["outputs"][0]["item"]), r["outputs"][0]["qty"]]
                        out_l.add_theme_font_size_override("font_size", 12)
                        out_l.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
                        row.add_child(out_l)
        if Game.craft_queue.is_empty():
                _craft_queue_label.text = "Queue: idle"
        else:
                var job: Dictionary = Game.craft_queue[0]
                var recipe_name := ""
                for r in Data.recipes:
                        if r["id"] == job["recipe_id"]:
                                recipe_name = r["name"]
                _craft_queue_label.text = "Crafting %s... %.1fs" % [recipe_name, job["remaining"]]


func _process(_delta: float) -> void:
        if current == "crafting" and not Game.craft_queue.is_empty():
                var job: Dictionary = Game.craft_queue[0]
                var recipe_name := ""
                for r in Data.recipes:
                        if r["id"] == job["recipe_id"]:
                                recipe_name = r["name"]
                _craft_queue_label.text = "Crafting %s... %.1fs" % [recipe_name, job["remaining"]]


# --------------------------------------------------------------- research --
var _research_list: VBoxContainer
var _research_points_label: Label


func _build_research() -> void:
        var p := _center_panel("research", Vector2(680, 580))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 8)
        p.add_child(vb)
        var t := _title(vb, "Research", "Observe Echoes, discover zones and finish quests to earn RP")
        _research_points_label = Label.new()
        _research_points_label.add_theme_font_size_override("font_size", 17)
        _research_points_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
        vb.add_child(_research_points_label)
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(640, 430)
        vb.add_child(scroll)
        _research_list = VBoxContainer.new()
        _research_list.add_theme_constant_override("separation", 4)
        scroll.add_child(_research_list)


func _refresh_research() -> void:
        if _research_list == null:
                return
        _research_points_label.text = "Research Points: %d" % Game.research_points
        for c in _research_list.get_children():
                c.queue_free()
        for era in ERAS:
                var any_in_era := false
                for tid in Data.techs:
                        if Data.techs[tid].get("era", "") == era:
                                any_in_era = true
                if not any_in_era:
                        continue
                var head := Label.new()
                head.text = "— %s Era —" % era
                head.add_theme_font_size_override("font_size", 15)
                head.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
                _research_list.add_child(head)
                for tid in Data.techs:
                        var t: Dictionary = Data.techs[tid]
                        if t.get("era", "") != era:
                                continue
                        var row := HBoxContainer.new()
                        row.add_theme_constant_override("separation", 10)
                        _research_list.add_child(row)
                        var name_l := Label.new()
                        name_l.text = t["name"]
                        name_l.custom_minimum_size = Vector2(200, 20)
                        name_l.add_theme_font_size_override("font_size", 13)
                        row.add_child(name_l)
                        var cost_l := Label.new()
                        cost_l.text = "%d RP" % int(t["cost"])
                        cost_l.custom_minimum_size = Vector2(70, 20)
                        cost_l.add_theme_font_size_override("font_size", 12)
                        cost_l.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
                        row.add_child(cost_l)
                        var status := ""
                        var unlocked: bool = Game.unlocked_tech.has(tid)
                        var prereq_ok := true
                        for pr in t.get("prereqs", []):
                                if not Game.unlocked_tech.has(pr):
                                        prereq_ok = false
                        if unlocked:
                                status = "✔ unlocked"
                        elif not prereq_ok:
                                status = "🔒 needs " + ", ".join(t.get("prereqs", []))
                        elif Game.research_points < int(t["cost"]):
                                status = "not enough RP"
                        if status != "":
                                var sl := Label.new()
                                sl.text = status
                                sl.add_theme_font_size_override("font_size", 12)
                                sl.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7) if unlocked else Color(0.65, 0.6, 0.6))
                                row.add_child(sl)
                        else:
                                var tid2: String = tid
                                var b := _btn("Unlock", func _u():
                                        Game.unlock_tech(tid2)
                                        _refresh_research())
                                b.add_theme_font_size_override("font_size", 12)
                                row.add_child(b)
                        var d := Label.new()
                        d.text = t.get("desc", "")
                        d.add_theme_font_size_override("font_size", 11)
                        d.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
                        d.custom_minimum_size = Vector2(240, 20)
                        d.clip_text = true
                        row.add_child(d)


# ---------------------------------------------------------------- journal --
var _journal_list: VBoxContainer
var _journal_tab := 0


func _build_journal() -> void:
        var p := _center_panel("journal", Vector2(860, 580))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 8)
        p.add_child(vb)
        _title(vb, "Field Journal — The Grand Menagerie", "Observe wild Echoes (aim at them) to fill the codex")
        var tabs := TabBar.new()
        var zone_names := []
        for z in Data.zones:
                zone_names.append(z["name"])
        for n in zone_names:
                tabs.add_tab(n)
        tabs.tab_changed.connect(func i(i: int): _journal_tab = i; _refresh_journal())
        vb.add_child(tabs)
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(820, 440)
        vb.add_child(scroll)
        _journal_list = VBoxContainer.new()
        _journal_list.add_theme_constant_override("separation", 4)
        scroll.add_child(_journal_list)


func _refresh_journal() -> void:
        if _journal_list == null:
                return
        for c in _journal_list.get_children():
                c.queue_free()
        if _journal_tab >= Data.zones.size():
                return
        var zone: Dictionary = Data.zones[_journal_tab]
        var zone_id: String = zone["id"]
        var head := Label.new()
        head.text = "%s — %s" % [zone["name"], zone.get("subtitle", "")]
        head.add_theme_font_size_override("font_size", 15)
        head.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
        _journal_list.add_child(head)
        var ids: Array = Data.species_by_zone.get(zone_id.replace("Zone_", ""), [])
        if ids.is_empty():
                ids = Data.species_by_zone.get(zone_id, [])
        var count := 0
        for sid in ids:
                var s: Dictionary = Data.species_def(sid)
                if s.is_empty():
                        continue
                count += 1
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 8)
                _journal_list.add_child(row)
                var prog: float = Game.observe_progress(sid)
                var name_l := Label.new()
                name_l.text = s["name"] if prog > 0.0 else "???"
                name_l.custom_minimum_size = Vector2(150, 20)
                name_l.add_theme_font_size_override("font_size", 13)
                name_l.add_theme_color_override("font_color", Data.element_color(s.get("element", "None")) if prog > 0.0 else Color(0.5, 0.5, 0.55))
                row.add_child(name_l)
                if prog <= 0.0:
                        var unknown := Label.new()
                        unknown.text = "not yet observed"
                        unknown.add_theme_font_size_override("font_size", 12)
                        unknown.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58))
                        row.add_child(unknown)
                        continue
                var fam := Label.new()
                fam.text = "%s · %s · %s" % [s.get("family", "?"), s.get("body_plan", "?"), s.get("size_class", "?")]
                fam.custom_minimum_size = Vector2(220, 20)
                fam.add_theme_font_size_override("font_size", 12)
                fam.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
                row.add_child(fam)
                var stats := ""
                if prog >= 25.0:
                        var st: Dictionary = s["stats"]
                        stats += "HP %d · ATK %d · DEF %d" % [st["hp"], st["atk"], st["def"]]
                if prog >= 50.0 and not s.get("foods", []).is_empty():
                        stats += " · food: %s" % Data.item_name(s["foods"][0])
                if prog >= 75.0:
                        stats += " · weak to %s" % s.get("weakness", "?")
                if prog >= 100.0:
                        stats += " · %s" % ("hostile ⚔" if s.get("hostile", false) else "docile")
                var sl := Label.new()
                sl.text = stats if stats != "" else "scanned…"
                sl.add_theme_font_size_override("font_size", 12)
                sl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.8))
                sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                sl.clip_text = true
                row.add_child(sl)
                var bar := ProgressBar.new()
                bar.custom_minimum_size = Vector2(80, 10)
                bar.min_value = 0
                bar.max_value = 100
                bar.value = prog
                bar.show_percentage = false
                row.add_child(bar)
        var footer := Label.new()
        footer.text = "%d species registered in this zone" % count
        footer.add_theme_font_size_override("font_size", 12)
        footer.add_theme_color_override("font_color", Color(0.55, 0.6, 0.68))
        _journal_list.add_child(footer)


# --------------------------------------------------------------------- map --
var _map_draw: Control


func _build_map() -> void:
        var p := _center_panel("map", Vector2(760, 640))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 8)
        p.add_child(vb)
        _title(vb, "The Shattered Vale — Grand Expanse", "[Esc] close · gold dot is you")
        _map_draw = Control.new()
        _map_draw.custom_minimum_size = Vector2(720, 480)
        _map_draw.draw.connect(_draw_map)
        vb.add_child(_map_draw)
        var legend := Label.new()
        legend.text = "Zone tint = biome · ★ landmarks discovered · campfire = home"
        legend.add_theme_font_size_override("font_size", 11)
        legend.add_theme_color_override("font_color", Color(0.6, 0.65, 0.72))
        vb.add_child(legend)


func _refresh_map() -> void:
        if _map_draw:
                _map_draw.queue_redraw()


func _map_rect(w: float, h: float) -> Rect2:
        # world 3200x2400 → panel
        var size := _map_draw.size
        var scale: float = minf(size.x / 3400.0, size.y / 2600.0)
        var off := (size - Vector2(3400.0, 2600.0) * scale) / 2.0
        return Rect2(off, Vector2(3400.0, 2600.0) * scale)


func _map_xy(x: float, z: float) -> Vector2:
        var size := _map_draw.size
        var scale: float = minf(size.x / 3400.0, size.y / 2600.0)
        var off := (size - Vector2(3400.0, 2600.0) * scale) / 2.0
        return off + (Vector2(x + 1700.0, z + 1300.0)) * scale


func _draw_map() -> void:
        var size := _map_draw.size
        _map_draw.draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.1), true)
        for z in Data.zones:
                var zid: String = z["id"]
                var known: bool = Game.discovered_zones.has(zid)
                var rect := Rect2(_map_xy(z["center"][0] - 400.0, z["center"][1] - 400.0), Vector2(800, 800) * (minf(size.x / 3400.0, size.y / 2600.0)))
                var col := Color(z["ground"][0], z["ground"][1], z["ground"][2])
                if not known:
                        col = Color(0.16, 0.18, 0.22)
                _map_draw.draw_rect(rect, col * Color(0.9, 0.95, 1.0), true)
                _map_draw.draw_rect(rect, Color(0.35, 0.4, 0.5), false, 1.5)
                var center := rect.position + rect.size / 2.0
                if known:
                        var font := _map_draw.get_theme_default_font()
                        _map_draw.draw_string(font, center + Vector2(-60, -8), z["name"], HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(1, 1, 1, 0.92))
                        _map_draw.draw_string(font, center + Vector2(-60, 10), "threat %d" % z["threat"], HORIZONTAL_ALIGNMENT_CENTER, 120, 10, Color(1, 1, 1, 0.6))
        # camp
        var camp := _map_xy(-400, 0)
        _map_draw.draw_circle(camp, 7, Color(1.0, 0.6, 0.25))
        # player
        var player := get_tree().get_first_node_in_group("player")
        if player:
                var pp := _map_xy(player.global_position.x, player.global_position.z)
                _map_draw.draw_circle(pp, 6, Color(1.0, 0.85, 0.3))
                _map_draw.draw_arc(pp, 9.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.3, 0.5), 2.0)


# ------------------------------------------------------------------- pause --
var _pause_box: VBoxContainer


func _build_pause() -> void:
        var p := _center_panel("pause", Vector2(420, 420))
        _pause_box = VBoxContainer.new()
        _pause_box.add_theme_constant_override("separation", 12)
        _pause_box.alignment = BoxContainer.ALIGNMENT_CENTER
        p.add_child(_pause_box)
        var t := _title(_pause_box, "ASTRAWILD", "Echoes of the First Dawn")


func _refresh_pause() -> void:
        for c in _pause_box.get_children():
                if c is Button:
                        c.queue_free()
        var world := get_tree().get_first_node_in_group("world")
        var player := get_tree().get_first_node_in_group("player")
        _pause_box.add_child(_btn("Resume", func _r(): close()))
        _pause_box.add_child(_btn("Save progress", func _s(): Saves.save_game(world, player)))
        if Saves.has_save():
                _pause_box.add_child(_btn("Load last save", func _l():
                        var data := Saves.load_game()
                        if not data.is_empty():
                                Game.toast.emit("Save loaded.", Color(0.7, 1.0, 0.85))
                                close()
                                if world and world.has_method("apply_save_data") and data.has("world"):
                                        world.apply_save_data(data["world"])
                                if player and data.has("player_pos"):
                                        player.global_position = Saves.player_pos(data) + Vector3(0, 0.5, 0)))
        _pause_box.add_child(_btn("Restart (new world)", func _n():
                Saves.delete_save()
                get_tree().paused = false
                get_tree().reload_current_scene()))
        _pause_box.add_child(_btn("Echo Mods [F7]", func _m(): open("mods")))
        _pause_box.add_child(_btn("Quit to desktop", func _q(): get_tree().quit(), Color(0.9, 0.6, 0.55)))


# -------------------------------------------------------------------- mods --
var _mods_list: VBoxContainer
var _mods_count_label: Label


func _build_mods() -> void:
        var p := _center_panel("mods", Vector2(680, 560))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 10)
        p.add_child(vb)
        _title(vb, "ECHO MODS", "[F7] / [Esc] close · runtime mod manager")
        _mods_count_label = Label.new()
        _mods_count_label.add_theme_font_size_override("font_size", 13)
        _mods_count_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
        vb.add_child(_mods_count_label)
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(640, 400)
        scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        vb.add_child(scroll)
        _mods_list = VBoxContainer.new()
        _mods_list.add_theme_constant_override("separation", 8)
        _mods_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        scroll.add_child(_mods_list)
        var hint := Label.new()
        hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hint.custom_minimum_size = Vector2(640, 0)
        hint.add_theme_font_size_override("font_size", 11)
        hint.add_theme_color_override("font_color", Color(0.55, 0.62, 0.72))
        hint.text = "เพิ่ม mods: สร้างโฟลเดอร์ mods/<ชื่อmod>/ ข้างไฟล์เกม (หรือ user://mods) ใส่ไฟล์ mod.json — species / items / recipes จะถูกโหลดอัตโนมัติตอนเริ่มเกม ดูรูปแบบที่ docs/MODS.md ใน repository"
        vb.add_child(hint)
        var close_row := HBoxContainer.new()
        close_row.alignment = BoxContainer.ALIGNMENT_CENTER
        vb.add_child(close_row)
        close_row.add_child(_btn("ปิด · Close", func _c(): close()))


func _refresh_mods() -> void:
        if _mods_list == null:
                return
        for c in _mods_list.get_children():
                c.queue_free()
        var ids: Array = Mods.mods.keys()
        if ids.is_empty():
                var empty := Label.new()
                empty.text = "ยังไม่มี mods ที่โหลด — ใส่ mod แรกของคุณผ่านโฟลเดอร์ mods/ (ด้านล่าง)"
                empty.add_theme_font_size_override("font_size", 14)
                empty.add_theme_color_override("font_color", Color(0.75, 0.7, 0.55))
                _mods_list.add_child(empty)
        else:
                _mods_count_label.text = "%d mod(s) ที่ใช้งานอยู่ · รายละเอียดต่อ mod ด้านล่าง" % ids.size()
        for id in ids:
                var m: Dictionary = Mods.mods[id]
                var card := PanelContainer.new()
                var style := _panel_style()
                style.border_color = Color(0.55, 0.45, 0.25)
                card.add_theme_stylebox_override("panel", style)
                _mods_list.add_child(card)
                var vb := VBoxContainer.new()
                vb.add_theme_constant_override("separation", 4)
                card.add_child(vb)
                var head := HBoxContainer.new()
                vb.add_child(head)
                var name_l := Label.new()
                name_l.text = "%s  v%s" % [m.get("name", id), m.get("version", "?")]
                name_l.add_theme_font_size_override("font_size", 16)
                name_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
                name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                head.add_child(name_l)
                var source_map := {
                        "bundled": ["BUNDLED", Color(0.62, 0.85, 0.66)],
                        "portable": ["PORTABLE", Color(0.55, 0.8, 0.95)],
                        "user": ["USER", Color(0.9, 0.75, 0.5)],
                }
                var src: Array = source_map.get(m.get("source", "bundled"), ["?", Color.WHITE])
                var src_l := Label.new()
                src_l.text = "[ %s ]" % src[0]
                src_l.add_theme_font_size_override("font_size", 11)
                src_l.add_theme_color_override("font_color", src[1])
                head.add_child(src_l)
                var meta := Label.new()
                var c2: Dictionary = m.get("counts", {})
                meta.text = "by %s · %d species · %d items · %d recipes" % [m.get("author", "?"), c2.get("species", 0), c2.get("items", 0), c2.get("recipes", 0)]
                meta.add_theme_font_size_override("font_size", 12)
                meta.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
                vb.add_child(meta)
                var desc := Label.new()
                desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                desc.custom_minimum_size = Vector2(600, 0)
                desc.text = str(m.get("description", ""))
                desc.add_theme_font_size_override("font_size", 12)
                desc.add_theme_color_override("font_color", Color(0.78, 0.8, 0.85))
                vb.add_child(desc)
        if ids.is_empty():
                _mods_count_label.text = "0 mods โหลดอยู่"


# ---------------------------------------------------------------- dialogue --
var _dlg_name: Label
var _dlg_text: Label
var _dlg_buttons: HBoxContainer


func _build_dialogue() -> void:
        var p := _center_panel("dialogue", Vector2(560, 240))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 10)
        p.add_child(vb)
        _dlg_name = Label.new()
        _dlg_name.add_theme_font_size_override("font_size", 19)
        _dlg_name.add_theme_color_override("font_color", Color(1.0, 0.9, 0.65))
        vb.add_child(_dlg_name)
        _dlg_text = Label.new()
        _dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        _dlg_text.custom_minimum_size = Vector2(500, 80)
        _dlg_text.add_theme_font_size_override("font_size", 14)
        vb.add_child(_dlg_text)
        _dlg_buttons = HBoxContainer.new()
        _dlg_buttons.add_theme_constant_override("separation", 10)
        vb.add_child(_dlg_buttons)


func open_dialogue(npc_name: String, text: String, role: String) -> void:
        _dialogue_npc = npc_name
        _dlg_name.text = npc_name
        _dlg_text.text = text
        for c in _dlg_buttons.get_children():
                c.queue_free()
        _dlg_buttons.add_child(_btn("Farewell", func _f(): close()))
        if role == "vendor":
                _dlg_buttons.add_child(_btn("Trade", func _t(): open("shop"), Color(0.8, 0.95, 1.0)))
        if role == "quest":
                _dlg_buttons.add_child(_btn("What should I do?", func _q():
                        var q: Dictionary = Game.active_quest_data()
                        if q.is_empty():
                                _dlg_text.text = "The vale needs nothing of you today. Rest, wanderer."
                        else:
                                _dlg_text.text = "%s — %s" % [q.get("title", ""), q.get("summary", "")]
                , Color(0.85, 0.9, 1.0)))
        if role == "herbalist":
                _dlg_buttons.add_child(_btn("Advice", func _a():
                        var tips := [
                                "Weaken an Echo before using a resonator — a hurt beast invites, a healthy one resists.",
                                "Feed wild Echoes their favorite food. Trust doubles the capture odds.",
                                "Aim at creatures to fill your journal. Full scans add capture chance.",
                                "Frost chills, ember burns — exploit elemental weaknesses for half again damage.",
                                "Gloomfangs prowl at night. Sleep, or fight with light.",
                        ]
                        _dlg_text.text = tips[randi() % tips.size()]
                , Color(0.8, 0.95, 0.8)))
        open("dialogue")


# -------------------------------------------------------------------- shop --
var _shop_list: VBoxContainer
const SHOP_STOCK := [
        {"item": "Item_Resonator", "price": 3},
        {"item": "Item_Bandage", "price": 2},
        {"item": "Item_WaterFlask", "price": 2},
        {"item": "Item_FeedMix", "price": 2},
        {"item": "Item_Berry", "price": 1},
        {"item": "Item_EnergyCell", "price": 4},
]


func _build_shop() -> void:
        var p := _center_panel("shop", Vector2(640, 520))
        var vb := VBoxContainer.new()
        vb.add_theme_constant_override("separation", 8)
        p.add_child(vb)
        _title(vb, "Trader Tam's Wares", "Dawn Shards trade for everything")
        var scroll := ScrollContainer.new()
        scroll.custom_minimum_size = Vector2(600, 380)
        vb.add_child(scroll)
        _shop_list = VBoxContainer.new()
        _shop_list.add_theme_constant_override("separation", 4)
        scroll.add_child(_shop_list)


func open_shop() -> void:
        _refresh_shop()
        open("shop")


func _refresh_shop() -> void:
        if _shop_list == null:
                return
        for c in _shop_list.get_children():
                c.queue_free()
        var wallet := Label.new()
        wallet.text = "You carry %d Dawn Shards" % Game.count_item("Item_DawnShard")
        wallet.add_theme_font_size_override("font_size", 14)
        wallet.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
        _shop_list.add_child(wallet)
        var head := Label.new()
        head.text = "— Buy —"
        head.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
        _shop_list.add_child(head)
        for stock in SHOP_STOCK:
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 10)
                _shop_list.add_child(row)
                var l := Label.new()
                l.text = Data.item_name(stock["item"])
                l.custom_minimum_size = Vector2(180, 20)
                row.add_child(l)
                var p_l := Label.new()
                p_l.text = "%d shards" % stock["price"]
                p_l.custom_minimum_size = Vector2(80, 20)
                p_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
                row.add_child(p_l)
                var item_id: String = stock["item"]
                var price: int = stock["price"]
                var b := _btn("Buy", func _buy():
                        if Game.count_item("Item_DawnShard") >= price:
                                Game.remove_item("Item_DawnShard", price)
                                Game.add_item(item_id, 1)
                                _refresh_shop()
                        else:
                                Game.toast.emit("Not enough shards.", Color(1, 0.7, 0.5)))
                b.add_theme_font_size_override("font_size", 12)
                row.add_child(b)
        var sell_head := Label.new()
        sell_head.text = "— Sell (half price) —"
        sell_head.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
        _shop_list.add_child(sell_head)
        for id in Game.inventory.keys():
                if id == "Item_DawnShard":
                        continue
                var value: int = maxi(1, int(Data.item(id).get("weight", 1.0) * 8.0))
                var row := HBoxContainer.new()
                row.add_theme_constant_override("separation", 10)
                _shop_list.add_child(row)
                var l := Label.new()
                l.text = "%s ×%d" % [Data.item_name(id), Game.inventory[id]]
                l.custom_minimum_size = Vector2(180, 20)
                row.add_child(l)
                var p_l := Label.new()
                p_l.text = "%d shards" % value
                p_l.custom_minimum_size = Vector2(80, 20)
                p_l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
                row.add_child(p_l)
                var item_id: String = id
                var val: int = value
                var b := _btn("Sell 1", func _sell():
                        if Game.remove_item(item_id, 1):
                                Game.add_item("Item_DawnShard", val)
                                _refresh_shop())
                b.add_theme_font_size_override("font_size", 12)
                row.add_child(b)
