// hero_rim.gdshader — an upgraded cold "wet edge" rim for the hero sprite.
//
// A drop-in superset of character_rim.gdshader, tuned for the player: instead of a flat one-colour
// outline, the hero gets a directional, wet-looking rim — cold key light skims the top-left edge of
// the silhouette (a streetlamp / moon read), warmer/darker on the shaded side, so the player figure
// reads as a materially-lit body in the rain rather than a glowing decal. Still LIT (no `unshaded`)
// so the CanvasTexture diffuse/normal/specular keep receiving the warm follow-light pools; only the
// silhouette rim is synthesised here.
//
// Wired by CharacterAtlas2D only when _atlas_key == "hero" (see _hero_rim_material). Every other actor
// keeps the cheaper shared character_rim.gdshader. Atlas cells are now 192x256 with a transparent
// margin around the figure; rim taps stay 1-2 texels out so they read as a thin wet edge and never
// bleed into the neighbouring direction/animation cell.
shader_type canvas_item;
// Generated/pre-lit atlases already carry baked cold-key/warm-rim lighting, so the sprite is shown
// UNSHADED (not re-lit by the dim night 2D lights, which would crush the painted detail to a silhouette).
render_mode unshaded;

uniform vec4 rim_cold : source_color = vec4(0.70, 0.84, 1.0, 1.0);   // key-side wet edge (moon/lamp)
uniform vec4 rim_warm : source_color = vec4(0.46, 0.40, 0.40, 1.0);  // shaded-side dim grounding edge
uniform float rim_width : hint_range(0.5, 3.0) = 1.4;
uniform float rim_intensity : hint_range(0.0, 6.0) = 4.0;
uniform float body_gain : hint_range(0.5, 2.5) = 1.85;
// Light direction the rim "catches", in UV space (default: from upper-left). Normalised in fragment.
uniform vec2 light_dir = vec2(-0.65, -0.75);
// How strongly the rim splits cold(lit)/warm(shaded) around the silhouette. 0 = flat cold rim.
uniform float directionality : hint_range(0.0, 1.0, 0.01) = 0.65;
// Extra sharpening of the rim falloff so it reads as a crisp wet highlight, not a soft glow.
uniform float rim_sharpness : hint_range(0.5, 4.0) = 1.6;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * rim_width;

	// 8-neighbour alpha gradient: coverage just outside this fragment, and the direction it grows in
	// (the outward silhouette normal, approximated from the alpha field).
	float a_r = texture(TEXTURE, UV + vec2( px.x, 0.0)).a;
	float a_l = texture(TEXTURE, UV + vec2(-px.x, 0.0)).a;
	float a_d = texture(TEXTURE, UV + vec2( 0.0,  px.y)).a;
	float a_u = texture(TEXTURE, UV + vec2( 0.0, -px.y)).a;
	float a_rd = texture(TEXTURE, UV + vec2( px.x,  px.y)).a;
	float a_ld = texture(TEXTURE, UV + vec2(-px.x,  px.y)).a;
	float a_ru = texture(TEXTURE, UV + vec2( px.x, -px.y)).a;
	float a_lu = texture(TEXTURE, UV + vec2(-px.x, -px.y)).a;

	float na = max(max(max(a_r, a_l), max(a_d, a_u)), max(max(a_rd, a_ld), max(a_ru, a_lu)));

	// Outer rim mask: outside the body (low self-alpha) yet beside it (high neighbour alpha).
	float rim = clamp(na - tex.a, 0.0, 1.0);
	rim = pow(rim, rim_sharpness);

	// Silhouette outward normal from the alpha gradient (points away from the body).
	vec2 grad = vec2((a_l - a_r), (a_u - a_d));
	vec2 normal = (length(grad) > 0.0001) ? normalize(grad) : vec2(0.0);
	float facing = clamp(dot(normal, normalize(light_dir)), 0.0, 1.0);

	// Cold where the edge faces the light, warm/dim where it faces away.
	float warm_to_cold = mix(1.0 - directionality, 1.0, facing);
	vec3 rim_rgb = mix(rim_warm.rgb, rim_cold.rgb, warm_to_cold);
	float rim_a_scale = mix(rim_warm.a, rim_cold.a, warm_to_cold);

	// Body keeps the draw-call modulate (hit-flash brighten, afterimage ghost tint, etc.).
	vec3 body = tex.rgb * body_gain * COLOR.rgb;
	vec3 rgb = body * tex.a + rim_rgb * rim_intensity * rim;
	float a = max(tex.a, rim * rim_a_scale) * COLOR.a;
	COLOR = vec4(rgb, a);
}
