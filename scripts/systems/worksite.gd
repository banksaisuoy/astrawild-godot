class_name WorkSite
extends StaticBody3D
## Echo work site (UE5 AstrawildWorkSiteActor, Creature doc §8).
## Affinity × personality × mood × energy-scaled production; powered sites run
## at 1.5x, unpowered required sites stall at 0x. Consume→produce: definition
## driven sites burn inputs per cycle (Camp Kitchen: raw meat -> seared meat).
## Interact to (re)assign nearby party Echoes and collect stored output.

const ASSIGN_RADIUS := 20.0

var site_id := "Site_CampGathering"
var display_name := "Camp Gathering Post"
var work_type := "Gathering"
var output_item := "Item_Fiber"
var output_quantity := 1
var seconds_per_output := 10.0
var requires_power := false
var input_items := {}               # item_id -> qty per cycle
var workers := []                   # bound party entries (dicts)
var worker_nodes := []              # Echo follower nodes
var stored_output := 0
var work_accumulator := 0.0
var powered := false                # grid-supplied state (required-power sites)
var _label: Label3D
var _progress: MeshInstance3D


func setup(p_def: Dictionary) -> void:
        site_id = str(p_def.get("id", site_id))
        display_name = str(p_def.get("name", display_name))
        work_type = str(p_def.get("work_type", work_type))
        output_item = str(p_def.get("output", output_item))
        output_quantity = int(p_def.get("output_qty", 1))
        seconds_per_output = float(p_def.get("seconds", seconds_per_output))
        requires_power = bool(p_def.get("requires_power", false))
        input_items = p_def.get("inputs", {})
        def = p_def


var def: Dictionary = {}


func _ready() -> void:
        add_to_group("interactables")
        set_meta("interact_kind", "worksite")
        collision_layer = 4
        collision_mask = 0
        # required-power sites join the shared grid as consumers
        if requires_power:
                def["power_role"] = "Consumer"
                def["power_draw"] = 2.0
                var world := get_tree().get_first_node_in_group("world")
                if world:
                        var grid = world.get("power_grid")
                        if grid and grid.has_method("register_building"):
                                grid.register_building(self)

        # visual: work bench silhouette + element-tinted resonance ring
        var bench_mat := StandardMaterial3D.new()
        bench_mat.albedo_color = Color(0.5, 0.42, 0.32)
        bench_mat.roughness = 0.9
        _add_box(Vector3(2.0, 0.9, 1.2), Vector3(0, 0.45, 0), bench_mat)
        _add_box(Vector3(0.2, 0.9, 0.2), Vector3(-0.8, 0.45, -0.45), bench_mat)
        _add_box(Vector3(0.2, 0.9, 0.2), Vector3(0.8, 0.45, -0.45), bench_mat)
        _add_box(Vector3(0.2, 0.9, 0.2), Vector3(-0.8, 0.45, 0.45), bench_mat)
        _add_box(Vector3(0.2, 0.9, 0.2), Vector3(0.8, 0.45, 0.45), bench_mat)
        var glow := StandardMaterial3D.new()
        var col := Color(0.4, 0.9, 0.7) if not requires_power else Color(1.0, 0.7, 0.3)
        glow.albedo_color = col
        glow.emission_enabled = true
        glow.emission = col
        glow.emission_energy_multiplier = 1.6
        _progress = _add_box(Vector3(1.6, 0.08, 0.5), Vector3(0, 0.95, 0), glow)

        _label = Label3D.new()
        _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _label.no_depth_test = true
        _label.position = Vector3(0, 2.0, 0)
        _label.font_size = 40
        _label.outline_size = 8
        _label.modulate = Color(0.85, 0.95, 0.9)
        add_child(_label)
        _update_label()

        var col_shape := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(2.2, 1.0, 1.4)
        shape.size.y = 1.0
        col_shape.shape = shape
        col_shape.position = Vector3(0, 0.5, 0)
        add_child(col_shape)


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = size
        mi.mesh = box
        mi.material_override = mat
        mi.position = pos
        add_child(mi)
        return mi


func _update_label() -> void:
        var workers_txt := "%d Echo%s" % [workers.size(), "s" if workers.size() != 1 else ""]
        var stored_txt := "%d %s ready" % [stored_output, Data.item_name(output_item)]
        var power_txt := ""
        if requires_power:
                power_txt = " · ⚡ POWERED ×1.5" if powered else " · ⚠ NO POWER (build a Dynamo within 12 m)"
        _label.text = "%s\n%s · %s%s" % [display_name, workers_txt, stored_txt, power_txt]


func _process(delta: float) -> void:
        _drop_stale_workers()
        if workers.is_empty():
                return
        var powered := _power_multiplier()
        if powered <= 0.0:
                return
        var rate := _total_worker_rate()
        work_accumulator += delta * rate * powered
        while work_accumulator >= seconds_per_output:
                if not _consume_cycle_inputs():
                        work_accumulator = seconds_per_output
                        break
                work_accumulator -= seconds_per_output
                stored_output += maxi(1, output_quantity)
                _update_label()
        # progress bar visual
        if _progress:
                _progress.scale.x = clampf(work_accumulator / seconds_per_output, 0.08, 1.0)


func _drop_stale_workers() -> void:
        var world := get_tree().get_first_node_in_group("world")
        if world == null:
                return
        for i in range(worker_nodes.size() - 1, -1, -1):
                var n = worker_nodes[i]
                if not is_instance_valid(n) or global_position.distance_to(n.global_position) > ASSIGN_RADIUS * 1.5:
                        worker_nodes.remove_at(i)
                        if workers.size() > i:
                                workers.remove_at(i)
                        _update_label()


func _power_multiplier() -> float:
        if not requires_power:
                return 1.0
        return 1.5 if powered else 0.0


## Power grid callback — UE5 per-actor bIsPowered replication equivalent.
func set_powered(state: bool) -> void:
        powered = state
        _update_label()


## Affinity (species work list) × mood × energy scaled production rate.
func _worker_rate(entry: Dictionary) -> float:
        var s: Dictionary = Data.species_def(entry.get("species_id", ""))
        if s.is_empty():
                return 0.0
        var affinity := 0.5
        if work_type in s.get("work", []):
                affinity = float(s.get("work_affinity", 1.0))
        var mood := float(entry.get("mood", 70.0)) / 100.0
        var energy := float(entry.get("energy", 80.0)) / 100.0
        var personality := 1.0
        match str(s.get("personality", "Curious")):
                "Industrious": personality = 1.25
                "Playful": personality = 0.9
                "Stoic": personality = 1.1
                "Skittish": personality = 0.85
        return affinity * (0.5 + mood * 0.5) * (0.5 + energy * 0.5) * personality


func _total_worker_rate() -> float:
        var total := 0.0
        for w in workers:
                total += _worker_rate(w)
        return maxf(total, 0.05)


func _consume_cycle_inputs() -> bool:
        if input_items.is_empty():
                return true  # harvest-from-the-land site: no inputs needed
        for item_id in input_items:
                if Game.count_item(item_id) < int(input_items[item_id]):
                        Game.toast.emit("%s stalled — needs %s" % [display_name, Data.item_name(item_id)], Color(1.0, 0.7, 0.5))
                        return false
        for item_id in input_items:
                Game.remove_item(item_id, int(input_items[item_id]))
        return true


# -------------------------------------------------------------- interaction --
func prompt() -> String:
        var stored := " · %d %s ready" % [stored_output, Data.item_name(output_item)]
        var assign := "assign party" if workers.is_empty() else "reassign"
        if stored_output > 0:
                return "%s — [E] collect%s / %s" % [display_name, stored, assign]
        return "%s — [E] %s" % [display_name, assign]


func interact() -> bool:
        _collect_output()
        _reassign_workers()
        return true


func _collect_output() -> void:
        if stored_output <= 0:
                return
        Game.add_item(output_item, stored_output)
        Game.toast.emit("+%d %s from the %s" % [stored_output, Data.item_name(output_item), display_name], Color(0.75, 1.0, 0.8))
        stored_output = 0
        _update_label()


func _reassign_workers() -> void:
        workers = []
        worker_nodes = []
        var world := get_tree().get_first_node_in_group("world")
        if world == null:
                return
        # nearby captured party followers within the assign radius
        var followers: Dictionary = world.get("followers")
        for idx in followers:
                var n: Node = followers[idx]
                if n == null or not is_instance_valid(n):
                        continue
                if global_position.distance_to(n.global_position) <= ASSIGN_RADIUS:
                        worker_nodes.append(n)
                        workers.append(Game.party[idx])
        if workers.is_empty():
                Game.toast.emit("%s: no party Echoes within %d m — bring your companions close." % [display_name, int(ASSIGN_RADIUS)], Color(1.0, 0.8, 0.6))
        else:
                var names := []
                for w in workers:
                        names.append(str(w.get("name", "Echo")))
                Game.toast.emit("%s assigned: %s" % [display_name, ", ".join(names)], Color(0.8, 1.0, 0.85))
        _update_label()


# --------------------------------------------------------------------- save --
func get_save_data() -> Dictionary:
        return {"id": site_id, "stored": stored_output, "acc": work_accumulator}


func apply_save_data(data: Dictionary) -> void:
        stored_output = int(data.get("stored", 0))
        work_accumulator = float(data.get("acc", 0.0))
        _update_label()
