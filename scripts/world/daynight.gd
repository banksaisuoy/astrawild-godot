class_name DayNightCycle
extends Node3D
## Sun + atmosphere ramp (matches UE5 EvalAtmosphereRamp semantics).
## Owns: DirectionalLight3D, WorldEnvironment, fog and sky colors.

var sun: DirectionalLight3D
var env: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var _accum := 0.0

const NIGHT_SUN := Color(0.55, 0.65, 0.90)
const NIGHT_FOG := Color(0.05, 0.07, 0.13)
const NIGHT_FOG_DENSITY := 0.0009
const DAWN_SUN := Color(1.0, 0.72, 0.45)
const NOON_SUN := Color(1.0, 0.98, 0.92)
const DUSK_SUN := Color(1.0, 0.62, 0.42)
const DAWN_FOG := Color(0.88, 0.70, 0.55)
const NOON_FOG := Color(0.70, 0.76, 0.84)
const DUSK_FOG := Color(0.66, 0.47, 0.50)


func setup() -> void:
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-80, 30, 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 180.0
	add_child(sun)

	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.5, 0.8)
	sky_mat.sky_horizon_color = Color(0.75, 0.8, 0.85)
	sky_mat.ground_bottom_color = Color(0.15, 0.13, 0.12)
	sky_mat.ground_horizon_color = Color(0.55, 0.52, 0.5)
	sky_mat.sun_angle_max = 20.0

	var env_res := Environment.new()
	env_res.background_mode = Environment.BG_SKY
	env_res.sky = Sky.new()
	env_res.sky.sky_material = sky_mat
	env_res.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env_res.ambient_light_energy = 1.0
	env_res.tonemap_mode = Environment.TONE_MAPPER_ACES
	env_res.tonemap_exposure = 1.0
	env_res.fog_enabled = true
	env_res.fog_light_color = NOON_FOG
	env_res.fog_density = 0.0012
	env_res.fog_sky_affect = 0.4

	env = WorldEnvironment.new()
	env.environment = env_res
	add_child(env)


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.1:
		return
	_accum = 0.0
	_apply_atmosphere()


func _apply_atmosphere() -> void:
	var h: float = Game.hour()
	var night: bool = Game.is_night()
	# sun pitch: -5 at 06:00 sweeping to -365 at next 06:00
	var pitch := -5.0 - fposmod(h - 6.0, 24.0) * 15.0
	sun.rotation_degrees = Vector3(pitch, 30.0, 0.0)

	var sun_col: Color
	var fog_col: Color
	var fog_density: float
	var ambient: float
	var sky_top: Color
	var sky_horizon: Color

	if night:
		sun_col = NIGHT_SUN
		fog_col = NIGHT_FOG
		fog_density = NIGHT_FOG_DENSITY
		ambient = 0.22
		sky_top = Color(0.03, 0.045, 0.10)
		sky_horizon = Color(0.07, 0.09, 0.16)
		sun.light_energy = 0.35
	else:
		# day arc: dawn (6) -> noon (12.5) -> dusk (19)
		if h < 12.5:
			var t: float = clampf((h - 6.0) / 6.5, 0.0, 1.0)
			sun_col = DAWN_SUN.lerp(NOON_SUN, t)
			fog_col = DAWN_FOG.lerp(NOON_FOG, t)
		else:
			var t: float = clampf((h - 12.5) / 6.5, 0.0, 1.0)
			sun_col = NOON_SUN.lerp(DUSK_SUN, t)
			fog_col = NOON_FOG.lerp(DUSK_FOG, t)
		var arc: float = clampf((h - 6.0) / 13.0, 0.0, 1.0)
		var horizonness: float = 1.0 - sin(arc * PI)  # 1 at horizon, 0 at noon
		fog_density = lerpf(0.0009, 0.0016, horizonness)
		ambient = lerpf(1.2, 0.85, horizonness)
		sun.light_energy = lerpf(1.6, 3.0, sin(arc * PI))
		sky_top = Color(0.25, 0.42, 0.75).lerp(Color(0.4, 0.6, 0.9), sin(arc * PI))
		sky_horizon = fog_col

	# weather coupling
	var vis: float = Game.visibility()
	var vis_loss: float = 1.0 - vis
	fog_density *= (1.0 + 1.8 * vis_loss)
	sun.light_energy *= (0.45 + 0.55 * vis)
	fog_col = Color(fog_col.r * 0.55 + 0.05, fog_col.g * 0.55 + 0.05, fog_col.b * 0.55 + 0.06) if vis < 0.9 else fog_col

	sun.light_color = sun_col
	sky_mat.sky_top_color = sky_top
	sky_mat.sky_horizon_color = sky_horizon
	env.environment.fog_light_color = fog_col
	env.environment.fog_density = fog_density
	env.environment.ambient_light_energy = ambient
