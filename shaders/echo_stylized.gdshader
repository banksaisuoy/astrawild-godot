// v1.7 Phase 2 — stylized creature material (gl_compatibility safe).
// Replaces StandardMaterial3D on procedural Tier-B bodies: fresnel RIM
// (emission-driven so it interacts with the bloom pass), a vertical
// dark->light GRADIENT (grounded feet, lifted shoulders — the ambient
// occlusion feel low-poly bodies never get), and a fake SUBSURFACE term
// (light bleeding through thin facing surfaces: ears, fins, tails).
// Silhouettes stay readable at range even before textures resolve.
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
// rim (fresnel edge kick, emission so Radiant variants bloom)
uniform float rim_strength : hint_range(0.0, 1.5) = 0.34;
uniform float rim_pow : hint_range(0.5, 8.0) = 2.6;
uniform vec4 rim_col : source_color = vec4(1.0, 0.95, 0.85, 1.0);
// fake subsurface: warm bleed on camera-facing thin parts
uniform vec4 sss_col : source_color = vec4(1.0, 0.45, 0.35, 1.0);
uniform float sss_strength : hint_range(0.0, 1.0) = 0.16;
// vertical gradient multiplier (lo at feet, hi at top)
uniform float grad_lo : hint_range(0.2, 1.0) = 0.62;
uniform float grad_hi : hint_range(1.0, 1.6) = 1.12;
uniform float body_h = 1.0;             // local height span of the body
// elemental / variant emission passthrough
uniform vec4 emit_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emit_energy : hint_range(0.0, 3.0) = 0.0;

varying float v_grad;
varying vec3 v_nrm;
varying vec3 world_pos;

void vertex() {
        v_grad = clamp(VERTEX.y / max(body_h, 0.05), 0.0, 1.0);
        v_nrm = NORMAL;
        world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
        vec4 t = texture(base_tex, UV);
        vec3 base = t.rgb * surface_col.rgb;
        // vertical gradient shading — feet settle into shadow, tops lift
        base *= mix(vec3(grad_lo), vec3(grad_hi), v_grad);
        // fake subsurface scattering on thin camera-facing surfaces
        vec3 n = normalize(v_nrm);
        vec3 v = normalize(VIEW);
        float facing = clamp(dot(n, v), 0.0, 1.0);
        base += sss_col.rgb * pow(facing, 3.0) * sss_strength;
        ALBEDO = aw_apply_fog(base, world_pos, length(VERTEX));
        // fresnel rim as EMISSION: edge light that feeds the glow pass
        float fres = pow(1.0 - facing, rim_pow);
        EMISSION = emit_col.rgb * emit_energy + rim_col.rgb * rim_strength * fres;
        ROUGHNESS = 0.85;
        SPECULAR = 0.1;
}
