extends Node3D
## NPC — Survivor model with a name plate, greeting dialogue and a role
## (quest giver / vendor / herbalist). Interacted with [E].

var def_color: Color = Color(0.5, 0.8, 0.6)
var display_name: String = "NPC"
var greeting: String = "..."
var role: String = "quest"
var _label: Label3D
var _anim: AnimationPlayer


func _ready() -> void:
	display_name = str(get_meta("npc_name", "NPC"))
	def_color = get_meta("npc_color", Color(0.5, 0.8, 0.6))
	greeting = str(get_meta("npc_greeting", "..."))
	role = str(get_meta("npc_role", "quest"))

	var scene: PackedScene = load("res://assets/meshes/characters/SK_Survivor_Exosuit.glb")
	if scene:
		var visual := scene.instantiate()
		add_child(visual)
		_tint(visual)
		_anim = _find_anim(visual)
		if _anim and _anim.has_animation("AM_Survivor_Idle"):
			_anim.play("AM_Survivor_Idle")

	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position = Vector3(0, 2.35, 0)
	_label.modulate = def_color
	_label.font_size = 48
	_label.outline_size = 10
	add_child(_label)


func _tint(root: Node) -> void:
	for c in _all_meshes(root):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = def_color.darkened(0.15)
		mat.roughness = 0.8
		c.material_override = mat


func _all_meshes(node: Node, acc: Array = []) -> Array:
	if node is MeshInstance3D:
		acc.append(node)
	for c in node.get_children():
		_all_meshes(c, acc)
	return acc


func _find_anim(node: Node) -> AnimationPlayer:
	for c in node.get_children():
		if c is AnimationPlayer:
			return c
		var found := _find_anim(c)
		if found:
			return found
	return null


func interact() -> bool:
	var screens := get_tree().get_first_node_in_group("screens")
	if screens:
		screens.open_dialogue(display_name, greeting, role)
	return true


func prompt() -> String:
	return "%s — [E] talk" % display_name
