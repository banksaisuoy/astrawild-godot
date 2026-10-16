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
const NIGHT_FOG_DENSITY := 0.0008
const DAWN_SUN := Color(1.0, 0.72, 0.45)
const NOON_SUN := Color(1.0, 0.98, 0.92)
const DUSK_SUN := Color(1.0, 0.62, 0.42)
# v1.2 V11-d: deeper fog colors (was 0.88/0.70/0.55 etc.) — kills the
# washed-out white void look; saturation over brightness, air still reads.
const DAWN_FOG := Color(0.72, 0.54, 0.42)
const NOON_FOG := Color(0.56, 0.65, 0.76)
const DUSK_FOG := Color(0.52, 0.36, 0.40)


func setup() -> void:
        sun = DirectionalLight3D.new()
        sun.rotation_degrees = Vector3(-80, 30, 0)
        sun.shadow_enabled = true
        sun.shadow_bias = 0.03
        # v1.6 Radiant Dawn: blur 1.0 -> 2.2 — soft penumbra contact shadows
        # instead of razor-stamped silhouettes; reads "lit by a real sun".
        sun.shadow_blur = 1.7
        sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
        sun.directional_shadow_blend_splits = true
        sun.directional_shadow_max_distance = 240.0
        add_child(sun)

        sky_mat = ProceduralSkyMaterial.new()
        # v1.6 Radiant Dawn: richer, more saturated sky ramp — the old washed
        # pastel ramp was a top-3 VLM critique ("depressing desaturated grey-blue")
        sky_mat.sky_top_color = Color(0.30, 0.48, 0.78)
        sky_mat.sky_horizon_color = Color(0.78, 0.82, 0.85)
        sky_mat.ground_bottom_color = Color(0.15, 0.13, 0.12)
        sky_mat.ground_horizon_color = Color(0.55, 0.52, 0.5)
        sky_mat.sun_angle_max = 13.0

        var env_res := Environment.new()
        env_res.background_mode = Environment.BG_SKY
        env_res.sky = Sky.new()
        env_res.sky.sky_material = sky_mat
        env_res.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
        env_res.ambient_light_energy = 0.68
        env_res.tonemap_mode = Environment.TONE_MAPPER_ACES
        env_res.tonemap_exposure = 0.95
        # v1.7 Phase 1: ACES white point — warmer highlights roll off to white
        # instead of clipping pink, completes the stylized colour grade.
        env_res.tonemap_white = 6.0
        env_res.fog_enabled = true
        env_res.fog_light_color = NOON_FOG
        env_res.fog_density = 0.0007
        env_res.fog_sky_affect = 0.28
        # v1.7 Phase 1: HEIGHT FOG — the missing vertical half of the atmosphere.
        # Fog plane sits just above the valley floor so morning mist pools in
        # low ground and peaks rise out of it; density is driven per world-hour
        # in _apply_atmosphere (dawn mist thickest, noon thinnest).
        env_res.fog_height = 6.0
        env_res.fog_height_density = 0.15
        # v1.6 Radiant Dawn — color grade pass (VLM critique: "flat, washed out,
        # lifeless; pure default RGB primaries"). Saturation + contrast push
        # the whole frame off the MS Paint read while ACES keeps highlights.
        env_res.adjustment_enabled = true
        env_res.adjustment_saturation = 1.34
        env_res.adjustment_contrast = 1.11
        env_res.adjustment_brightness = 1.0
        # v1.6 Radiant Dawn — glow pass: emissive eyes / astraite nodes / glow
        # reeds / campfires finally bloom. Threshold 1.05 keeps only true
        # emissives hot; SOFTLIGHT blend stays stylized-soft, never HDR soup.
        env_res.glow_enabled = true
        env_res.glow_intensity = 0.5
        env_res.glow_strength = 1.03
        env_res.glow_bloom = 0.04
        env_res.glow_hdr_threshold = 1.12
        env_res.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

        env = WorldEnvironment.new()
        env.environment = env_res
        add_child(env)
        # v1.7 Atmosphere: the compat renderer draws NO engine fog — every
        # fogged shader (terrain / vista / water / foliage / creatures) reads
        # these GLOBALS instead; _apply_atmosphere retunes them per hour,
        # weather and zone identity. Registration is programmatic (the
        # project.godot [shader_globals] section is editor-serialised).
        if RenderingServer.global_shader_parameter_get("aw_fog_density") == null:
                RenderingServer.global_shader_parameter_add("aw_fog_color", RenderingServer.GLOBAL_VAR_TYPE_COLOR, NOON_FOG)
                RenderingServer.global_shader_parameter_add("aw_fog_density", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.0007)
                RenderingServer.global_shader_parameter_add("aw_fog_height", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 6.0)
                RenderingServer.global_shader_parameter_add("aw_fog_height_density", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 0.15)
        RenderingServer.global_shader_parameter_set("aw_fog_color", NOON_FOG)
        RenderingServer.global_shader_parameter_set("aw_fog_density", 0.0007)
        RenderingServer.global_shader_parameter_set("aw_fog_height", 6.0)
        RenderingServer.global_shader_parameter_set("aw_fog_height_density", 0.15)


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
        var fog_height_density: float
        var ambient: float
        var sky_top: Color
        var sky_horizon: Color

        if night:
                sun_col = NIGHT_SUN
                fog_col = NIGHT_FOG
                fog_density = NIGHT_FOG_DENSITY
                fog_height_density = 0.30
                ambient = 0.16
                sky_top = Color(0.03, 0.045, 0.10)
                sky_horizon = Color(0.07, 0.09, 0.16)
                sun.light_energy = 0.22
        else:
                # day arc: dawn (6) -> noon (12.5) -> dusk (19)
                if h < 12.5:
                        var t: float = clampf((h - 6.0) / 6.5, 0.0, 1.0)
                        sun_col = DAWN_SUN.lerp(NOON_SUN, t)
                        fog_col = DAWN_FOG.lerp(NOON_FOG, t)
                        # morning mist pools in the valleys then burns off
                        fog_height_density = lerpf(0.42, 0.08, t)
                else:
                        var t: float = clampf((h - 12.5) / 6.5, 0.0, 1.0)
                        sun_col = NOON_SUN.lerp(DUSK_SUN, t)
                        fog_col = NOON_FOG.lerp(DUSK_FOG, t)
                        fog_height_density = lerpf(0.08, 0.25, t)
                var arc: float = clampf((h - 6.0) / 13.0, 0.0, 1.0)
                var horizonness: float = 1.0 - sin(arc * PI)  # 1 at horizon, 0 at noon
                fog_density = lerpf(0.0006, 0.0011, horizonness)
                # v1.3 gallery pass: sun 1.7→1.15 / ambient 0.72→0.5 (was
                # 1.3→2.2 / 1.05→0.8) — the old stack blew green terrain out to
                # pure white under the tonemap; now the ground keeps its hue and
                # hills keep their shaded relief
                # v1.6: +0.04 ambient offsets the saturation/contrast darkening
                ambient = lerpf(0.49, 0.34, horizonness)
                sun.light_energy = lerpf(0.94, 0.62, horizonness)
                sky_top = Color(0.20, 0.44, 0.82).lerp(Color(0.36, 0.60, 0.92), sin(arc * PI))
                sky_horizon = fog_col

        # weather coupling
        var vis: float = Game.visibility()
        var vis_loss: float = 1.0 - vis
        fog_density *= (1.0 + 1.8 * vis_loss)
        fog_height_density *= (1.0 + 1.1 * vis_loss)
        sun.light_energy *= (0.45 + 0.55 * vis)
        fog_col = Color(fog_col.r * 0.55 + 0.05, fog_col.g * 0.55 + 0.05, fog_col.b * 0.55 + 0.06) if vis < 0.9 else fog_col

        # ---- v1.1 Phase V6 zone identity grade ----
        # blend fog + sky horizon toward the player's zone identity (partition-of-unity
        # weights over the zone grid, so transitions are smooth and save-safe).
        var zone_tint: Color = Color.TRANSPARENT
        var zone_sky: Color = Color.TRANSPARENT
        var player := get_tree().get_first_node_in_group("player")
        if player:
                var weights: Dictionary = ZoneTerrain.zone_weights(player.global_position.x, player.global_position.z)
                for zid in weights:
                        var zone: Dictionary = Data.zone(zid)
                        var ident: Dictionary = zone.get("identity", {})
                        if ident.is_empty():
                                continue
                        var w: float = weights[zid]
                        var fc: Array = ident.get("fog", [1, 1, 1])
                        var sc: Array = ident.get("sky", [1, 1, 1])
                        var fog_add := Color(fc[0], fc[1], fc[2]) * w
                        var sky_add := Color(sc[0], sc[1], sc[2]) * w
                        if zone_tint == Color.TRANSPARENT:
                                zone_tint = fog_add
                                zone_sky = sky_add
                        else:
                                zone_tint += fog_add
                                zone_sky += sky_add
        if zone_tint != Color.TRANSPARENT:
                fog_col = fog_col.lerp(zone_tint, 0.45)
                sky_horizon = sky_horizon.lerp(zone_sky, 0.4)
                sky_top = sky_top.lerp(zone_sky, 0.18)

        sun.light_color = sun_col
        sky_mat.sky_top_color = sky_top
        sky_mat.sky_horizon_color = sky_horizon
        env.environment.fog_light_color = fog_col
        env.environment.fog_density = fog_density
        env.environment.fog_height_density = fog_height_density
        env.environment.ambient_light_energy = ambient
        # v1.7 Atmosphere: push the real fog into the global uniforms the
        # custom shaders read (compat renderer ignores the env values above).
        RenderingServer.global_shader_parameter_set("aw_fog_color", fog_col)
        RenderingServer.global_shader_parameter_set("aw_fog_density", fog_density)
        RenderingServer.global_shader_parameter_set("aw_fog_height", env.environment.fog_height)
        RenderingServer.global_shader_parameter_set("aw_fog_height_density", fog_height_density)
        # v1.7 Phase 1: let the sky fog eat more of the horizon band at dawn /
        # dusk so the Distant Vista Ring melts into the sky instead of pasting
        # a hard silhouette line against it (noon stays crisper).
        if night:
                env.environment.fog_sky_affect = 0.34
        else:
                var arc2: float = clampf((h - 6.0) / 13.0, 0.0, 1.0)
                env.environment.fog_sky_affect = lerpf(0.40, 0.24, sin(arc2 * PI))
                env.environment.fog_sky_affect *= (1.0 + 0.5 * vis_loss)
