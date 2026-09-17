extends Node
## Data — static content registry.
## Loads every data/*.json table once and exposes typed lookups.

var items := {}            # id -> item dict
var recipes := []          # array of recipe dicts
var techs := {}            # id -> tech dict
var buildings := {}        # id -> building dict
var resource_nodes := {}   # id -> node dict
var zones := []            # ordered zone dicts
var zone_by_id := {}
var weather_states := []
var species := {}          # id -> species dict (226 total)
var species_by_zone := {}  # zone id -> array of species ids
var quests := {}           # id -> quest dict
var camp := {}

const _PATHS := {
	"items": "res://data/items.json",
	"crafting": "res://data/crafting.json",
	"zones": "res://data/zones.json",
	"bestiary": "res://data/bestiary.json",
	"special": "res://data/species_special.json",
	"quests": "res://data/quests.json",
}


func _ready() -> void:
	_load_all()


func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Data: missing data file %s" % path)
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Data: failed to parse %s" % path)
	return parsed


func _load_all() -> void:
	var item_data: Dictionary = _load_json(_PATHS.items)
	for it in item_data.get("items", []):
		items[it["id"]] = it

	var craft: Dictionary = _load_json(_PATHS.crafting)
	recipes = craft.get("recipes", [])
	for r in recipes:
		r["inputs_by_item"] = {}
		for inp in r["inputs"]:
			r["inputs_by_item"][inp["item"]] = inp["qty"]
	for t in craft.get("tech", []):
		techs[t["id"]] = t
	for b in craft.get("buildings", []):
		buildings[b["id"]] = b
	for n in craft.get("nodes", []):
		resource_nodes[n["id"]] = n

	var world: Dictionary = _load_json(_PATHS.zones)
	zones = world.get("zones", [])
	weather_states = world.get("weather", [])
	camp = world.get("camp", {})
	for z in zones:
		zone_by_id[z["id"]] = z

	var best: Array = _load_json(_PATHS.bestiary)
	for s in best:
		species[s["id"]] = s
	var special: Dictionary = _load_json(_PATHS.special)
	for s in special.get("species", []):
		species[s["id"]] = s

	for q in _load_json(_PATHS.quests):
		quests[q["id"]] = q

	for sid in species:
		var s: Dictionary = species[sid]
		var zid: String = s.get("home_zone", "")
		if not species_by_zone.has(zid):
			species_by_zone[zid] = []
		species_by_zone[zid].append(sid)

	print("Data: %d items, %d recipes, %d techs, %d buildings, %d nodes, %d zones, %d species, %d quests" % [
		items.size(), recipes.size(), techs.size(), buildings.size(),
		resource_nodes.size(), zones.size(), species.size(), quests.size()])


# ---------------------------------------------------------------- helpers --

func item(id: String) -> Dictionary:
	return items.get(id, {})


func item_name(id: String) -> String:
	return items.get(id, {}).get("name", id)


func zone(id: String) -> Dictionary:
	return zone_by_id.get(id, {})


func species_def(id: String) -> Dictionary:
	return species.get(id, {})


func element_color(el: String) -> Color:
	match el:
		"Light": return Color(1.0, 0.95, 0.72)
		"Ash": return Color(0.55, 0.52, 0.58)
		"Flora": return Color(0.45, 0.75, 0.40)
		"Ember": return Color(1.0, 0.55, 0.30)
		"Frost": return Color(0.60, 0.85, 1.0)
		"Pulse": return Color(0.55, 0.75, 1.0)
	return Color(0.8, 0.8, 0.8)


func size_scale(size_class: String) -> float:
	match size_class:
		"Tiny": return 0.45
		"Small": return 0.7
		"Medium": return 1.0
		"Large": return 1.4
		"Huge": return 1.9
	return 1.0
