class_name DawnSkiff
extends Node3D
## The Dawn Skiff — the Vale's first aircraft (UE5 AstrawildSkiffActor, Batch 8).
## Board with [E] near the hull, W/S thrust, A/D yaw, SPACE rise, CTRL descend,
## SHIFT resonance boost (14 -> 26 m/s). E while flying dismounts beside the hull.
## Banking + pitch tilt, terrain hover clamps (+2.2 m floor, +120 m ceiling).

const CRUISE_SPEED := 14.0
const BOOST_SPEED := 26.0
const VERTICAL_SPEED := 7.0
const TURN_RATE := 62.0            # deg/s
const MIN_HOVER := 2.2
const MAX_ALTITUDE := 120.0
const BOARD_RANGE := 6.0

var skiff_id := "Skiff_Dawnstead"
var display_name := "Dawn Skiff"
var pilot: Node3D = null           # the player while aboard
var _visual: Node3D = null
var _bow_light: OmniLight3D
var _hover_bob := 0.0
var _bank_roll := 0.0
var _pitch_tilt := 0.0
var _fwd_axis := 0.0
var _vert_axis := 0.0
var _turn_axis := 0.0
var _boosting := false
var _home_pos := Vector3.ZERO


func _ready() -> void:
        skiff_id = str(get_meta("skiff_id", "Skiff_Dawnstead"))
        display_name = str(get_meta("skiff_name", "Dawn Skiff"))
        _home_pos = position
        _build_visual()
        add_to_group("interactables")
        set_meta("interact_kind", "skiff")


func _build_visual() -> void:
        var scene: PackedScene = load("res://assets/meshes/vehicles/SM_Vehicle_DawnSkiff.glb")
        if scene:
                _visual = scene.instantiate()
                add_child(_visual)
        else:
                # fallback silhouette: hull + nose cone + tail fin + twin pontoons
                _visual = Node3D.new()
                add_child(_visual)
                _box(Vector3(3.2, 0.9, 1.6), Vector3(0, 1.1, 0), Color(0.72, 0.62, 0.42))
                _box(Vector3(1.2, 0.5, 1.1), Vector3(1.9, 1.25, 0), Color(0.8, 0.7, 0.5))
                _box(Vector3(0.18, 1.3, 1.0), Vector3(-1.5, 1.9, 0), Color(0.85, 0.72, 0.5))
                _box(Vector3(2.4, 0.4, 0.5), Vector3(0, 0.55, 1.05), Color(0.55, 0.46, 0.34))
                _box(Vector3(2.4, 0.4, 0.5), Vector3(0, 0.55, -1.05), Color(0.55, 0.46, 0.34))
        # resonance glow strip
        for mi in _all_meshes(_visual):
                var mat := StandardMaterial3D.new()
                mat.albedo_color = Color(0.78, 0.68, 0.5)
                mat.emission_enabled = true
                mat.emission = Color(0.9, 0.62, 0.25)
                mat.emission_energy_multiplier = 0.35
                mat.roughness = 0.55
                mi.material_override = mat
                break
        _bow_light = OmniLight3D.new()
        _bow_light.position = Vector3(2.4, 1.6, 0)
        _bow_light.omni_range = 22.0
        _bow_light.light_color = Color(1.0, 0.82, 0.55)
        _bow_light.light_energy = 1.8
        add_child(_bow_light)
        # landing gear hover shimmer when parked
        var pad := MeshInstance3D.new()
        var cyl := CylinderMesh.new()
        cyl.top_radius = 0.4
        cyl.bottom_radius = 2.6
        cyl.height = 0.06
        pad.mesh = cyl
        var pad_mat := StandardMaterial3D.new()
        pad_mat.albedo_color = Color(0.95, 0.75, 0.4)
        pad_mat.emission_enabled = true
        pad_mat.emission = Color(0.9, 0.6, 0.2)
        pad_mat.emission_energy_multiplier = 0.8
        pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        pad_mat.albedo_color.a = 0.35
        pad.mesh = cyl
        pad.material_override = pad_mat
        pad.position = Vector3(0, -0.55, 0)
        add_child(pad)


func _box(size: Vector3, pos: Vector3, color: Color) -> void:
        var mi := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = size
        mi.mesh = box
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mi.material_override = mat
        mi.position = pos
        _visual.add_child(mi)


func _all_meshes(node: Node, acc: Array = []) -> Array:
        if node is MeshInstance3D:
                acc.append(node)
        for c in node.get_children():
                _all_meshes(c, acc)
        return acc


# ------------------------------------------------------------- interaction --
func prompt() -> String:
        if pilot:
                return ""
        if _player_in_range():
                return "%s — [E] board" % display_name
        return ""


func _player_in_range() -> bool:
        var player := get_tree().get_first_node_in_group("player")
        return player != null and global_position.distance_to(player.global_position) <= BOARD_RANGE


func interact() -> bool:
        if pilot:
                return true
        var player := get_tree().get_first_node_in_group("player")
        if player == null:
                return false
        if global_position.distance_to(player.global_position) > BOARD_RANGE:
                return false
        board(player)
        return true


func board(player: Node3D) -> void:
        pilot = player
        player.set_meta("piloting", true)
        if player.has_method("set_piloting"):
                player.call("set_piloting", true)
        # attach the player to the hull so the third-person camera follows the flight
        var follow_point := Node3D.new()
        follow_point.name = "PilotFollow"
        add_child(follow_point)
        follow_point.position = Vector3(-0.6, 1.9, 0)
        player.reparent(follow_point)
        Game.toast.emit("Dawn Skiff boarded — WASD thrust · SPACE/CTRL altitude · SHIFT boost · [E] dismount", Color(1.0, 0.85, 0.55))


func dismount() -> void:
        if pilot == null:
                return
        var player := pilot
        pilot = null
        player.remove_meta("piloting") if player.has_meta("piloting") else null
        if player.has_method("set_piloting"):
                player.call("set_piloting", false)
        # place the player on the ground beside the hull
        var world := get_tree().get_first_node_in_group("world")
        var side := global_basis.x.normalized() * 3.2
        var drop := global_position + side
        if world and world.has_method("tile_height"):
                drop.y = world.tile_height(drop.x, drop.z) + 0.2
        player.reparent(get_tree().current_scene)
        player.global_position = drop
        Game.toast.emit("Dismounted. The skiff holds station here.", Color(0.85, 0.9, 1.0))


# ------------------------------------------------------------------- flight --
func _physics_process(delta: float) -> void:
        if pilot == null or not is_instance_valid(pilot):
                pilot = null
                return
        _read_input()
        # dynamic banking & pitch tilt (UE5 ComputeSkiffVelocity neighbours)
        var target_roll := -_turn_axis * 16.0
        var target_pitch := _fwd_axis * 4.5 + _vert_axis * 8.0
        _bank_roll = lerp_angle(_bank_roll, deg_to_rad(target_roll), clampf(delta * 4.0, 0.0, 1.0))
        _pitch_tilt = lerp_angle(_pitch_tilt, deg_to_rad(target_pitch), clampf(delta * 3.5, 0.0, 1.0))
        _hover_bob += delta
        var yaw := rotation.y
        if not is_zero_approx(_turn_axis):
                yaw += deg_to_rad(_turn_rate_value())
        rotation = Vector3(_pitch_tilt, yaw, _bank_roll)

        # velocity: forward/vertical with boost (1:1 port of ComputeSkiffVelocity)
        var fwd := -global_basis.z
        var speed := BOOST_SPEED if _boosting else CRUISE_SPEED
        var vel := fwd * (_fwd_axis * speed) + Vector3.UP * (_vert_axis * VERTICAL_SPEED)
        var delta_move := vel * delta

        # altitude clamps against terrain floor and flight ceiling
        var world := get_tree().get_first_node_in_group("world")
        if world and world.has_method("tile_height"):
                var ground_z: float = world.tile_height(global_position.x, global_position.z)
                var min_z := ground_z + MIN_HOVER
                var max_z := ground_z + MAX_ALTITUDE
                var cur_z: float = global_position.y
                if cur_z + delta_move.y < min_z:
                        delta_move.y = min_z - cur_z
                elif cur_z + delta_move.y > max_z:
                        delta_move.y = max_z - cur_z
        # hull sweep: stop horizontal motion into terrain/cliffs
        var dest := global_position + delta_move
        if world and world.has_method("tile_height"):
                var dest_ground: float = world.tile_height(dest.x, dest.z)
                if dest.y < dest_ground + MIN_HOVER:
                        delta_move = Vector3.ZERO
                        delta_move.y = maxf(delta_move.y, 0.0)
        global_position += delta_move
        # gentle hover bob while drifting
        if _visual:
                _visual.position.y = sin(_hover_bob * 1.7) * 0.12


func _turn_rate_value() -> float:
        return _turn_axis * TURN_RATE * get_physics_process_delta_time()


func _read_input() -> void:
        if _ui_open():
                _fwd_axis = 0.0
                _vert_axis = 0.0
                _turn_axis = 0.0
                _boosting = false
                return
        _fwd_axis = Input.get_axis("move_back", "move_forward")
        var rise := 0.0
        if Input.is_action_pressed("jump"):
                rise += 1.0
        if Input.is_key_pressed(KEY_CTRL):
                rise -= 1.0
        _vert_axis = rise
        _turn_axis = Input.get_axis("rotate_left", "rotate_right")
        _boosting = Input.is_action_pressed("sprint")


func _ui_open() -> bool:
        var screens := get_tree().get_first_node_in_group("screens")
        if screens and screens.has_method("is_open"):
                return screens.is_open()
        return false


func _unhandled_input(event: InputEvent) -> void:
        if pilot and event.is_action_pressed("interact"):
                dismount()
                get_viewport().set_input_as_handled()


# -------------------------------------------------------------------- save --
func get_save_data() -> Dictionary:
        return {"id": skiff_id, "x": global_position.x, "y": global_position.y, "z": global_position.z, "yaw": rotation.y}


func apply_save_data(data: Dictionary) -> void:
        global_position = Vector3(float(data.get("x", _home_pos.x)), float(data.get("y", _home_pos.y)), float(data.get("z", _home_pos.z)))
        rotation.y = float(data.get("yaw", 0.0))
