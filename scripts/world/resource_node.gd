class_name ResourceNode
extends StaticBody3D
## Harvestable resource node — charges, respawn timer, interaction area.

signal harvested(node: ResourceNode, item_id: String, qty: int)

var def: Dictionary = {}
var charges := 3
var respawn_timer := 0.0
var mesh_instance: MeshInstance3D
var _area: Area3D
var _scanner_required := false


func _init(p_def: Dictionary) -> void:
	def = p_def


func _ready() -> void:
	charges = int(def.get("max", 3))
	_scanner_required = bool(def.get("hidden", false))
	collision_layer = 4
	collision_mask = 0

	var source: PackedScene = load(def["mesh"])
	if source:
		var visual := source.instantiate()
		mesh_instance = _first_mesh_instance(visual)
		if mesh_instance:
			var rarity_scale: float = {"Common": 1.0, "Uncommon": 1.15, "Rare": 1.3, "Epic": 1.45}.get(def.get("rarity", "Common"), 1.0)
			mesh_instance.scale = Vector3.ONE * (0.55 * rarity_scale)
			_apply_tint(mesh_instance)
		add_child(visual)

	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 2.2, 2.2)
	col.shape = box
	col.position = Vector3(0, 1.0, 0)
	add_child(col)

	_area = Area3D.new()
	_area.collision_layer = 0
	_area.collision_mask = 2
	var acol := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(3.4, 3.4, 3.4)
	abox.size = abox.size
	acol.shape = abox
	acol.position = Vector3(0, 1.2, 0)
	_area.add_child(acol)
	add_child(_area)

	if _scanner_required:
		modulate_scanner_state(false)


func _first_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root
	for c in root.get_children():
		var found := _first_mesh_instance(c)
		if found:
			return found
	return null


func _apply_tint(mi: MeshInstance3D) -> void:
	var mat := StandardMaterial3D.new()
	var t: Array = def.get("tint", [0.6, 0.6, 0.6])
	mat.albedo_color = Color(t[0], t[1], t[2])
	mat.roughness = 0.9
	if def.get("id", "").find("Crystal") >= 0 or def.get("id", "").find("Astraite") >= 0 or def.get("hidden", false):
		mat.emission_enabled = true
		mat.emission = Color(t[0], t[1], t[2]) * 0.8
		mat.emission_energy_multiplier = 1.6
	mi.material_override = mat


func modulate_scanner_state(visible_now: bool) -> void:
	if mesh_instance:
		mesh_instance.transparency = 0.85 if not visible_now else 0.0
		mesh_instance.visible = true


func scanner_visible() -> bool:
	return not _scanner_required or Game.equipment["tool"] == "Item_FieldScanner"


func interact() -> bool:
	if respawn_timer > 0.0 or charges <= 0:
		return false
	if not scanner_visible():
		Game.toast.emit("A faint resonance... a Field Scanner would reveal it.", Color(0.8, 0.8, 1.0))
		return false
	var qty := int(def.get("qty", 1))
	charges -= 1
	harvested.emit(self, def["item"], qty)
	Game.add_item(def["item"], qty)
	Game.toast.emit("+%d %s" % [qty, Data.item_name(def["item"])], Color(0.85, 1.0, 0.8))
	if charges <= 0:
		respawn_timer = float(def.get("respawn", 30.0))
		_set_visual_active(false)
	return true


func _set_visual_active(active: bool) -> void:
	for c in get_children():
		if c is Node3D and not (c is CollisionShape3D or c is Area3D):
			c.visible = active


func _process(delta: float) -> void:
	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			charges = int(def.get("max", 3))
			_set_visual_active(true)


func prompt() -> String:
	if respawn_timer > 0.0:
		return ""
	if not scanner_visible():
		return "Resonance? [E] focus"
	return "%s [%d] — [E] harvest" % [def.get("name", "Resource"), charges]
