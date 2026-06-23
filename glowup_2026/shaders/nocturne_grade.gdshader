shader_type canvas_item;
render_mode unshaded;

// Attach to a full-screen ColorRect below HUD/menu layers. One semantic grade prevents heat,
// humanity, frenzy, feed, and dawn overlays from clobbering or multiplying each other.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float heat : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float humanity_loss : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float frenzy : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float feeding : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float dawn_phase : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float sun_exposure : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float vignette_strength : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float max_desaturation : hint_range(0.0, 1.0, 0.01) = 0.45;
uniform bool reduced_flash = false;
uniform bool reduced_motion = false;

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 scene = texture(screen_texture, uv).rgb;
    float luma = luminance(scene);

    // Humanity loss cools and desaturates gradually instead of presenting a single opaque flash.
    float humanity_amount = clamp(humanity_loss, 0.0, 1.0);
    vec3 gray = vec3(luma);
    scene = mix(scene, gray, humanity_amount * max_desaturation);
    scene = mix(scene, scene * vec3(0.83, 0.94, 1.08), humanity_amount * 0.34);

    // Dawn warms highlights first; deep shadows remain readable blue until exposure becomes dangerous.
    float highlight = smoothstep(0.30, 0.95, luma);
    vec3 dawn_tint = vec3(1.08, 0.91, 0.70);
    scene = mix(scene, scene * dawn_tint, dawn_phase * (0.10 + 0.30 * highlight));

    vec2 centered = uv * 2.0 - 1.0;
    float radius = length(centered * vec2(0.86, 1.0));
    float edge = smoothstep(0.30, 1.15, radius);
    float motion_scale = reduced_motion ? 0.12 : 1.0;
    float temporal_scale = reduced_flash ? 0.12 : 1.0;

    float heat_pulse = 0.5 + 0.5 * sin(TIME * (2.0 + heat * 4.0));
    float heat_edge = heat * edge * (0.28 + 0.22 * heat_pulse * temporal_scale);
    scene = mix(scene, scene * vec3(1.12, 0.78, 0.72), heat_edge);

    // Frenzy adds central contrast and a controlled red edge; never erase silhouettes.
    float frenzy_pulse = 0.5 + 0.5 * sin(TIME * 5.5 * motion_scale);
    float frenzy_edge = frenzy * edge * (0.18 + 0.22 * frenzy_pulse * temporal_scale);
    scene = mix(scene, scene * vec3(1.18, 0.70, 0.76), frenzy_edge);
    scene = mix(vec3(luminance(scene)), scene, 1.0 + frenzy * 0.08);

    // Feeding subtly focuses the center and creates a cinematic frame without hard black bars.
    float feed_frame = feeding * smoothstep(0.52, 0.98, abs(centered.y));
    scene *= 1.0 - feed_frame * 0.42;
    scene = mix(scene, scene * vec3(1.07, 0.86, 0.88), feeding * edge * 0.12);

    // Sun exposure is the only channel allowed to lift toward white; reduced-flash caps temporal peak.
    float sun_peak = sun_exposure * (reduced_flash ? 0.38 : 0.68);
    scene = mix(scene, vec3(1.0, 0.82, 0.56), sun_peak * (0.18 + 0.45 * highlight));

    float vignette = vignette_strength * edge;
    vignette += heat * edge * 0.10;
    vignette += frenzy * edge * 0.08;
    vignette -= dawn_phase * 0.05;
    scene *= 1.0 - clamp(vignette, 0.0, 0.62);

    COLOR = vec4(max(scene, vec3(0.0)), 1.0);
}
