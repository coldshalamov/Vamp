// character_rim.gdshader — a bright silhouette rim so dark actors pop from the dark ground.
//
// The night runs under a CanvasModulate ambient (~0.22), so an actor standing outside a light
// pool reads as a near-black blob against near-black asphalt (the #1 readability complaint).
// This canvas_item shader draws a 1-2px cold-moon rim around every actor's silhouette by
// alpha-edge detection on the atlas diffuse: a fragment that is OUTSIDE the body (low self-alpha)
// but ADJACENT to it (a neighbour texel is opaque) gets painted with rim_color. The rim is pushed
// well above 1.0 so it survives the ambient multiply and stays legible in shadow — like Hades /
// Dead Cells, where characters are always readable against any background.
//
// Left in LIT mode (no `unshaded`) so the body still receives the warm streetlamp / follow-light
// pools — only the rim is boosted. The CanvasTexture's normal/specular still drive body shading.
// One shared ShaderMaterial is assigned to every CharacterAtlas2D node (no per-actor material).
//
// Atlas note: rim taps sample 1-2 texels out. Cells are 96x128 with the character centred inside a
// ~20px transparent margin, so the taps never cross into the neighbouring direction/animation cell.
shader_type canvas_item;

uniform vec4 rim_color : source_color = vec4(0.74, 0.83, 1.0, 1.0);
uniform float rim_width : hint_range(0.5, 3.0) = 1.4;
uniform float rim_intensity : hint_range(0.0, 6.0) = 4.4;
uniform float body_gain : hint_range(0.5, 2.0) = 1.28;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * rim_width;

	// Max alpha of the 8 neighbours: how "covered" the area just around this fragment is.
	float na = 0.0;
	na = max(na, texture(TEXTURE, UV + vec2( px.x, 0.0)).a);
	na = max(na, texture(TEXTURE, UV + vec2(-px.x, 0.0)).a);
	na = max(na, texture(TEXTURE, UV + vec2( 0.0,  px.y)).a);
	na = max(na, texture(TEXTURE, UV + vec2( 0.0, -px.y)).a);
	na = max(na, texture(TEXTURE, UV + vec2( px.x,  px.y)).a);
	na = max(na, texture(TEXTURE, UV + vec2(-px.x,  px.y)).a);
	na = max(na, texture(TEXTURE, UV + vec2( px.x, -px.y)).a);
	na = max(na, texture(TEXTURE, UV + vec2(-px.x, -px.y)).a);

	// Outer rim: outside the silhouette (low self-alpha) yet beside it (high neighbour alpha).
	float rim = clamp(na - tex.a, 0.0, 1.0);

	// Body keeps the draw-call modulate (civilian tints, afterimage ghosts, hit-flash brighten).
	vec3 body = tex.rgb * body_gain * COLOR.rgb;
	vec3 rgb = body * tex.a + rim_color.rgb * rim_intensity * rim;
	float a = max(tex.a, rim * rim_color.a) * COLOR.a;
	COLOR = vec4(rgb, a);
}
