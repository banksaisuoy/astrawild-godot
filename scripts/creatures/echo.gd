class_name Echo
extends Node3D
## Wild / captured Echo creature. Data-driven: builds a procedural body from
## the species body plan + tints, or uses the production GLB model when present.
## AI: simplified UE5 state machine (Idle/Explore/Sleep/Investigate/Flee/Combat/
## Follow/Stay/Defeated) with personality, activity windows and perception.

const THINK_INTERVAL := 0.25
const ATTACK_RANGE := 1.8
const ATTACK_COOLDOWN := 1.6

var def: Dictionary = {}
var rng := RandomNumberGenerator.new()
var hp: float = 100.0
var max_hp: float = 100.0
var trust: float = 0.0
var captured := false
var defeated := false
var boss_mode := false
var entry: Dictionary = {}          # bound party entry (captured)
var ai_state := "Idle"
var home_pos := Vector3.ZERO
var wander_target := Vector3.ZERO
var think_timer := 0.0
var attack_timer := 0.0
var move_speed := 3.0
var velocity := Vector3.ZERO
var tracked := false
var _player: Node3D = null
var _world: Node3D = null
var _body_root: Node3D
var _parts := {}                    # name -> Node3D for procedural animation
var _anim: AnimationPlayer = null
var _label: Label3D
var _walk_phase := 0.0
var _hit_flash := 0.0
var _death_timer := 0.0
var _stagger_timer := 0.0
var _personalities := {
	"Brave": {"flee": 0.4, "aggro": 1.2}, "Timid": {"flee": 1.8, "aggro": 0.5},
	"Aggressive": {"flee": 0.5, "aggro": 1.5}, "Curious": {"flee": 1.0, "aggro": 1.0},
	"Loyal": {"flee": 1.0, "aggro": 1.0}, "Lazy": {"flee": 1.0, "aggro": 1.0},
	"Energetic": {"flee": 1.0, "aggro": 1.0}, "Protective": {"flee": 0.6, "aggro": 1.0},
	"Independent": {"flee": 1.0, "aggro": 1.0}, "Social": {"flee": 1.0, "aggro": 1.0},
}
var _personality := "Curious"
# boss extras
var _telegraph_mesh: MeshInstance3D
var _telegraph_timer := 0.0
var _special_timer := 7.0
var _weak_timer := 12.0
var _weak_orb: MeshInstance3D
var _phase := 1


func _init(p_def: Dictionary, p_rng: RandomNumberGenerator) -> void:
	def = p_def
	rng = p_rng
	rng.seed = hash("%s-%d" % [def.get("id", "?"), Time.get_ticks_msec()])


func _ready() -> void:
	max_hp = float(def["stats"]["hp"])
	hp = max_hp
	move_speed = float(def["stats"]["spd"]) / 100.0
	if boss_mode:
		max_hp = max_hp
		hp = max_hp
	_personality = def.get("personality", "Curious")
	if rng.randf() < 0.3:
		var keys := _personalities.keys()
		_personality = keys[rng.randi() % keys.size()]
	home_pos = global_position

	_build_body()
	_build_label()
	_add_hit_area()
	add_to_group("creatures")
	_player = get_tree().get_first_node_in_group("player")
	_world = get_tree().get_first_node_in_group("world")
	ai_state = "Explore"


# ------------------------------------------------------------------- body --
func _build_body() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)
	var model_path: String = def.get("model", "")
	if model_path != "" and ResourceLoader.exists(model_path):
		var scene: PackedScene = load(model_path)
		if scene:
			var visual := scene.instantiate()
			_body_root.add_child(visual)
			_apply_model_tint(visual)
			_anim = _find_anim(visual)
			if _anim:
				_anim.play(_anim_name("Idle"))
			var s: float = Data.size_scale(def.get("size_class", "Medium")) * (1.6 if boss_mode else 1.0)
			_body_root.scale = Vector3(s, s, s)
			if def.get("body_plan", "") in ["Floating", "Amorphous"]:
				_body_root.position.y = 1.0
			return
	_build_procedural_body()


func _anim_name(kind: String) -> String:
	# production GLB animations follow AM_<Species>_<Kind>
	var species: String = def.get("name", "Echo").replace(" ", "")
	if _anim.has_animation("AM_%s_%s" % [species, kind]):
		return "AM_%s_%s" % [species, kind]
	for lib in _anim.get_animation_list():
		if lib.ends_with("/%s" % kind) or lib.find("_%s" % kind) >= 0:
			return lib
	return ""


func _find_anim(node: Node) -> AnimationPlayer:
	for c in node.get_children():
		if c is AnimationPlayer:
			return c
		var found := _find_anim(c)
		if found:
			return found
	return null


func _apply_model_tint(root: Node) -> void:
	# recolor GLB materials toward species tints (keeps model detail)
	var prim: Array = def["colors"]["primary"]
	var sec: Array = def["colors"]["secondary"]
	var idx := 0
	for mi in _all_meshes(root):
		var mat := StandardMaterial3D.new()
		var c: Color = Color(prim[0], prim[1], prim[2]) if idx % 2 == 0 else Color(sec[0], sec[1], sec[2])
		mat.albedo_color = c
		mat.roughness = 0.8
		var el: Color = Data.element_color(def.get("element", "None"))
		if el != Color(0.8, 0.8, 0.8):
			mat.emission_enabled = true
			mat.emission = el * 0.5
			mat.emission_energy_multiplier = 0.8
		mi.material_override = mat
		idx += 1


func _all_meshes(node: Node, acc: Array = []) -> Array:
	if node is MeshInstance3D:
		acc.append(node)
	for c in node.get_children():
		_all_meshes(c, acc)
	return acc


func _mat(color: Color, glow: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = glow
		mat.emission_energy_multiplier = energy
	return mat


func _box(part: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	_body_root.add_child(mi)
	_parts[part] = mi
	return mi


func _sphere(part: String, radius: float, pos: Vector3, mat: Material, segments: int = 12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = segments
	sph.rings = 8
	mi.mesh = sph
	mi.position = pos
	mi.material_override = mat
	_body_root.add_child(mi)
	_parts[part] = mi
	return mi


func _build_procedural_body() -> void:
	var prim: Array = def["colors"]["primary"]
	var sec: Array = def["colors"]["secondary"]
	var body_c := Color(prim[0], prim[1], prim[2])
	var accent_c := Color(sec[0], sec[1], sec[2])
	var el := Data.element_color(def.get("element", "None"))
	var glow := _mat(accent_c, el, 1.4)
	var body_mat := _mat(body_c)
	var accent_mat := _mat(accent_c)
	var s: float = Data.size_scale(def.get("size_class", "Medium")) * (1.6 if boss_mode else 1.0)
	_body_root.scale = Vector3(s, s, s)

	match def.get("body_plan", "Quadruped"):
		"Quadruped":
			_box("torso", Vector3(1.1, 0.62, 0.55), Vector3(0, 0.75, 0), body_mat)
			_box("head", Vector3(0.42, 0.38, 0.4), Vector3(0.62, 0.95, 0), body_mat)
			_sphere("eye_l", 0.06, Vector3(0.8, 1.0, 0.13), glow, 6)
			_sphere("eye_r", 0.06, Vector3(0.8, 1.0, -0.13), glow, 6)
			_box("ear_l", Vector3(0.1, 0.22, 0.08), Vector3(0.66, 1.2, 0.14), accent_mat)
			_box("ear_r", Vector3(0.1, 0.22, 0.08), Vector3(0.66, 1.2, -0.14), accent_mat)
			for i in 4:
				var lx := 0.4 if i < 2 else -0.38
				var lz := 0.22 if i % 2 == 0 else -0.22
				_box("leg%d" % i, Vector3(0.16, 0.5, 0.16), Vector3(lx, 0.28, lz), accent_mat)
			_box("tail", Vector3(0.5, 0.14, 0.12), Vector3(-0.75, 0.85, 0), accent_mat)
			_box("spine", Vector3(0.7, 0.14, 0.2), Vector3(-0.05, 1.1, 0), glow)
		"Biped":
			_box("torso", Vector3(0.5, 0.7, 0.4), Vector3(0, 1.0, 0), body_mat)
			_sphere("head", 0.26, Vector3(0, 1.55, 0), body_mat)
			_sphere("eye_l", 0.06, Vector3(0.12, 1.6, 0.18), glow, 6)
			_sphere("eye_r", 0.06, Vector3(-0.12, 1.6, 0.18), glow, 6)
			_box("arm_l", Vector3(0.14, 0.55, 0.14), Vector3(0.34, 1.05, 0), accent_mat)
			_box("arm_r", Vector3(0.14, 0.55, 0.14), Vector3(-0.34, 1.05, 0), accent_mat)
			_box("leg_l", Vector3(0.17, 0.6, 0.17), Vector3(0.14, 0.32, 0), accent_mat)
			_box("leg_r", Vector3(0.17, 0.6, 0.17), Vector3(-0.14, 0.32, 0), accent_mat)
			_box("crest", Vector3(0.2, 0.3, 0.1), Vector3(0, 1.85, 0), glow)
		"Serpent":
			var prev: Vector3 = Vector3.ZERO
			for i in 6:
				var r := 0.3 - i * 0.035
				var m := body_mat if i % 2 == 0 else accent_mat
				_sphere("seg%d" % i, r, Vector3(-i * 0.42, 0.42, sin(i * 0.8) * 0.15), m, 10)
			_sphere("head", 0.3, Vector3(0.55, 0.55, 0), body_mat)
			_sphere("eye_l", 0.06, Vector3(0.72, 0.62, 0.14), glow, 6)
			_sphere("eye_r", 0.06, Vector3(0.72, 0.62, -0.14), glow, 6)
			_box("fin", Vector3(0.3, 0.2, 0.06), Vector3(-1.8, 0.55, 0), glow)
		"Avian":
			_sphere("torso", 0.34, Vector3(0, 0.9, 0), body_mat)
			_sphere("head", 0.2, Vector3(0.3, 1.2, 0), body_mat)
			_box("beak", Vector3(0.22, 0.08, 0.08), Vector3(0.5, 1.2, 0), accent_mat)
			_box("wing_l", Vector3(0.5, 0.06, 0.55), Vector3(0, 0.95, 0.4), accent_mat)
			_box("wing_r", Vector3(0.5, 0.06, 0.55), Vector3(0, 0.95, -0.4), accent_mat)
			_box("tail_f", Vector3(0.35, 0.05, 0.2), Vector3(-0.4, 0.9, 0), glow)
			_box("leg_l", Vector3(0.06, 0.4, 0.06), Vector3(0.05, 0.45, 0.08), accent_mat)
			_box("leg_r", Vector3(0.06, 0.4, 0.06), Vector3(-0.05, 0.45, -0.08), accent_mat)
		"Floating":
			_body_root.position.y = 0.9
			_sphere("core", 0.4, Vector3(0, 1.2, 0), body_mat, 14)
			_sphere("halo_l", 0.1, Vector3(0.35, 1.45, 0.2), glow, 8)
			_sphere("halo_r", 0.1, Vector3(-0.35, 1.45, 0.2), glow, 8)
			for i in 4:
				var ang := TAU * i / 4.0
				_box("shard%d" % i, Vector3(0.1, 0.4, 0.1), Vector3(cos(ang) * 0.6, 0.9, sin(ang) * 0.6), accent_mat)
		"Amorphous":
			_sphere("core", 0.5, Vector3(0, 0.6, 0), body_mat, 14)
			_sphere("blob1", 0.28, Vector3(0.35, 0.4, 0.2), accent_mat, 10)
			_sphere("blob2", 0.22, Vector3(-0.3, 0.75, -0.15), accent_mat, 10)
			_sphere("blob3", 0.18, Vector3(0.1, 0.95, -0.25), glow, 8)
			_sphere("eye_l", 0.07, Vector3(0.15, 0.7, 0.42), glow, 6)
			_sphere("eye_r", 0.07, Vector3(-0.15, 0.7, 0.42), glow, 6)
		"Crystalline":
			_body_root.position.y = 0.2
			var crystal_mat := _mat(Color(prim[0] * 0.8 + 0.2, prim[1] * 0.8 + 0.2, prim[2] * 0.8 + 0.2), el, 1.6)
			var crystal_mat2 := _mat(Color(sec[0] * 0.8 + 0.2, sec[1] * 0.8 + 0.2, sec[2] * 0.8 + 0.2), el, 1.2)
			_box("main", Vector3(0.6, 1.6, 0.6), Vector3(0, 0.8, 0), crystal_mat)
			_box("shard1", Vector3(0.35, 1.0, 0.35), Vector3(0.45, 0.5, 0.2), crystal_mat2).rotation.z = 0.4
			_box("shard2", Vector3(0.3, 0.9, 0.3), Vector3(-0.4, 0.45, -0.25), crystal_mat2).rotation.z = -0.4
			_box("shard3", Vector3(0.28, 0.7, 0.28), Vector3(0.1, 0.35, 0.45), crystal_mat2).rotation.x = 0.4
		"Insectoid":
			_box("thorax", Vector3(0.55, 0.4, 0.45), Vector3(0, 0.7, 0), body_mat)
			_sphere("abdomen", 0.3, Vector3(-0.45, 0.65, 0), accent_mat, 12)
			_sphere("head", 0.22, Vector3(0.4, 0.8, 0), body_mat)
			_box("ant_l", Vector3(0.35, 0.04, 0.04), Vector3(0.6, 1.0, 0.12), glow)
			_box("ant_r", Vector3(0.35, 0.04, 0.04), Vector3(0.6, 1.0, -0.12), glow)
			_box("ant_l2", Vector3(0.35, 0.04, 0.04), Vector3(0.6, 1.0, 0.12), glow)
			_sphere("eye_l", 0.08, Vector3(0.52, 0.85, 0.14), glow, 8)
			_sphere("eye_r", 0.08, Vector3(0.52, 0.85, -0.14), glow, 8)
			for i in 6:
				var side := 1 if i % 2 == 0 else -1
				var fx := 0.25 if i < 2 else (0.0 if i < 4 else -0.3)
				var leg := _box("leg%d" % i, Vector3(0.5, 0.06, 0.06), Vector3(fx, 0.5, side * 0.32), accent_mat)
				leg.rotation.y = side * 0.7
			_box("plate", Vector3(0.5, 0.1, 0.5), Vector3(0, 0.92, 0), glow)
		_:
			_sphere("core", 0.5, Vector3(0, 0.7, 0), body_mat, 12)
			_sphere("eye_l", 0.07, Vector3(0.18, 0.8, 0.4), glow, 6)
			_sphere("eye_r", 0.07, Vector3(-0.18, 0.8, 0.4), glow, 6)


func _build_label() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	var h: float = 2.2 * Data.size_scale(def.get("size_class", "Medium")) * (1.6 if boss_mode else 1.0)
	_label.position = Vector3(0, h, 0)
	_label.font_size = 34
	_label.outline_size = 8
	_label.modulate = Color(1, 1, 1)
	add_child(_label)
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	var txt: String = def.get("name", "Echo")
	if boss_mode:
		txt = "☠ " + txt
	elif captured:
		txt = "♥ %s · %s" % [txt, Game.trust_stage(trust)]
	var bar_len := 12
	var filled := int(round(clampf(hp / max_hp, 0.0, 1.0) * float(bar_len)))
	var bar := ""
	for i in bar_len:
		bar += "█" if i < filled else "░"
	var hostile_mark := " ⚔" if (def.get("hostile", false) and not captured) else ""
	_label.text = "%s%s\n%s" % [txt, hostile_mark, bar]
	var col := Color(0.4, 1.0, 0.5) if not def.get("hostile", false) else Color(1.0, 0.5, 0.4)
	if defeated:
		col = Color(0.5, 0.5, 0.5)
	if captured:
		col = Color(0.55, 0.85, 1.0)
	_label.modulate = col


func _add_hit_area() -> void:
	var area := Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 2
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	var s: float = Data.size_scale(def.get("size_class", "Medium")) * (1.6 if boss_mode else 1.0)
	cap.radius = 0.55 * s
	cap.height = 1.6 * s
	col.shape = cap
	col.position = Vector3(0, 0.8 * s, 0)
	area.add_child(col)
	add_child(area)


# ------------------------------------------------------------------ utils --
func health_fraction() -> float:
	return hp / max_hp if max_hp > 0.0 else 0.0


func is_defeated() -> bool:
	return defeated


func is_tracked() -> bool:
	return tracked


func _ground_y(x: float, z: float) -> float:
	if _world and _world.has_method("tile_height"):
		return _world.tile_height(x, z)
	return 0.0


func _personality_flee_mult() -> float:
	return _personalities.get(_personality, {"flee": 1.0})["flee"]


func _sight_radius() -> float:
	var aggro: float = _personalities.get(_personality, {"aggro": 1.0})["aggro"]
	return def.get("sight_radius", 1500.0) / 100.0 * aggro


func _in_activity_window() -> bool:
	var act: String = def.get("activity", "Diurnal")
	var night: bool = Game.is_night()
	match act:
		"Nocturnal": return night
		"Diurnal": return not night
		"Crepuscular": return Game.hour() >= 5.0 and Game.hour() <= 8.0 or Game.hour() >= 17.0 and Game.hour() <= 20.0
	return true


# -------------------------------------------------------------------- AI ---
func _process(delta: float) -> void:
	if defeated:
		_death_timer -= delta
		if _death_timer <= 0.0 and not captured:
			queue_free()
		return
	_hit_flash = maxf(0.0, _hit_flash - delta * 3.0)
	if _stagger_timer > 0.0:
		_stagger_timer -= delta
		_animate_body(delta, 0.0)
		return

	think_timer -= delta
	if think_timer <= 0.0:
		think_timer = THINK_INTERVAL
		_think()

	_move(delta)
	_animate_body(delta, velocity.length())
	if boss_mode:
		_boss_logic(delta)
	if captured and entry != null:
		_follower_passives(delta)
	_update_label()


func _think() -> void:
	if captured:
		_think_captured()
		return
	# wild decision tree (UE5 AstrawildEchoAIController, simplified)
	var player := get_tree().get_first_node_in_group("player")
	var dist := INF
	if player:
		dist = global_position.distance_to(player.global_position)
	# needs: sleep outside activity window
	if not _in_activity_window():
		ai_state = "Sleep"
		return
	# flee when hp low
	if health_fraction() <= 0.30 * _personality_flee_mult() and not boss_mode:
		ai_state = "Flee"
		return
	# hostile: combat when player perceived
	if def.get("hostile", false) and player and dist < _sight_radius() and not Game.dead:
		var to_player: Vector3 = (player.global_position - global_position).normalized()
		var facing: Vector3 = -global_transform.basis.z
		if facing.dot(to_player) > cos(deg_to_rad(75.0)) or dist < 4.0:
			ai_state = "Combat"
			return
		ai_state = "Investigate"
		return
	# curious: investigate fresh player perception
	if _personality == "Curious" and player and dist < _sight_radius() * 0.7 and health_fraction() > 0.8:
		ai_state = "Investigate"
		return
	ai_state = "Explore"


func _think_captured() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		ai_state = "Stay"
		return
	match Game.get_party_command():
		"Stay":
			ai_state = "Stay"
		"Attack":
			var target := _find_hostile_near(player.global_position, 30.0)
			if target:
				ai_state = "Combat"
				set_meta("combat_target", target)
			else:
				ai_state = "Follow"
		_:
			ai_state = "Follow"


func _find_hostile_near(pos: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for c in get_parent().get_children():
		if c == self or not (c is Node3D):
			continue
		if c.get("def") == null:
			continue
		if not c.def.get("hostile", false) or c.is_defeated() or c.captured:
			continue
		var d: float = pos.distance_to(c.global_position)
		if d < best_d:
			best_d = d
			best = c
	return best


func _move(delta: float) -> void:
	var target_velocity := Vector3.ZERO
	var speed := move_speed
	match ai_state:
		"Explore":
			if wander_target == Vector3.ZERO or global_position.distance_to(wander_target) < 1.5:
				_pick_wander()
			target_velocity = _dir_to(wander_target) * speed * 0.45
		"Investigate":
			var player := get_tree().get_first_node_in_group("player")
			if player:
				var d: float = global_position.distance_to(player.global_position)
				if d > 3.5:
					target_velocity = _dir_to(player.global_position) * speed * 0.5
		"Flee":
			var player := get_tree().get_first_node_in_group("player")
			if player and global_position.distance_to(player.global_position) < 30.0:
				target_velocity = -_dir_to(player.global_position) * speed * 1.15
			else:
				target_velocity = _dir_to(home_pos) * speed * 0.5
		"Combat":
			var target = get_tree().get_first_node_in_group("player") if not captured else get_meta("combat_target", null)
			if captured and target == null:
				target = _find_hostile_near(global_position, 40.0)
				if target == null:
					ai_state = "Follow"
			if target is Node3D:
				var d: float = global_position.distance_to(target.global_position)
				var desired := ATTACK_RANGE * 0.8
				if d > desired + 0.4:
					target_velocity = _dir_to(target.global_position) * speed
				elif d < desired - 0.6:
					target_velocity = -_dir_to(target.global_position) * speed * 0.5
				attack_timer -= delta
				if d <= ATTACK_RANGE + 0.3 and attack_timer <= 0.0:
					attack_timer = ATTACK_COOLDOWN
					_perform_attack(target)
		"Follow":
			var player := get_tree().get_first_node_in_group("player")
			if player:
				var d: float = global_position.distance_to(player.global_position)
				if d > 3.2:
					target_velocity = _dir_to(player.global_position) * speed * (1.25 if d > 8.0 else 1.0)
		"Sleep":
			target_velocity = Vector3.ZERO
		"Stay":
			target_velocity = Vector3.ZERO
		"Alert":
			target_velocity = Vector3.ZERO

	velocity = velocity.lerp(target_velocity, clampf(delta * 6.0, 0.0, 1.0))
	if velocity.length() > 0.05:
		var n := velocity.normalized()
		global_position += n * velocity.length() * delta
		# stick to ground
		global_position.y = _ground_y(global_position.x, global_position.z) + (0.9 if def.get("body_plan") in ["Floating", "Amorphous"] else 0.0)
		# face movement direction
		var look := global_position + Vector3(n.x, 0, n.z)
		if look != global_position:
			var target_basis := Transform3D().looking_at(look - global_position, Vector3.UP)
			global_basis = global_basis.slerp(target_basis.basis, clampf(delta * 5.0, 0.0, 1.0))


func _pick_wander() -> void:
	var ang := rng.randf() * TAU
	var r := rng.randf_range(4.0, 15.0)
	wander_target = home_pos + Vector3(cos(ang) * r, 0, sin(ang) * r)
	wander_target.y = _ground_y(wander_target.x, wander_target.z)


func _dir_to(pos: Vector3) -> Vector3:
	var v := pos - global_position
	v.y = 0.0
	return v.normalized() if v.length() > 0.01 else Vector3.ZERO


# ----------------------------------------------------------------- combat --
func _perform_attack(target: Node3D) -> void:
	var atk: float = def["stats"]["atk"]
	var mult := 1.0
	if boss_mode:
		mult = [1.0, 1.15, 1.4][_phase - 1]
	_play_anim("Hit")
	if target == get_tree().get_first_node_in_group("player"):
		Game.take_damage(atk * mult, def.get("element", "None"), true)
		_apply_status_to_player(def.get("element", "None"))
	else:
		if target.has_method("take_hit"):
			target.take_hit(atk * mult, "None")
	# lunge animation
	if _body_root:
		var tw := create_tween()
		tw.tween_property(_body_root, "position:z", 0.5, 0.12)
		tw.tween_property(_body_root, "position:z", 0.0, 0.18)


func _apply_status_to_player(element: String) -> void:
	match element:
		"Ember": Game.apply_status("Burning", 4.0, 2.5, 1.0)
		"Frost": Game.apply_status("Chilled", 3.0, 0.0, 0.5)
		"Flora": Game.apply_status("Poisoned", 6.0, 2.0, 1.0)
		"Pulse": Game.apply_status("Shocked", 0.8, 0.0, 0.3)


func take_hit(raw: float, element: String = "None") -> void:
	if defeated:
		return
	var damage := raw
	var weakness: String = def.get("weakness", "")
	var own: String = def.get("element", "None")
	if element == weakness and weakness != "":
		damage *= 1.5
	elif element == own and own != "None":
		damage *= 0.8
	if boss_mode and _weak_orb and is_instance_valid(_weak_orb) and _weak_orb.visible:
		damage *= 2.0
		Game.toast.emit("Weak point struck!", Color(1.0, 0.9, 0.4))
	damage = maxf(0.0, damage - float(def["stats"]["def"]))
	hp -= damage
	_hit_flash = 1.0
	_update_label()
	if hp <= 0.0:
		_die()
	elif damage >= 35.0 and not boss_mode:
		_stagger_timer = 0.6
	# aggro when hurt by player proximity (simplified: hostile retaliation)
	if not captured and not def.get("hostile", false) and damage > 0:
		ai_state = "Flee"


func _die() -> void:
	defeated = true
	hp = 0.0
	_death_timer = 8.0
	ai_state = "Dead"
	_play_anim("Hit")
	if _body_root:
		var tw := create_tween()
		tw.tween_property(_body_root, "rotation:x", -PI / 2.0, 0.4)
		tw.parallel().tween_property(_body_root, "position:y", 0.2 if def.get("body_plan") not in ["Floating", "Amorphous"] else -0.6, 0.4)
	# loot
	var loot: Array = def.get("loot", [])
	for drop in loot:
		Game.add_item(drop["item"], int(drop["qty"]))
		Game.toast.emit("+%d %s" % [int(drop["qty"]), Data.item_name(drop["item"])], Color(1.0, 0.85, 0.6))
	if not captured:
		Game.echo_defeated.emit(def["id"])
		Game.notify_event("DefeatCreature", def["id"])
	# XP to party
	for e in Game.party:
		Game.add_party_xp(e, 8.0 + float(def["stats"]["hp"]) * 0.05)
	_update_label()


# ------------------------------------------------------------------ boss ---
func _boss_logic(delta: float) -> void:
	# phases
	var frac := health_fraction()
	var new_phase := 1
	if frac <= 0.33:
		new_phase = 3
	elif frac <= 0.66:
		new_phase = 2
	if new_phase != _phase:
		_phase = new_phase
		Game.toast.emit("%s enters phase %d!" % [def.get("name", "Boss"), _phase], Color(1.0, 0.5, 0.3))

	_special_timer -= delta
	if _special_timer <= 0.0:
		_special_timer = 7.0
		_start_telegraph()
	if _telegraph_timer > 0.0:
		_telegraph_timer -= delta
		if _telegraph_timer <= 0.0:
			_resolve_telegraph()
	_weak_timer -= delta
	if _weak_timer <= 0.0:
		_weak_timer = 12.0
		_show_weak_point(5.0)
	if _weak_orb and is_instance_valid(_weak_orb) and _weak_orb.visible:
		_weak_orb.rotate_y(delta * 3.0)


func _start_telegraph() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if _telegraph_mesh == null:
		_telegraph_mesh = MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 3.5
		cyl.bottom_radius = 3.5
		cyl.height = 0.08
		_telegraph_mesh.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.15, 0.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.15, 0.1)
		mat.emission_energy_multiplier = 1.4
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_telegraph_mesh.material_override = mat
		add_child(_telegraph_mesh)
	var p: Vector3 = player.global_position
	_telegraph_mesh.global_position = Vector3(p.x, _ground_y(p.x, p.z) + 0.06, p.z)
	_telegraph_mesh.visible = true
	_telegraph_timer = 1.5


func _resolve_telegraph() -> void:
	if _telegraph_mesh == null:
		return
	var center: Vector3 = _telegraph_mesh.global_position
	_telegraph_mesh.visible = false
	var player := get_tree().get_first_node_in_group("player")
	if player and player.global_position.distance_to(center) <= 3.5:
		Game.take_damage(45.0, def.get("element", "None"), true)
		Game.toast.emit("The ground erupts!", Color(1.0, 0.4, 0.3))


func _show_weak_point(duration: float) -> void:
	if _weak_orb == null:
		_weak_orb = MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.35
		sph.height = 0.7
		_weak_orb.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.85, 0.3)
		mat.emission_energy_multiplier = 2.5
		_weak_orb.material_override = mat
		add_child(_weak_orb)
	var s: float = Data.size_scale(def.get("size_class", "Huge"))
	_weak_orb.position = Vector3(0, 2.6 * s, 0.8)
	_weak_orb.visible = true
	await get_tree().create_timer(duration).timeout
	if _weak_orb and is_instance_valid(_weak_orb):
		_weak_orb.visible = false


# -------------------------------------------------------------- followers --
func become_captured(player: Node3D) -> void:
	captured = true
	ai_state = "Follow"
	_play_anim("Idle")
	_update_label()


func bind_entry(p_entry: Dictionary) -> void:
	entry = p_entry
	trust = float(entry.get("trust", 0.0))
	var sdef := Data.species_def(entry.get("species_id", ""))
	if not sdef.is_empty():
		max_hp = float(sdef["stats"]["hp"]) * (1.0 + 0.1 * float(entry.get("level", 1) - 1))
	_update_label()


func _follower_passives(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var near: bool = global_position.distance_to(player.global_position) < 15.0
	var passive: String = str(entry.get("passive", ""))
	if near and passive == "PartyHeal":
		Game.heal(1.0 * delta)
	# regenerate bound echo hp slowly
	if entry.get("hp", 0.0) is float or entry.get("hp", 0) is int:
		entry["hp"] = minf(max_hp, float(entry.get("hp", max_hp)) + 0.5 * delta)


# ------------------------------------------------------------- animation ---
func _animate_body(delta: float, speed: float) -> void:
	if _anim:
		if speed > 0.3:
			var cur := _anim.current_animation
			if not cur.ends_with("Move") and _anim_name("Move") != "":
				_anim.play(_anim_name("Move"))
		else:
			var cur2 := _anim.current_animation
			if not cur2.ends_with("Idle") and _anim_name("Idle") != "":
				_anim.play(_anim_name("Idle"))
		return
	# procedural animation
	_walk_phase += delta * (4.0 + speed * 2.0)
	var walking := speed > 0.3
	var swing := sin(_walk_phase) * (0.5 if walking else 0.08)
	var bob := absf(sin(_walk_phase)) * (0.06 if walking else 0.02)
	match def.get("body_plan", "Quadruped"):
		"Quadruped":
			for i in 4:
				var leg: Node3D = _parts.get("leg%d" % i, null)
				if leg:
					leg.rotation.x = swing if i % 2 == 0 else -swing
			if _body_root:
				_body_root.position.y = bob
			var tail: Node3D = _parts.get("tail", null)
			if tail:
				tail.rotation.y = sin(_walk_phase * 0.7) * 0.3
		"Biped":
			var arm_l: Node3D = _parts.get("arm_l", null)
			var arm_r: Node3D = _parts.get("arm_r", null)
			var leg_l: Node3D = _parts.get("leg_l", null)
			var leg_r: Node3D = _parts.get("leg_r", null)
			if leg_l: leg_l.rotation.x = swing
			if leg_r: leg_r.rotation.x = -swing
			if arm_l: arm_l.rotation.x = -swing * 0.7
			if arm_r: arm_r.rotation.x = swing * 0.7
			if _body_root:
				_body_root.position.y = bob
		"Serpent":
			for i in 6:
				var seg: Node3D = _parts.get("seg%d" % i, null)
				if seg:
					seg.position.y = 0.42 + sin(_walk_phase - i * 0.7) * 0.08
		"Avian":
			var wl: Node3D = _parts.get("wing_l", null)
			var wr: Node3D = _parts.get("wing_r", null)
			if wl: wl.rotation.x = sin(_walk_phase * 2.0) * 0.5
			if wr: wr.rotation.x = -sin(_walk_phase * 2.0) * 0.5
			if _body_root:
				_body_root.position.y = 0.05 + sin(_walk_phase * 2.0) * 0.05
		"Floating":
			if _body_root:
				_body_root.position.y = 0.9 + sin(_walk_phase * 0.8) * 0.15
			for i in 4:
				var shard: Node3D = _parts.get("shard%d" % i, null)
				if shard:
					shard.rotation.y += delta * 0.8
		"Amorphous":
			if _body_root:
				_body_root.scale = Vector3.ONE * (1.0 + sin(_walk_phase * 0.9) * 0.05)
			var b1: Node3D = _parts.get("blob1", null)
			if b1: b1.position.y = 0.4 + sin(_walk_phase) * 0.06
		"Crystalline":
			if _body_root:
				_body_root.rotation.y += delta * 0.4
		"Insectoid":
			for i in 6:
				var leg: Node3D = _parts.get("leg%d" % i, null)
				if leg:
					leg.rotation.z = sin(_walk_phase * 1.6 + i) * 0.25
	# hit flash tint on parts
	if _hit_flash > 0.0 and _body_root:
		pass  # flash handled by scale pulse
	if _hit_flash > 0.0 and _body_root and not _anim:
		var pulse := 1.0 + _hit_flash * 0.12
		_body_root.scale = _body_root.scale.lerp(Vector3.ONE * Data.size_scale(def.get("size_class", "Medium")) * (1.6 if boss_mode else 1.0) * pulse, 0.4)


func _play_anim(kind: String) -> void:
	if _anim == null:
		return
	var n := _anim_name(kind)
	if n != "":
		_anim.play(n)
