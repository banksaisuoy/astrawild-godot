extends Node
## Saves — versioned save/load with backup slot.
## Schema: {version, saved_at, game: {...}, player_pos, buildings, creatures}

const SAVE_VERSION := 2
const SAVE_PATH := "user://astrawild_save.json"
const BACKUP_PATH := "user://astrawild_save.backup.json"

signal saved
signal loaded


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game(world_root: Node = null, player: Node = null) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game": {
			"world_seed": Game.world_seed,
			"day": Game.day,
			"time_minutes": Game.time_minutes,
			"weather_id": Game.weather_id,
			"weather_timer": Game.weather_timer,
			"hp": Game.hp,
			"stamina": Game.stamina,
			"hunger": Game.hunger,
			"thirst": Game.thirst,
			"inventory": Game.inventory,
			"equipment": Game.equipment,
			"research_points": Game.research_points,
			"unlocked_tech": Game.unlocked_tech.keys(),
			"journal": Game.journal,
			"quest_states": Game.quest_states,
			"active_quest": Game.active_quest,
			"completed_quests": Game.completed_quests.keys(),
			"party": Game.party,
			"echo_box": Game.echo_box,
			"discovered_zones": Game.discovered_zones.keys(),
			"current_zone_id": Game.current_zone_id,
		},
	}
	if player and player is Node3D:
		data["player_pos"] = {"x": player.global_position.x, "y": player.global_position.y, "z": player.global_position.z}
	if world_root and world_root.has_method("get_save_data"):
		data["world"] = world_root.get_save_data()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		Game.toast.emit("Save failed — could not write file.", Color(1, 0.5, 0.5))
		return false
	f.store_string(JSON.stringify(data, "\t"))
	Game.toast.emit("Progress saved.", Color(0.8, 1.0, 0.85))
	Game.game_saved.emit()
	saved.emit()
	return true


func load_game() -> Dictionary:
	if not has_save():
		return {}
	var path := SAVE_PATH
	var data: Variant = null
	for attempt in 2:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			break
		data = JSON.parse_string(f.get_as_text())
		if data != null and data is Dictionary and int(data.get("version", 0)) == SAVE_VERSION:
			break
		data = null
		path = BACKUP_PATH
	if data == null:
		Game.toast.emit("Save file unreadable — starting fresh.", Color(1, 0.6, 0.5))
		return {}
	# rotate backup
	if FileAccess.file_exists(SAVE_PATH):
		var src := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var dst := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
		if src and dst:
			dst.store_string(src.get_as_text())
	_apply(data)
	Game.game_loaded.emit()
	loaded.emit()
	return data


func _apply(data: Dictionary) -> void:
	var g: Dictionary = data.get("game", {})
	Game.reset_run()
	Game.world_seed = int(g.get("world_seed", 1337))
	Game.day = int(g.get("day", 1))
	Game.time_minutes = float(g.get("time_minutes", 480.0))
	Game.weather_id = str(g.get("weather_id", "Clear"))
	Game.weather_timer = float(g.get("weather_timer", 90.0))
	Game.hp = float(g.get("hp", 100.0))
	Game.stamina = float(g.get("stamina", 100.0))
	Game.hunger = float(g.get("hunger", 100.0))
	Game.thirst = float(g.get("thirst", 100.0))
	Game.inventory = {}
	for k in g.get("inventory", {}):
		Game.inventory[k] = int(g["inventory"][k])
	Game.equipment = g.get("equipment", Game.equipment)
	Game.research_points = int(g.get("research_points", 0))
	Game.unlocked_tech = {}
	for t in g.get("unlocked_tech", []):
		Game.unlocked_tech[t] = true
	Game.journal = g.get("journal", {})
	Game.quest_states = g.get("quest_states", {})
	Game.active_quest = str(g.get("active_quest", ""))
	Game.completed_quests = {}
	for q in g.get("completed_quests", []):
		Game.completed_quests[q] = true
	Game.party = g.get("party", [])
	Game.echo_box = g.get("echo_box", [])
	Game.discovered_zones = {}
	for z in g.get("discovered_zones", []):
		Game.discovered_zones[z] = true
	Game.current_zone_id = str(g.get("current_zone_id", ""))
	Game.equip("body", Game.equipment.get("body", ""))
	Game.equip("head", Game.equipment.get("head", ""))
	Game.stats_changed.emit()
	Game.inventory_changed.emit()
	Game.party_changed.emit()
	Game.quest_changed.emit()
	Game.research_changed.emit()


func player_pos(data: Dictionary) -> Vector3:
	var p: Dictionary = data.get("player_pos", {})
	return Vector3(float(p.get("x", -400.0)), float(p.get("y", 4.0)), float(p.get("z", 0.0)))


func delete_save() -> void:
	for path in [SAVE_PATH, BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
