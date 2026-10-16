// v1.7 Horizon & Atmosphere — weather-coupled foliage wind shader
// (gl_compatibility safe). Evolves v1.6 wind_sway: same world-phased twin
// sine displacement + per-instance tint (INSTANCE_CUSTOM, 0.5 = neutral 1.0),
// now driven by a prevailing wind DIRECTION and a global wind_strength the
// world updates from the 8 weather states (Clear 0.55 … Storm 1.9), plus a
// slow gust envelope so storms don't read as uniform shaking.
shader_type spatial;


// ---- v1.7 Atmosphere: manual distance+height fog (compat renderer draws no
// ---- engine fog; the day/night cycle drives these globals per hour/weather)
global uniform vec4 aw_fog_color : source_color;
global uniform float aw_fog_density;
global uniform float aw_fog_height;
global uniform float aw_fog_height_density;

vec3 aw_apply_fog(vec3 albedo, vec3 world_pos, float eye_depth) {
        // aerial perspective: pure distance fog — mountains at 2 km melt into
        // the sky regardless of their height.
        float d = aw_fog_density * eye_depth;
        float fog_amt = 1.0 - exp(-d * d);
        // valley mist: EXTRA fog below the mist plane, ramping to zero AT the
        // plane (35 m band) — morning mist pools in low ground, never strips
        // fog off distant peaks like an exp-decay height term would.
        float band = clamp((aw_fog_height - world_pos.y) / 35.0, 0.0, 1.0);
        fog_amt = fog_amt + aw_fog_height_density * band * (1.0 - fog_amt);
        return mix(albedo, aw_fog_color.rgb, clamp(fog_amt, 0.0, 1.0));
}


uniform vec4 surface_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D base_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform float sway_world : hint_range(0.0, 0.5) = 0.08;
uniform float sway_speed : hint_range(0.2, 4.0) = 1.35;
uniform float h_lo = 0.35;
uniform float h_hi = 1.6;
// v1.7: weather coupling — world.gd pushes these onto every cached wind
// material when Game.weather_changed fires (and once at build time).
uniform float wind_strength : hint_range(0.0, 3.0) = 1.0;
uniform vec2 wind_dir = vec2(0.8, 0.6);

varying vec3 custom_mul;
varying vec3 world_pos;

void vertex() {
        vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        float ms = max(length(MODEL_MATRIX[0].xyz), 0.001);
        float hf = smoothstep(h_lo, h_hi, VERTEX.y);
        float ph = wp.x * 0.37 + wp.z * 0.29;
        float s1 = sin(TIME * sway_speed + ph);
        float s2 = sin(TIME * sway_speed * 1.71 + ph * 1.31 + 1.7);
        // slow gust envelope (period ~12 s) — gusts sweep across the world
        float gust = 0.72 + 0.28 * sin(TIME * 0.53 + wp.x * 0.013 + wp.z * 0.011);
        vec2 dir_n = normalize(wind_dir);
        vec2 side_n = vec2(-dir_n.y, dir_n.x);
        // v1.6 wave character rotated into the prevailing direction and scaled
        // by weather strength + gust — calm heatwaves barely whisper, storms
        // visibly heave whole canopies.
        vec2 off = (dir_n * (s1 + 0.55 * s2) + side_n * (0.6 * s1 - 0.4 * s2) * 0.45)
                * sway_world * hf * wind_strength * gust / ms;
        VERTEX.x += off.x;
        VERTEX.z += off.y;
        world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        custom_mul = INSTANCE_CUSTOM.rgb * 2.0;
}

void fragment() {
        vec4 t = texture(base_tex, UV);
        vec3 base = t.rgb * surface_col.rgb * custom_mul;
        ALBEDO = aw_apply_fog(base, world_pos, length(VERTEX));
        ROUGHNESS = 0.9;
        SPECULAR = 0.12;
}
