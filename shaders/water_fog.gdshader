// v1.7 Atmosphere — water plane with manual fog. The sea extends past the
// playfield edge (3400x2600 vs 3200x2400 terrain); without fog it painted a
// hard bright cyan band between the terrain cut and the vista ring.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;


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


uniform vec4 water_col : source_color = vec4(0.16, 0.38, 0.52, 0.72);
uniform float water_roughness : hint_range(0.05, 1.0) = 0.3;

varying vec3 world_pos;

void vertex() {
        world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
        ALBEDO = aw_apply_fog(water_col.rgb, world_pos, length(VERTEX));
        ALPHA = water_col.a;
        ROUGHNESS = water_roughness;
        SPECULAR = 0.5;
}
