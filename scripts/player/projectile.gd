extends Node3D
## Simple forward projectile (ranged weapons). Sweeps against creature areas.

var damage := 10.0
var element := "None"
var speed := 55.0
var life := 1.6
var direction := Vector3.FORWARD


func _ready() -> void:
	damage = float(get_meta("damage", 10.0))
	element = str(get_meta("element", "None"))
	speed = float(get_meta("speed", 55.0))
	life = float(get_meta("life", 1.6))
	direction = get_meta("direction", Vector3.FORWARD)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var step := direction * speed * delta
	# shape query along the step
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position + step * 0.5)
	query.collision_mask = 4
	var hits := space.intersect_shape(query, 8)
	if not hits.is_empty():
		for hit in hits:
			var collider := hit["collider"]
			var echo := collider.get_parent() if collider is Area3D else collider
			if echo and echo.has_method("take_hit"):
				echo.take_hit(damage, element)
				queue_free()
				return
	global_position += step
	# terrain hit
	var world := get_tree().get_first_node_in_group("world")
	if world and world.has_method("tile_height"):
		if global_position.y < world.tile_height(global_position.x, global_position.z):
			queue_free()
