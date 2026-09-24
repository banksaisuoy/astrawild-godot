extends SceneTree
## tools/measure_rigs.gd — print world-space AABB size of each acquired rig.
## Run: godot --headless --script tools/measure_rigs.gd --path .

func _initialize() -> void:
	var paths: Array = []
	for dir in [
		"res://assets/meshes/quaternius/animals",
		"res://assets/meshes/quaternius/monsters_flying",
		"res://assets/meshes/quaternius/monsters_big",
		"res/meshes/quaternius/monsters_blob",
		"res://assets/meshes/quaternius/monsters_blob",
		"res://assets/meshes/quaternius/village",
	]:
		var d := DirAccess.open(dir)
		if d == null:
			continue
		d.list_dir_begin()
		var fn := d.get_next()
		while fn != "":
			if fn.ends_with(".gltf") or fn.ends_with(".glb") or fn.ends_with(".fbx"):
				paths.append(dir + "/" + fn)
			fn = d.get_next()
		d.list_dir_end()

	print("RIG SIZE REPORT (unscaled import AABB):")
	for p in paths:
		var scene: PackedScene = null
		var res = ResourceLoader.exists(p)
		if res:
			scene = ResourceLoader.load(p, "PackedScene")
		if scene == null:
			print("%-58s LOAD FAILED" % p)
			continue
		var node = scene.instantiate()
		var box: AABB = node.transform * _combined_aabb(node)
		if box.size == Vector3.ZERO:
			box = _combined_aabb(node)
		print("%-58s %s  (h=%.2f)" % [p.get_file(), box.size, box.size.y])
		node.free()
	quit(0)

func _combined_aabb(n: Node) -> AABB:
	var box := AABB()
	if n is VisualInstance3D:
		box = n.get_aabb()
		var t: Transform3D = (n as Node3D).transform
		box = t * box
	for c in n.get_children():
		var b := _combined_aabb(c)
		if b.size.length() > 0.0001:
			if box.size.length() > 0.0001:
				box = box.merge(b)
			else:
				box = b
	return box
