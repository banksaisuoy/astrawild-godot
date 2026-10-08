extends SceneTree
## Headless utility: instantiate every Quaternius rig once and print its
## native AABB footprint, so species_models.json scales can be calibrated
## (target body length = size_scale(size_class) meters).
## Usage: godot --headless --path . -s tools/measure_rigs.gd

func _init() -> void:
        var base := "res://assets/meshes/quaternius/"
        var rigs: Array = []
        for folder in ["animals", "monsters_big", "monsters_blob", "monsters_flying"]:
                var dir := DirAccess.open(base + str(folder))
                if dir == null:
                        continue
                dir.list_dir_begin()
                var f := dir.get_next()
                while f != "":
                        if f.ends_with(".gltf"):
                                rigs.append(str(folder) + "/" + f)
                        f = dir.get_next()
                dir.list_dir_end()
        rigs.sort()
        for r in rigs:
                var path: String = base + str(r)
                if not ResourceLoader.exists(path):
                        print("RIG %s MISSING" % r)
                        continue
                var scene: PackedScene = load(path)
                if scene == null:
                        print("RIG %s LOAD_FAIL" % r)
                        continue
                var node: Node3D = scene.instantiate()
                root.add_child(node)
                var aabb := AABB()
                var has := false
                for c in _walk(node):
                        if c is VisualInstance3D:
                                var a: AABB = (c as VisualInstance3D).get_aabb()
                                a.position = node.global_transform * a.position
                                a.size = node.global_transform.basis * a.size
                                if not has:
                                        aabb = a
                                        has = true
                                else:
                                        aabb = aabb.merge(a)
                var maxd: float = 0.0
                if has:
                        maxd = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
                print("RIG %s native=%.2f x=%.2f y=%.2f z=%.2f" % [r, maxd, aabb.size.x, aabb.size.y, aabb.size.z])
                node.queue_free()
        quit(0)


func _walk(n: Node) -> Array:
        var out := [n]
        for c in n.get_children():
                out.append_array(_walk(c))
        return out
