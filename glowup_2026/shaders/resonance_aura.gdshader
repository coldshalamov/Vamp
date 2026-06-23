shader_type canvas_item;
render_mode unshaded;

// Top-down resonance read for feedable actors. The source sprite atlas needs transparent padding
// around the silhouette so the aura has room to render. Color is only one channel: pulse rhythm,
// width, and optional glyph/marker in the renderer must also identify resonance.
uniform vec4 aura_color : source_color = vec4(0.35, 0.85, 1.0, 0.85);
uniform float aura_width_px : hint_range(1.0, 10.0, 0.25) = 4.0;
uniform float aura_strength : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float pulse_speed : hint_range(0.0, 8.0, 0.05) = 2.2;
uniform float pulse_depth : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform float reveal : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float noise_scale : hint_range(1.0, 24.0, 0.5) = 7.0;
uniform float noise_amount : hint_range(0.0, 1.0, 0.01) = 0.16;
uniform float phase_offset : hint_range(0.0, 6.28318, 0.01) = 0.0;
uniform bool reduced_motion = false;
uniform sampler2D noise_texture : repeat_enable, filter_linear;

void fragment() {
    vec4 vertex_tint = COLOR;
    vec4 source = texture(TEXTURE, UV) * vertex_tint;
    vec2 px = TEXTURE_PIXEL_SIZE * aura_width_px;

    float nearby_alpha = 0.0;
    nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2( px.x, 0.0)).a);
    nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
    nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0,  px.y)).a);
    nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(0.0, -px.y)).a);
    nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2( px.x,  px.y) * 0.7071).a);
    nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-px.x,  px.y) * 0.7071).a);
    nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2( px.x, -px.y) * 0.7071).a);
    nearby_alpha = max(nearby_alpha, texture(TEXTURE, UV + vec2(-px.x, -px.y) * 0.7071).a);

    float silhouette = smoothstep(0.04, 0.55, nearby_alpha);
    float outside = silhouette * (1.0 - smoothstep(0.02, 0.35, source.a));
    float n = texture(noise_texture, fract(UV * noise_scale + vec2(TIME * 0.025, -TIME * 0.017))).r;
    float motion_scale = reduced_motion ? 0.18 : 1.0;
    float pulse = 1.0 - pulse_depth * motion_scale
        + pulse_depth * motion_scale * (0.5 + 0.5 * sin(TIME * pulse_speed + phase_offset));
    float texture_breakup = mix(1.0, 0.72 + 0.28 * n, noise_amount);
    float aura_alpha = outside * aura_color.a * aura_strength * reveal * pulse * texture_breakup;

    // Preserve the authored sprite. Aura appears only in transparent padding, avoiding color wash.
    vec3 rgb = mix(aura_color.rgb, source.rgb, source.a);
    float out_alpha = max(source.a, aura_alpha);
    rgb = mix(rgb, aura_color.rgb, aura_alpha * (1.0 - source.a));
    COLOR = vec4(rgb, out_alpha);
}
