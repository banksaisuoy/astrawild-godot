class_name UtilityRobot
extends Node3D
## Utility Robot (U key) — walks to the nearest unmanned work site and
## mans it at a flat 0.8 rate (v1.0.4 field automation). Power-gated by
## the site itself (required-power sites stall without grid power).
## 600 s battery, recall refunds the item.

const BATTERY_MAX := 600.0
const WALK_SPEED := 3.2
const MAN_RATE := 0.8
const DOCK_DIST := 4.0

var battery := BATTERY_MAX
var _player: Node3D
var _site: Node3D = null
var _label: Label3D
var _body: Node3D


func setup(p_player: Node3D) -> void:
        _player = p_player


func _ready() -> void:
        add_to_group("robot")
        if _player:
                global_position = _player.global_position + Vector3(1.0, 0.0, 1.0)
        var world := get_tree().get_first_node_in_group("world")
        if world:
                global_position.y = world.tile_height(global_position.x, global_position.z) + 0.1

        # body: boxy little bot + eye light
        _body = Node3D.new()
        add_child(_body)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.62, 0.58, 0.52)
        mat.roughness = 0.6
        mat.metallic = 0.4
        _add_box(Vector3(0.9, 1.1, 0.7), Vector3(0, 0.55, 0), mat)
        _add_box(Vector3(0.5, 0.35, 0.5), Vector3(0, 1.3, 0), mat)
        var eye_mat := StandardMaterial3D.new()
        eye_mat.albedo_color = Color(1.0, 0.75, 0.3)
        eye_mat.emission_enabled = true
        eye_mat.emission = Color(1.0, 0.7, 0.25)
        eye_mat.emission_energy_multiplier = 2.0
        eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _add_box(Vector3(0.34, 0.12, 0.1), Vector3(0, 1.32, 0.36), eye_mat)
        _add_box(Vector3(0.22, 0.55, 0.22), Vector3(-0.62, 0.28, 0), mat)
        _add_box(Vector3(0.22, 0.55, 0.22), Vector3(0.62, 0.28, 0), mat)

        _label = Label3D.new()
        _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _label.no_depth_test = true
        _label.position = Vector3(0, 2.0, 0)
        _label.font_size = 34
        _label.outline_size = 7
        _label.modulate = Color(0.95, 0.9, 0.75)
        add_child(_label)
        _update_label()


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> void:
        var mi := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = size
        mi.mesh = box
        mi.material_override = mat
        mi.position = pos
        _body.add_child(mi)


func _process(delta: float) -> void:
        battery -= delta
        if battery <= 0.0:
                Game.toast.emit("Utility Robot battery depleted — recalled, robot refunded.", Color(1.0, 0.8, 0.55))
                _release_site()
                Game.add_item("Item_UtilityRobot", 1)
                queue_free()
                return
        if _site == null or not is_instance_valid(_site):
                _release_site()
                _site = _nearest_free_site()
        if _site:
                var d: float = global_position.distance_to(_site.global_position)
                if d > DOCK_DIST:
                        # walk toward the site, sticking to the ground
                        var dir := (_site.global_position - global_position)
                        dir.y = 0.0
                        dir = dir.normalized()
                        var world := get_tree().get_first_node_in_group("world")
                        var next := global_position + dir * WALK_SPEED * delta
                        if world:
                                next.y = world.tile_height(next.x, next.z) + 0.1
                        global_position = next
                        if _body:
                                _body.rotation.y = atan2(dir.x, dir.z)
                elif not get_meta("manning", false):
                        set_meta("manning", true)
                        _site.set("robot_rate", MAN_RATE)
                        _site.set("robot_node", self)
                        Game.toast.emit("Utility Robot is manning %s (×%s rate)." % [_site.get("display_name"), str(MAN_RATE)], Color(0.85, 1.0, 0.8))
        _update_label()


func _nearest_free_site() -> Node3D:
        var best: Node3D = null
        var best_d := INF
        for site in get_tree().get_nodes_in_group("worksites"):
                if not (site is Node3D) or site.is_queued_for_deletion():
                        continue
                if site.get("workers") != null and not site.workers.is_empty():
                        continue  # already manned by Echoes
                if site.get("robot_node") != null and is_instance_valid(site.robot_node):
                        continue  # another robot is here
                var d: float = global_position.distance_to(site.global_position)
                if d < best_d:
                        best_d = d
                        best = site
        return best


func _release_site() -> void:
        if _site and is_instance_valid(_site):
                _site.set("robot_rate", 0.0)
                _site.set("robot_node", null)
        set_meta("manning", false)
        _site = null


func recall() -> void:
        _release_site()
        Game.add_item("Item_UtilityRobot", 1)
        Game.toast.emit("Utility Robot recalled — item refunded.", Color(0.85, 1.0, 0.8))
        queue_free()


func _update_label() -> void:
        if _label:
                var status := "seeking a site..."
                if _site and is_instance_valid(_site):
                        status = "→ %s" % str(_site.get("display_name"))
                _label.text = "ROBOT %d%% · %s" % [int(ceilf(battery / BATTERY_MAX * 100.0)), status]
