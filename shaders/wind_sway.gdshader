// v1.6 Radiant Dawn — foliage wind-sway shader (gl_compatibility safe).
// Vertex: two world-space-phased sine waves displace the mesh horizontally,
// weighted by local height (trunk rigid, canopy loose) and NORMALIZED by the
// instance's X scale so world-space sway is identical for every tree scale.
// Per-instance color jitter rides INSTANCE_CUSTOM (rgba8, 0.5 = neutral 1.0).
shader_type spatial;

uniform vec4 surface_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D base_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform float sway_world : hint_range(0.0, 0.5) = 0.08;
uniform float sway_speed : hint_range(0.2, 4.0) = 1.35;
uniform float h_lo = 0.35;
uniform float h_hi = 1.6;

varying vec3 custom_mul;

void vertex() {
        vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
        float ms = max(length(MODEL_MATRIX[0].xyz), 0.001);
        float hf = smoothstep(h_lo, h_hi, VERTEX.y);
        float ph = wp.x * 0.37 + wp.z * 0.29;
        float s1 = sin(TIME * sway_speed + ph);
        float s2 = sin(TIME * sway_speed * 1.71 + ph * 1.31 + 1.7);
        vec2 off = vec2(s1 + 0.55 * s2, 0.6 * s1 - 0.4 * s2) * sway_world * hf / ms;
        VERTEX.x += off.x;
        VERTEX.z += off.y;
        custom_mul = INSTANCE_CUSTOM.rgb * 2.0;
}

void fragment() {
        vec4 t = texture(base_tex, UV);
        ALBEDO = t.rgb * surface_col.rgb * custom_mul;
        ROUGHNESS = 0.9;
        SPECULAR = 0.12;
}
