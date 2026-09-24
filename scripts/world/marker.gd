extends Node3D
## Interactable world marker: rest point, station, quest location, POI beacon.

var kind := "marker"
var marker_label := ""
var location_id := ""
var beacon: MeshInstance3D
# v1.1 Phase V6 landmark chests
var chest_loot: Array = []
var chest_opened := false
var chest_mesh: Node3D = null


func _ready() -> void:
	kind = str(get_meta("interact_kind", "marker"))
	marker_label = str(get_meta("marker_label", ""))
	location_id = str(get_meta("location_id", ""))
	if has_meta("beacon"):
		beacon = get_meta("beacon")
	if has_meta("chest_loot"):
		chest_loot = get_meta("chest_loot")
	if has_meta("chest_mesh"):
		chest_mesh = get_meta("chest_mesh")
	add_to_group("interactables")


func prompt() -> String:
	match kind:
		"rest": return "Rest Point — [E] rest & save"
		"station_workbench": return "Workbench — [E] craft"
		"location": return "%s — [E] examine" % marker_label
		"chest": return ("%s — [E] open" % marker_label) if not chest_opened else "%s (opened)" % marker_label
		"marker": return "%s" % marker_label
	return marker_label


func interact() -> bool:
	match kind:
		"rest":
			Game.full_restore()
			var world := get_tree().get_first_node_in_group("world")
			Saves.save_game(world, get_tree().get_first_node_in_group("player"))
			return true
		"station_workbench":
			var screens := get_tree().get_first_node_in_group("screens")
			if screens:
				screens.open_crafting("Station_Workbench")
			return true
		"location":
			Game.notify_event("ReachLocation", location_id)
			Game.add_research_points(2)
			Game.toast.emit("%s charted in your journal (+2 RP)" % marker_label, Color(0.8, 0.95, 1.0))
			return true
		"chest":
			if chest_opened:
				return false
			chest_opened = true
			var gained := 0
			for entry in chest_loot:
				var item_id: String = entry.get("item", "")
				var qty: int = int(entry.get("qty", 1))
				if item_id != "" and Data.items.has(item_id):
					Game.add_item(item_id, qty)
					gained += qty
					var idef: Dictionary = Data.items[item_id]
					Game.toast.emit("+%d %s" % [qty, idef.get("name", item_id)], Color(0.95, 0.85, 0.5))
			Game.add_research_points(3)
			Game.toast.emit("%s plundered (+3 RP)" % marker_label, Color(0.95, 0.8, 0.4))
			Sfx.play_event("ui_confirm")
			# swap the mesh look: golden chest -> opened dark
			if chest_mesh and is_instance_valid(chest_mesh):
				for mi in _all_meshes(chest_mesh):
					var mat := StandardMaterial3D.new()
					mat.albedo_color = Color(0.35, 0.3, 0.24)
					mat.roughness = 0.9
					mi.material_override = mat
			return true
	return false


func _all_meshes(n: Node, acc: Array = []) -> Array:
	if n is MeshInstance3D:
		acc.append(n)
	for c in n.get_children():
		_all_meshes(c, acc)
	return acc
