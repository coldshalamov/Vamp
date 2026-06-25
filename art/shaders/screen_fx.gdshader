shader_type canvas_item;
render_mode unshaded;

// screen_fx — event-driven damage feedback grade, composited ABOVE NocturneGrade (layer 3 over 2).
//
// Attach to a full-screen ColorRect (driven by ScreenFX.gd). One opaque pass that ALWAYS samples
// the scene once; the red damage vignette and the constant framing vignette ride on that single
// tap via uniform-driven radial math (no extra screen reads). A brief crit chromatic aberration is
// the ONLY path that adds taps — and only while its uniform is non-zero, so the idle case stays a
// single-tap pass-through. The uniform branch is the same for every fragment, so GL Compatibility
// keeps it cheap (no divergence).
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// Red edge pulse on taking damage (0 = none). Decayed by the script over ~0.5s.
uniform float damage : hint_range(0.0, 1.0, 0.01) = 0.0;
// RGB-split intensity for crit hits (0 = pass-through). Decayed by the script over ~0.15s.
uniform float aberration : hint_range(0.0, 1.0, 0.01) = 0.0;
// Always-on subtle edge darkening for framing.
uniform float framing_vignette : hint_range(0.0, 1.0, 0.01) = 0.16;
// Max channel offset for the crit split, in UV space (kept to a few pixels' worth).
uniform float aberration_scale : hint_range(0.0, 0.05, 0.001) = 0.012;

void fragment() {
    vec2 uv = SCREEN_UV;
    // Aspect-corrected radial coords — matches NocturneGrade so the vignettes align with the grade
    // already running underneath.
    vec2 centered = uv * 2.0 - 1.0;
    float radius = length(centered * vec2(0.86, 1.0));
    float edge = smoothstep(0.30, 1.15, radius);

    vec3 scene;
    if (aberration > 0.001) {
        // Crit RGB-split: shift channels radially outward, weighted toward the screen edge so the
        // centre stays crisp. Three taps, only while the crit timer is live.
        vec2 dir = centered * (aberration * aberration_scale * (0.35 + 0.65 * edge));
        float r = texture(screen_texture, uv + dir).r;
        float g = texture(screen_texture, uv).g;
        float b = texture(screen_texture, uv - dir).b;
        scene = vec3(r, g, b);
    } else {
        // Idle: a single pass-through tap.
        scene = texture(screen_texture, uv).rgb;
    }

    // Red damage vignette — multiplicative edge reddening + darkening, uniform-driven, no extra tap.
    float dmg_edge = clamp(damage, 0.0, 1.0) * edge;
    scene = mix(scene, scene * vec3(1.25, 0.32, 0.30), dmg_edge * 0.85);
    scene *= 1.0 - dmg_edge * 0.30;

    // Constant subtle framing vignette.
    scene *= 1.0 - clamp(framing_vignette * edge, 0.0, 0.5);

    COLOR = vec4(max(scene, vec3(0.0)), 1.0);
}
