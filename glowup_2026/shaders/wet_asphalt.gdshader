shader_type canvas_item;

// Restrained wet-road treatment for the current 2D GL Compatibility renderer.
// This intentionally avoids screen-space reflection and expensive dynamic loops. Light2D still
// modulates the resulting CanvasItem normally. Author a broad low-frequency puddle mask in the
// noise texture; do not turn the entire street into chrome.
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform sampler2D ripple_texture : repeat_enable, filter_linear;
uniform vec4 reflection_tint : source_color = vec4(0.32, 0.48, 0.68, 1.0);
uniform vec4 warm_reflection_tint : source_color = vec4(0.95, 0.56, 0.28, 1.0);
uniform vec2 flow_direction = vec2(0.0, 1.0);
uniform float wetness : hint_range(0.0, 1.0, 0.01) = 0.75;
uniform float puddle_threshold : hint_range(0.0, 1.0, 0.01) = 0.60;
uniform float macro_scale : hint_range(0.25, 12.0, 0.05) = 2.4;
uniform float micro_scale : hint_range(2.0, 64.0, 0.5) = 18.0;
uniform float reflection_strength : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float warm_mix : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform float darkening : hint_range(0.0, 0.35, 0.01) = 0.12;
uniform float ripple_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float ripple_speed : hint_range(0.0, 3.0, 0.01) = 0.35;
uniform bool low_cost = false;
uniform bool reduced_motion = false;

float remap01(float value, float lo, float hi) {
    return clamp((value - lo) / max(0.0001, hi - lo), 0.0, 1.0);
}

void fragment() {
    vec4 vertex_tint = COLOR;
    vec4 base = texture(TEXTURE, UV) * vertex_tint;
    vec2 flow = normalize(flow_direction + vec2(0.0001, 0.0));

    float macro_noise = texture(noise_texture, UV * macro_scale).r;
    float puddle = smoothstep(puddle_threshold, 1.0, macro_noise) * wetness;

    float lane = 0.5 + 0.5 * sin(dot(UV, flow) * 90.0 + macro_noise * 6.28318);
    float broken_lane = smoothstep(0.62, 0.95, lane);
    float micro = texture(noise_texture, UV * micro_scale + vec2(0.37, 0.13)).g;
    float streak = broken_lane * (0.55 + 0.45 * micro);

    float motion_scale = reduced_motion ? 0.15 : 1.0;
    float ripple = 0.0;
    if (!low_cost && ripple_strength > 0.0) {
        vec2 ripple_uv = UV * 4.0 + flow * TIME * ripple_speed * motion_scale;
        ripple = texture(ripple_texture, ripple_uv).r * ripple_strength * puddle;
    }

    // Wet film darkens diffuse response modestly, while broad streaks provide the readable sheen.
    vec3 wet_base = base.rgb * (1.0 - darkening * wetness * (0.45 + 0.55 * puddle));
    vec3 reflected = mix(reflection_tint.rgb, warm_reflection_tint.rgb, warm_mix);
    float sheen = puddle * reflection_strength * (0.18 + 0.82 * streak);
    sheen += ripple * 0.28;

    // Preserve local texture variation. Highlight lift is deliberately bounded for night readability.
    vec3 final_rgb = wet_base + reflected * sheen;
    final_rgb += vec3(0.035) * wetness * micro * (0.25 + 0.75 * puddle);
    COLOR = vec4(final_rgb, base.a);
}
