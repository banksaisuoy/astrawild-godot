// v1.7 Phase 3 — stamina ring under the player's feet (gl_compatibility safe).
// A flat quad carries a soft-edged annulus (r 0.55–0.75 of the quad) that
// fills as an ARC clockwise from 12 o'clock by `fill_frac`; the colour leans
// light green while healthy and shifts yellow as stamina runs out. A faint
// ghost track keeps the full circle readable while draining. Unshaded, no
// shadows, no billboard — it simply lies on the ground plane.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float fill_frac : hint_range(0.0, 1.0) = 1.0;

void fragment() {
        vec2 p = UV - vec2(0.5);
        float r = length(p) * 2.0;                 // 0 centre → 1 mid-edge
        float ang = atan(p.x, -p.y);               // 0 at 12 o'clock, clockwise
        float t = fract(ang / TAU + 1.0);          // 0..1 once around the ring
        // soft-edged annulus mask (0.55–0.75 of the quad)
        float ring = smoothstep(0.52, 0.565, r) * (1.0 - smoothstep(0.735, 0.78, r));
        // arc fill with a softly feathered leading edge
        float filled = 1.0 - smoothstep(fill_frac - 0.03, fill_frac + 0.03, t);
        // green when healthy → yellow when running low
        vec3 col = mix(vec3(0.98, 0.9, 0.38), vec3(0.62, 0.95, 0.62),
                        smoothstep(0.15, 0.55, fill_frac));
        // ghost track (0.16) so the whole circle reads even while draining
        float alpha = ring * max(filled * 0.85, 0.16);
        ALBEDO = col;
        ALPHA = alpha;
}
