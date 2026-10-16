// v1.7 Atmosphere — vertex-coloured terrain / vista-ring material with manual
// distance+height fog (gl_compatibility renders no engine fog). Used by the
// 12 zone terrain tiles AND the Distant Vista Ring peaks: they must fade into
// the sky together or the horizon reads as a pasted cardboard cutout.
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


varying vec3 world_pos;
varying vec4 v_color;

void vertex() {
        world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        v_color = COLOR;
}

void fragment() {
        ALBEDO = aw_apply_fog(v_color.rgb, world_pos, length(VERTEX));
        ROUGHNESS = 1.0;
        SPECULAR = 0.5;
}
