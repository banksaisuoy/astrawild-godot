class_name Village
extends Node3D
## Living village (UE5 AstrawildVillageActor, Batch 8). Builds the hamlet and
## owns the waypoint circuit its NPCs patrol. Huts (cylinder + conical roof +
## door glow), palisade ring of stakes, campfire with light, lamp posts, and the
## full NPC roster linked through village_id / waypoints / campfire_pos metas.
## Dawnstead: 7 huts + 8 NPCs. Driftwood Landing: 3 huts + dock + 3 NPCs.

var village_id := "Village_Dawnstead"
var display_name := "Dawnstead"
var center := Vector3.ZERO
var campfire := Vector3.ZERO
var waypoints: Array = []
var _mesh_cache := {}


func setup(p_id: String, p_name: String, p_center: Vector3) -> void:
	village_id = p_id
	display_name = p_name
	center = p_center


func build(parent: Node3D, world: Node) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("village-%s-%d" % [village_id, Game.world_seed])
	campfire = center + Vector3(0, 0, 0)
	var ground: float = 0.0
	if world and world.has_method("tile_height"):
		ground = world.tile_height(center.x, center.z)
	campfire.y = ground

	var is_dock := village_id == "Village_Driftwood"
	var hut_count := 7 if not is_dock else 3
	var ring_radius := 26.0 if not is_dock else 15.0

	# --- campfire at the heart (the night gathering point) ---
	_add_campfire(parent, world)

	# --- huts in a ring ---
	for i in hut_count:
		var ang := TAU * float(i) / float(hut_count) + rng.randf() * 0.25
		var hr := ring_radius * (0.85 + rng.randf() * 0.3)
		var hx := center.x + cos(ang) * hr
		var hz := center.z + sin(ang) * hr
		var hy: float = world.tile_height(hx, hz) if world and world.has_method("tile_height") else ground
		_add_hut(parent, Vector3(hx, hy, hz), rng)

	# --- palisade ring (Dawnstead) / dock planks (Driftwood) ---
	if is_dock:
		_add_dock(parent, world)
	else:
		var stakes := 26
		for i in stakes:
			var ang := TAU * float(i) / float(stakes)
			var sx := center.x + cos(ang) * (ring_radius + 12.0)
			var sz := center.z + sin(ang) * (ring_radius + 12.0)
			var sy: float = world.tile_height(sx, sz) if world and world.has_method("tile_height") else ground
			_add_stake(parent, Vector3(sx, sy, sz), rng)

	# --- lamp posts on the main paths ---
	for i in 4:
		var ang := TAU * float(i) / 4.0 + 0.4
		var lx := center.x + cos(ang) * (ring_radius * 0.55)
		var lz := center.z + sin(ang) * (ring_radius * 0.55)
		var ly: float = world.tile_height(lx, lz) if world and world.has_method("tile_height") else ground
		_add_lamp_post(parent, Vector3(lx, ly, lz))

	# --- waypoint circuit (6 posts around + through the village) ---
	waypoints = []
	for i in 6:
		var ang := TAU * float(i) / 6.0 + rng.randf() * 0.3
		var wr := ring_radius * (0.5 + rng.randf() * 0.35)
		var wx := center.x + cos(ang) * wr
		var wz := center.z + sin(ang) * wr
		var wy: float = world.tile_height(wx, wz) if world and world.has_method("tile_height") else ground
		waypoints.append(Vector3(wx, wy, wz))

	# --- village signpost ---
	_add_sign(parent, world)

	# --- NPC roster ---
	_spawn_roster(parent, world)


# ------------------------------------------------------------------ pieces --
func _add_hut(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var hut := Node3D.new()
	hut.position = pos
	hut.rotation.y = rng.randf() * TAU
	parent.add_child(hut)
	# walls (cylinder silhouette via stacked boxes for the round feel)
	var wall := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.6
	cyl.bottom_radius = 2.9
	cyl.height = 2.6
	wall.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.44, 0.32)
	mat.roughness = 0.9
	wall.material_override = mat
	wall.position = Vector3(0, 1.3, 0)
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hut.add_child(wall)
	# conical roof
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(7.0, 2.2, 7.0)
	roof.mesh = prism
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.42, 0.33, 0.24)
	roof_mat.roughness = 0.95
	roof.material_override = roof_mat
	roof.position = Vector3(0, 3.6, 0)
	roof.rotation.y = PI / 4.0
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	hut.add_child(roof)
	# door glow
	var door := MeshInstance3D.new()
	var dbox := BoxMesh.new()
	dbox.size = Vector3(1.0, 1.6, 0.12)
	door.mesh = dbox
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.9, 0.65, 0.3)
	dmat.emission_enabled = true
	dmat.emission = Color(0.85, 0.5, 0.2)
	dmat.emission_energy_multiplier = 1.4
	door.material_override = dmat
	door.position = Vector3(0, 0.8, 2.95)
	hut.add_child(door)
	# collision so the player can't walk through
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 2.9
	shape.height = 4.6
	col.shape = shape
	col.position = Vector3(0, 2.3, 0)
	body.add_child(col)
	hut.add_child(body)


func _add_stake(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var stake := MeshInstance3D.new()
	var box := BoxMesh.new()
	var h := 3.2 + rng.randf() * 0.7
	box.size = Vector3(0.32, h, 0.32)
	stake.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.36, 0.26)
	mat.roughness = 0.95
	stake.material_override = mat
	stake.position = pos + Vector3(0, h * 0.5, 0)
	stake.rotation.y = rng.randf() * TAU
	stake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(stake)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, h, 0.4)
	col.shape = shape
	col.position = Vector3(0, h * 0.5, 0)
	body.add_child(col)
	stake.add_child(body)


func _add_dock(parent: Node3D, world: Node) -> void:
	# planks running toward the water
	for i in 6:
		var px := center.x - 8.0 - i * 2.2
		var pz := center.z + 10.0
		var py: float = (world.tile_height(px, pz) if world and world.has_method("tile_height") else center.y) + 0.35
		var plank := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.0, 0.18, 5.5)
		plank.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.42, 0.3)
		mat.roughness = 0.92
		plank.material_override = mat
		plank.position = Vector3(px, py, pz)
		parent.add_child(plank)
	# mooring posts
	for i in 2:
		var mx := center.x - 8.0 - i * 8.0
		var mz := center.z + 12.8
		var my: float = world.tile_height(mx, mz) if world and world.has_method("tile_height") else center.y
		_add_stake(parent, Vector3(mx, my, mz), RandomNumberGenerator.new())


func _add_lamp_post(parent: Node3D, pos: Vector3) -> void:
	var post := Node3D.new()
	post.position = pos
	parent.add_child(post)
	var pole := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 3.4, 0.16)
	pole.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.3, 0.26)
	pole.material_override = mat
	pole.position = Vector3(0, 1.7, 0)
	post.add_child(pole)
	var lamp := MeshInstance3D.new()
	var lbox := BoxMesh.new()
	lbox.size = Vector3(0.42, 0.42, 0.42)
	lamp.mesh = lbox
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.88, 0.6)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.8, 0.45)
	lmat.emission_energy_multiplier = 2.2
	lamp.material_override = lmat
	lamp.position = Vector3(0, 3.5, 0)
	post.add_child(lamp)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 3.6, 0)
	light.omni_range = 11.0
	light.light_color = Color(1.0, 0.82, 0.5)
	light.light_energy = 1.5
	post.add_child(light)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 3.4, 0.3)
	col.shape = shape
	col.position = Vector3(0, 1.7, 0)
	body.add_child(col)
	post.add_child(body)


func _add_campfire(parent: Node3D, world: Node) -> void:
	var fire_pos := campfire + Vector3(2.0, 0, 2.0)
	if world and world.has_method("tile_height"):
		fire_pos.y = world.tile_height(fire_pos.x, fire_pos.z)
	var fire := CPUParticles3D.new()
	fire.amount = 34
	fire.lifetime = 1.2
	fire.position = fire_pos + Vector3(0, 0.4, 0)
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 14.0
	fire.initial_velocity_min = 0.8
	fire.initial_velocity_max = 2.0
	fire.gravity = Vector3(0, 1.4, 0)
	fire.scale_amount_min = 0.12
	fire.scale_amount_max = 0.32
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.45, 0.1)
	mat.emission_energy_multiplier = 3.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	fire.mesh = quad
	parent.add_child(fire)
	var light := OmniLight3D.new()
	light.position = fire_pos + Vector3(0, 1.5, 0)
	light.omni_range = 16.0
	light.light_color = Color(1.0, 0.6, 0.3)
	light.light_energy = 1.7
	parent.add_child(light)
	var tw := create_tween().set_loops()
	tw.tween_property(light, "light_energy", 1.2, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "light_energy", 1.8, 0.5).set_trans(Tween.TRANS_SINE)


func _add_sign(parent: Node3D, world: Node) -> void:
	var sp := center + Vector3(0, 0, -30.0)
	if world and world.has_method("tile_height"):
		sp.y = world.tile_height(sp.x, sp.z)
	var sign := Node3D.new()
	sign.position = sp
	sign.rotation.y = PI
	parent.add_child(sign)
	var pole := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.14, 2.4, 0.14)
	pole.mesh = box
	pole.position = Vector3(0, 1.2, 0)
	sign.add_child(pole)
	var board := Label3D.new()
	board.text = display_name
	board.font_size = 44
	board.modulate = Color(1.0, 0.9, 0.7)
	board.outline_size = 10
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.no_depth_test = true
	board.position = Vector3(0, 2.4, 0)
	sign.add_child(board)


# ------------------------------------------------------------------- roster --
func _spawn_roster(parent: Node3D, world: Node) -> void:
	var roster: Array = DAWNSTEAD_ROSTER if village_id == "Village_Dawnstead" else DRIFTWOOD_ROSTER
	var npc_script := load("res://scripts/world/npc.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("roster-%s" % village_id)
	for i in roster.size():
		var npc_def: Dictionary = roster[i]
		var npc: Node3D = Node3D.new()
		npc.set_script(npc_script)
		var ang := TAU * float(i) / float(roster.size())
		var nx := center.x + cos(ang) * 7.0
		var nz := center.z + sin(ang) * 7.0
		npc.position = Vector3(nx, world.tile_height(nx, nz) if world and world.has_method("tile_height") else center.y, nz)
		npc.set_meta("npc_name", npc_def["name"])
		npc.set_meta("npc_color", npc_def["color"])
		npc.set_meta("npc_greeting", npc_def["greeting"])
		npc.set_meta("npc_role", npc_def["role"])
		npc.set_meta("village_id", village_id)
		npc.set_meta("waypoints", waypoints)
		npc.set_meta("campfire_pos", campfire)
		# NPCs must live under the world's npcs_root so the player's interaction
		# scan finds them (huts/stakes stay under props_root)
		if world and world.get("npcs_root"):
			world.npcs_root.add_child(npc)
		else:
			parent.add_child(npc)


const DAWNSTEAD_ROSTER := [
	{"name": "Warden Maren", "role": "quest", "color": Color(0.4, 0.85, 0.65),
		"greeting": "The fields are calm — for now. The dawnwood and fieldstone will make you ready."},
	{"name": "Trader Tam", "role": "vendor", "color": Color(0.9, 0.75, 0.35),
		"greeting": "Shards, friend. Shards for everything."},
	{"name": "Herbalist Wren", "role": "herbalist", "color": Color(0.7, 0.85, 0.4),
		"greeting": "Feed what you befriend. Every Echo has a favorite."},
	{"name": "Blacksmith Borin", "role": "armory", "color": Color(0.75, 0.5, 0.4),
		"greeting": "Steel sings when you pay in shards. Or Ancient Alloy — that hums."},
	{"name": "Elder Rowan", "role": "quest", "color": Color(0.5, 0.75, 0.85),
		"greeting": "Fisherfolk came before the flood. Take the skiff across the shallows — the vault below still hums."},
	{"name": "Guard Captain Sela", "role": "guard", "color": Color(0.85, 0.55, 0.35),
		"greeting": "Keep the fires high at night. The Gloomfangs test the palisade when the light dies."},
	{"name": "Guard Bram", "role": "guard", "color": Color(0.8, 0.5, 0.4),
		"greeting": "Nothing gets past me. Well — almost nothing."},
	{"name": "Farmer Jori", "role": "quest", "color": Color(0.6, 0.8, 0.45),
		"greeting": "The berry plot never sleeps. Neither do the Spriglings that raid it."},
]

const DRIFTWOOD_ROSTER := [
	{"name": "Skiff Warden Kael", "role": "quest", "color": Color(0.45, 0.8, 0.85),
		"greeting": "Beneath the isles sleeps a vault the tide never forgot — and the Dawnfang coils at its heart. End its long watch."},
	{"name": "Fisher Nima", "role": "vendor", "color": Color(0.7, 0.85, 0.9),
		"greeting": "Pearls, coral, a hot meal. The sea provides — for a price."},
	{"name": "Old Salt Perry", "role": "quest", "color": Color(0.6, 0.7, 0.8),
		"greeting": "The skiff rides the dawn thermals. Ride them past the reef and the vault will find you."},
]
