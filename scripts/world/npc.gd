extends Node3D
## Living village NPC (UE5 AstrawildNPCCharacter + NPCAIController, Batch 8).
## Waypoint circuit patrol with idle pauses, day/night schedule (21:00-06:00 the
## villager walks to the campfire and stays), guards aggro hostile wild Echoes
## within 35 m and strike every 1.4 s for 14 damage, interaction pauses the AI 5 s
## and turns the NPC to face the player. Role-colored lantern point light.

const WALK_SPEED := 1.9            # 190 cm/s
const RUN_SPEED := 4.3             # 430 cm/s (guards)
const IDLE_MIN := 5.0
const IDLE_MAX := 9.0
const NIGHT_START := 21.0
const NIGHT_END := 6.0
const GUARD_AGGRO_RANGE := 35.0
const GUARD_BREAK_RANGE := 52.5    # 1.5x aggro
const GUARD_STRIKE_CD := 1.4
const GUARD_DAMAGE := 14.0
const INTERACT_PAUSE := 5.0

var def_color: Color = Color(0.5, 0.8, 0.6)
var display_name: String = "NPC"
var greeting: String = "..."
var role: String = "quest"
var village_id: String = ""
var home_pos := Vector3.ZERO
var waypoints: Array = []          # patrol circuit (Vector3)
var campfire_pos: Vector3 = Vector3(INF, 0, INF)
var _label: Label3D
var _anim: AnimationPlayer
var _lantern: OmniLight3D
var _wp_index := 0
var _idle_timer := 3.0
var _pause_timer := 0.0            # interaction pause
var _guard_target: Node3D = null
var _strike_cd := 0.0
var _think_timer := 0.0
var _walk_phase := 0.0


func _ready() -> void:
        display_name = str(get_meta("npc_name", "NPC"))
        def_color = get_meta("npc_color", Color(0.5, 0.8, 0.6))
        greeting = str(get_meta("npc_greeting", "..."))
        role = str(get_meta("npc_role", "quest"))
        village_id = str(get_meta("village_id", ""))
        waypoints = get_meta("waypoints", [])
        campfire_pos = get_meta("campfire_pos", Vector3(INF, 0, INF))
        home_pos = position
        if waypoints.is_empty():
                waypoints = [home_pos]
        add_to_group("interactables")
        set_meta("interact_kind", "npc")

        var scene: PackedScene = load("res://assets/meshes/characters/SK_Survivor_Exosuit.glb")
        if scene:
                var visual := scene.instantiate()
                add_child(visual)
                _tint(visual)
                _anim = _find_anim(visual)
                if _anim and _anim.has_animation("AM_Survivor_Idle"):
                        _anim.play("AM_Survivor_Idle")

        _label = Label3D.new()
        _label.text = display_name
        _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _label.no_depth_test = true
        _label.position = Vector3(0, 2.35, 0)
        _label.modulate = def_color
        _label.font_size = 48
        _label.outline_size = 10
        add_child(_label)

        # role-colored lantern (guards ember-warm, vendors gold, quest teal)
        _lantern = OmniLight3D.new()
        var lantern_col := Color(1.0, 0.8, 0.5)
        if role == "guard":
                lantern_col = Color(1.0, 0.55, 0.35)
        elif role == "vendor":
                lantern_col = Color(1.0, 0.85, 0.4)
        elif role == "quest":
                lantern_col = Color(0.45, 0.9, 0.8)
        _lantern.light_color = lantern_col
        _lantern.light_energy = 0.9
        _lantern.omni_range = 7.0
        _lantern.position = Vector3(0.4, 1.9, 0.25)
        add_child(_lantern)


func _tint(root: Node) -> void:
        for c in _all_meshes(root):
                var mat := StandardMaterial3D.new()
                mat.albedo_color = def_color.darkened(0.15)
                mat.roughness = 0.8
                c.material_override = mat


func _all_meshes(node: Node, acc: Array = []) -> Array:
        if node is MeshInstance3D:
                acc.append(node)
        for c in node.get_children():
                _all_meshes(c, acc)
        return acc


func _find_anim(node: Node) -> AnimationPlayer:
        for c in node.get_children():
                if c is AnimationPlayer:
                        return c
                var found: AnimationPlayer = _find_anim(c)
                if found:
                        return found
        return null


func _process(delta: float) -> void:
        _think_timer -= delta
        _strike_cd = maxf(0.0, _strike_cd - delta)
        if _pause_timer > 0.0:
                _pause_timer -= delta
                _face_player()
                return
        if role == "guard":
                _guard_logic(delta)
                if _guard_target:
                        return
        _schedule_logic(delta)


# ----------------------------------------------------------------- schedule --
func _schedule_logic(delta: float) -> void:
        var is_night := Game.hour() >= NIGHT_START or Game.hour() < NIGHT_END
        if is_night and campfire_pos.x != INF:
                var d := global_position.distance_to(campfire_pos)
                if d > 4.0:
                        _step_toward(campfire_pos + Vector3(randf() * 3.0 - 1.5, 0, randf() * 3.0 - 1.5), WALK_SPEED, delta)
                else:
                        _play_idle()
                return
        # day: waypoint circuit with idle pauses
        if _idle_timer > 0.0:
                _idle_timer -= delta
                _play_idle()
                return
        var target: Vector3 = waypoints[_wp_index]
        if global_position.distance_to(target) < 1.2:
                _wp_index = (_wp_index + 1) % waypoints.size()
                _idle_timer = randf_range(IDLE_MIN, IDLE_MAX)
                return
        _step_toward(target, WALK_SPEED, delta)


func _step_toward(target: Vector3, speed: float, delta: float) -> void:
        var dir := target - global_position
        dir.y = 0.0
        if dir.length() < 0.05:
                return
        dir = dir.normalized()
        global_position += dir * speed * delta
        var world := get_tree().get_first_node_in_group("world")
        if world and world.has_method("tile_height"):
                global_position.y = world.tile_height(global_position.x, global_position.z)
        _look_dir(dir)
        _walk_phase += delta * speed * 2.4
        if _anim:
                var run_name := "AM_Survivor_Run" if speed > WALK_SPEED + 0.5 else "AM_Survivor_Walk"
                if _anim.has_animation(run_name) and _anim.current_animation != run_name:
                        _anim.play(run_name)


func _play_idle() -> void:
        if _anim and _anim.current_animation != "AM_Survivor_Idle" and _anim.has_animation("AM_Survivor_Idle"):
                _anim.play("AM_Survivor_Idle")


func _look_dir(dir: Vector3) -> void:
        var yaw := atan2(dir.x, dir.z)
        rotation.y = lerpf(rotation.y, yaw, 0.25)


func _face_player() -> void:
        var player: Node3D = get_tree().get_first_node_in_group("player")
        if player == null:
                return
        var dir: Vector3 = player.global_position - global_position
        dir.y = 0.0
        if dir.length() > 0.1:
                rotation.y = atan2(dir.x, dir.z)


# --------------------------------------------------------------------- guard --
func _guard_logic(delta: float) -> void:
        if _think_timer > 0.0 and _guard_target == null:
                return
        _think_timer = 1.0
        # validate current target
        if _guard_target:
                if not is_instance_valid(_guard_target) or _guard_target.get("defeated") == true or _guard_target.get("captured") == true:
                        _guard_target = null
                elif global_position.distance_to(_guard_target.global_position) > GUARD_BREAK_RANGE:
                        _guard_target = null
        if _guard_target == null:
                _guard_target = _find_hostile()
        if _guard_target == null:
                return
        var dist := global_position.distance_to(_guard_target.global_position)
        if dist > 2.6:
                _step_toward(_guard_target.global_position, RUN_SPEED, delta)
        else:
                _look_dir(_guard_target.global_position - global_position)
                if _strike_cd <= 0.0:
                        _strike_cd = GUARD_STRIKE_CD
                        if _guard_target.has_method("take_hit"):
                                _guard_target.take_hit(GUARD_DAMAGE, "None")
                                var tdef = _guard_target.get("def")
                                if tdef != null:
                                        Game.toast.emit("%s strikes the %s!" % [display_name, str(tdef.get("name", "Echo"))], Color(1.0, 0.8, 0.6))


func _find_hostile() -> Node3D:
        var world := get_tree().get_first_node_in_group("world")
        if world == null:
                return null
        var best: Node3D = null
        var best_d := GUARD_AGGRO_RANGE
        var creatures: Node = world.get("creatures_root")
        if creatures == null:
                return null
        for c in creatures.get_children():
                if not (c is Node3D):
                        continue
                var cdef = c.get("def")
                if cdef == null:
                        continue
                if not cdef.get("hostile", false) or c.get("captured") or c.get("defeated"):
                        continue
                var d: float = global_position.distance_to(c.global_position)
                if d < best_d:
                        best_d = d
                        best = c
        return best


# -------------------------------------------------------------- interaction --
func interact() -> bool:
        _pause_timer = INTERACT_PAUSE
        _face_player()
        var screens := get_tree().get_first_node_in_group("screens")
        if screens:
                screens.open_dialogue(display_name, greeting, role)
        return true


func prompt() -> String:
        return "%s — [E] talk" % display_name
