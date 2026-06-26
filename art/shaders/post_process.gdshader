shader_type canvas_item;
render_mode unshaded;

// post_process.gdshader — the final filmic master pass for the gameplay view.
//
// This is the LAST screen-space grade before the UI. Layer order (see GameRenderer.gd):
//   AtmosphereLayer(1) -> NocturneGrade(2) -> ScreenFX(3) -> *PostProcess(4)* -> DeathScreen(60)
//   -> HUD(100) -> DebugOverlay(128).
// It composites the already-lit, already-mood-graded, already-damage-graded world frame and applies
// the *cinematic master*: ACES filmic tonemap, a restrained lift/gamma/gain + split-tone colour grade,
// a subtle TIME-based film grain, an optional FXAA edge pass, and a near-zero framing vignette. It runs
// UNDER all UI layers (death overlay, HUD, debug) so it never tonemaps text or grain the interface.
//
// GL Compatibility / Intel iGPU notes (this whole pass is gated off in safe mode, see PostProcess.gd):
//   * screen_texture is an sRGB-encoded LDR back-buffer, NOT linear scene-referred HDR (there is no
//     HDR-2D on GL Compat). ACES assumes LINEAR input, so we DECODE sRGB -> linear, tonemap, then
//     RE-ENCODE. Applying ACES straight to the sRGB buffer is exactly how you crush the midtones and
//     turn the whole night to mud — the look the art target explicitly rejects. tonemap_strength stays
//     low and we mix back toward the untouched frame.
//   * NocturneGrade(0.28) and ScreenFX both already lay down a vignette. This pass's vignette default
//     is near-zero so the corners don't stack into black.
//   * FXAA adds neighbour taps; it lives behind a uniform branch (aa_strength > 0) so the idle path is
//     a single screen read. Uniform branches don't diverge per-fragment on GL Compat (cheap).
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// --- Master tonemap ----------------------------------------------------------------------------
// 0 = original frame, 1 = full ACES. Default subtle: filmic shoulder/toe without going muddy.
uniform float tonemap_strength : hint_range(0.0, 1.0, 0.01) = 0.32;
// Pre-tonemap exposure multiply in linear space. Slightly above 1.0 reclaims the toe ACES eats.
uniform float exposure : hint_range(0.4, 2.5, 0.01) = 1.28;

// --- Lift / Gamma / Gain (ASC-CDL-ish) ---------------------------------------------------------
// lift  = additive shadow offset (rgb), keep tiny.   gamma = power midtone bend (1 = neutral).
// gain  = multiplicative highlight scale (rgb).      All applied in linear space, restrained.
uniform vec3 grade_lift : source_color = vec3(0.00, 0.00, 0.005);
uniform float grade_gamma : hint_range(0.6, 1.6, 0.01) = 0.98;
uniform vec3 grade_gain : source_color = vec3(1.02, 1.0, 0.99);
uniform float saturation : hint_range(0.0, 1.6, 0.01) = 1.04;
uniform float contrast : hint_range(0.5, 1.6, 0.01) = 1.05;

// --- Split tone (the VtM gritty-urban cue): teal-ish cold shadows, restrained amber highlights ----
uniform vec4 shadow_tint : source_color = vec4(0.62, 0.80, 0.94, 1.0);   // cold/teal
uniform vec4 highlight_tint : source_color = vec4(1.04, 0.93, 0.78, 1.0); // warm/amber
uniform float split_strength : hint_range(0.0, 1.0, 0.01) = 0.16;

// --- Film grain --------------------------------------------------------------------------------
uniform float grain_strength : hint_range(0.0, 0.2, 0.001) = 0.035;
// Grain is heavier in shadow, near-zero in highlights (matches real film / sensor noise).
uniform float grain_shadow_bias : hint_range(0.0, 1.0, 0.01) = 0.7;

// --- Edge AA (FXAA-lite) -----------------------------------------------------------------------
// 0 = off (single tap). Subtle smoothing of the rotoscoped sprite edges against the dark city.
uniform float aa_strength : hint_range(0.0, 1.0, 0.01) = 0.0;

// --- Framing vignette (kept near-zero; NocturneGrade + ScreenFX already vignette) ---------------
uniform float vignette_strength : hint_range(0.0, 0.6, 0.01) = 0.05;

// Accessibility: let the host dampen the temporal grain like the other graded passes do.
uniform bool reduced_flash = false;


float luminance(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

// sRGB <-> linear. The back-buffer is sRGB LDR; ACES/grade math must run in linear.
vec3 srgb_to_linear(vec3 c) {
    return mix(c / 12.92, pow((c + vec3(0.055)) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}
vec3 linear_to_srgb(vec3 c) {
    c = clamp(c, vec3(0.0), vec3(1.0));
    return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - vec3(0.055), step(vec3(0.0031308), c));
}

// Narkowicz 2015 ACES filmic approximation (linear in -> tonemapped linear out).
vec3 aces_filmic(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), vec3(0.0), vec3(1.0));
}

// Cheap hash for the per-pixel, per-frame grain (no texture lookup).
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void fragment() {
    vec2 uv = SCREEN_UV;

    // --- FXAA-lite edge resolve (uniform branch: idle path is one tap) --------------------------
    vec3 scene_srgb;
    if (aa_strength > 0.001) {
        vec2 px = SCREEN_PIXEL_SIZE;
        vec3 c  = texture(screen_texture, uv).rgb;
        vec3 nw = texture(screen_texture, uv + vec2(-px.x, -px.y)).rgb;
        vec3 ne = texture(screen_texture, uv + vec2( px.x, -px.y)).rgb;
        vec3 sw = texture(screen_texture, uv + vec2(-px.x,  px.y)).rgb;
        vec3 se = texture(screen_texture, uv + vec2( px.x,  px.y)).rgb;
        float lc  = luminance(c);
        float lnw = luminance(nw);
        float lne = luminance(ne);
        float lsw = luminance(sw);
        float lse = luminance(se);
        float lmin = min(lc, min(min(lnw, lne), min(lsw, lse)));
        float lmax = max(lc, max(max(lnw, lne), max(lsw, lse)));
        // Edge amount: high where local luma contrast is high -> blend the corner average there.
        float edge = clamp((lmax - lmin) * 2.0, 0.0, 1.0) * aa_strength;
        vec3 blur = (nw + ne + sw + se) * 0.25;
        scene_srgb = mix(c, blur, edge);
    } else {
        scene_srgb = texture(screen_texture, uv).rgb;
    }

    // --- Work in linear space for tonemap + grade -----------------------------------------------
    vec3 lin = srgb_to_linear(scene_srgb) * exposure;

    // ACES filmic, mixed back toward the original so it stays gritty/filmic, never crushed.
    vec3 tm = aces_filmic(lin);
    lin = mix(lin, tm, tonemap_strength);

    // Lift / gamma / gain.
    lin = lin + grade_lift;
    lin = max(lin, vec3(0.0));
    lin = pow(lin, vec3(grade_gamma));
    lin = lin * grade_gain;

    // Split tone: cold shadows, amber highlights, weighted by luma. Restrained.
    float l = clamp(luminance(lin), 0.0, 1.0);
    vec3 split = mix(shadow_tint.rgb, highlight_tint.rgb, smoothstep(0.0, 1.0, l));
    lin = mix(lin, lin * split, split_strength);

    // Saturation + contrast around mid-grey (linear).
    vec3 grey = vec3(luminance(lin));
    lin = mix(grey, lin, saturation);
    lin = mix(vec3(0.18), lin, contrast);

    // --- Back to sRGB for grain + vignette + output ---------------------------------------------
    vec3 col = linear_to_srgb(max(lin, vec3(0.0)));

    // Film grain: per-pixel temporal noise, biased into the shadows. Cheap hash, no texture.
    float grain_amt = grain_strength * (reduced_flash ? 0.35 : 1.0);
    if (grain_amt > 0.0001) {
        float n = hash21(uv * vec2(1920.0, 1080.0) + fract(TIME) * 311.7) - 0.5;
        float shadow_w = mix(1.0, 1.0 - smoothstep(0.0, 0.6, luminance(col)), grain_shadow_bias);
        col += n * grain_amt * (0.4 + 0.6 * shadow_w);
    }

    // Near-zero framing vignette (NocturneGrade + ScreenFX carry the main one).
    vec2 centered = uv * 2.0 - 1.0;
    float radius = length(centered * vec2(0.86, 1.0));
    float edge = smoothstep(0.30, 1.15, radius);
    col *= 1.0 - clamp(vignette_strength * edge, 0.0, 0.5);

    COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
