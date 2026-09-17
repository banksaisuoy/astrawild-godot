class_name WeatherFX
extends Node3D
## Rain/snow particle column that follows the player. CPUParticles for web compat.

var rain: CPUParticles3D
var _player: Node3D = null
var _current: String = ""


func setup() -> void:
	rain = CPUParticles3D.new()
	rain.amount = 400
	rain.lifetime = 1.6
	rain.explosiveness = 0.0
	rain.direction = Vector3(0.15, -1, 0.1)
	rain.spread = 35.0
	rain.gravity = Vector3(0, -22, 0)
	rain.initial_velocity_min = 14.0
	rain.initial_velocity_max = 20.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(28, 1, 28)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.035, 0.55)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.65, 0.78, 0.95, 0.55)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	rain.mesh = quad
	add_child(rain)
	_apply(Game.weather_id)


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
		return
	global_position = _player.global_position + Vector3(0, 14, 0)
	if Game.weather_id != _current:
		_apply(Game.weather_id)


func _apply(state: String) -> void:
	_current = state
	match state:
		"Rain":
			rain.emitting = true
			rain.amount = 400
		"HeavyRain":
			rain.emitting = true
			rain.amount = 900
		"Storm":
			rain.emitting = true
			rain.amount = 1200
		"Fog":
			rain.emitting = false
		_:
			rain.emitting = false
