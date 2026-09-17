extends Node3D
## Dungeon resonance portal (UE5 AstrawildDungeonPortalActor, Batch 6 Item C).
## Flat resonance pad; interact (E) teleports the player with a 6 m range guard
## and publishes Event.LocationReached with the portal id (quest ReachLocation).

var portal_id := ""
var portal_label := ""
var portal_color := Color(0.8, 0.45, 0.9)
var destination := Vector3.ZERO
var _ring: MeshInstance3D


func _ready() -> void:
	portal_id = str(get_meta("portal_id", ""))
	portal_label = str(get_meta("portal_label", "Resonance Gate"))
	portal_color = get_meta("portal_color", Color(0.8, 0.45, 0.9))
	destination = get_meta("portal_dest", Vector3.ZERO)
	add_to_group("interactables")
	set_meta("interact_kind", "portal")

	# squashed cylinder pad (UE5: engine cylinder squashed)
	_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.7
	cyl.bottom_radius = 2.0
	cyl.height = 0.14
	_ring.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = portal_color
	mat.emission_enabled = true
	mat.emission = portal_color
	mat.emission_energy_multiplier = 1.8
	_ring.material_override = mat
	_ring.position = Vector3(0, 0.1, 0)
	add_child(_ring)
	# hovering resonance shard
	var shard := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 1.2, 0.7)
	shard.mesh = prism
	var smat := StandardMaterial3D.new()
	smat.albedo_color = portal_color.lightened(0.3)
	smat.emission_enabled = true
	smat.emission = portal_color.lightened(0.3)
	smat.emission_energy_multiplier = 2.4
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color.a = 0.8
	shard.material_override = smat
	shard.position = Vector3(0, 1.5, 0)
	add_child(shard)
	var tw := create_tween().set_loops()
	tw.tween_property(shard, "position:y", 2.0, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(shard, "position:y", 1.5, 1.4).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(shard, "rotation:y", TAU, 4.0)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.6, 0)
	light.omni_range = 10.0
	light.light_color = portal_color
	light.light_energy = 1.4
	add_child(light)


func prompt() -> String:
	return "%s — [E] step through" % portal_label


func interact() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	# 6 m range guard (anti-cheat, UE5 policy)
	if global_position.distance_to(player.global_position) > 6.0:
		return false
	var world := get_tree().get_first_node_in_group("world")
	var dest := destination
	if world and world.has_method("tile_height"):
		dest.y = maxf(dest.y, world.tile_height(dest.x, dest.z) + 0.4)
	player.global_position = dest
	player.velocity = Vector3.ZERO
	Game.notify_event("ReachLocation", portal_id)
	Game.add_research_points(1)
	Game.toast.emit("Resonance shift — %s" % portal_label, Color(0.85, 0.7, 1.0))
	return true
