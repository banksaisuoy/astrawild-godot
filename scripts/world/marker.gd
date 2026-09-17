extends Node3D
## Interactable world marker: rest point, station, quest location, POI beacon.

var kind := "marker"
var marker_label := ""
var location_id := ""
var beacon: MeshInstance3D


func _ready() -> void:
	kind = str(get_meta("interact_kind", "marker"))
	marker_label = str(get_meta("marker_label", ""))
	location_id = str(get_meta("location_id", ""))
	beacon = get_meta("beacon", null)
	add_to_group("interactables")


func prompt() -> String:
	match kind:
		"rest": return "Rest Point — [E] rest & save"
		"station_workbench": return "Workbench — [E] craft"
		"location": return "%s — [E] examine" % marker_label
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
	return false
