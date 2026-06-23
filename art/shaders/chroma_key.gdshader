// chroma_key.gdshader — drop a solid key-color background (e.g. the concept art's pink/magenta)
// and despill the fringe. Use on a TextureRect/Sprite for portraits or billboard art.
shader_type canvas_item;

uniform vec3 key_color : source_color = vec3(1.0, 0.0, 1.0);
uniform float threshold = 0.40;
uniform float softness = 0.14;
uniform float despill = 0.6;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(c.rgb, key_color);
	float a = smoothstep(threshold, threshold + softness, d);
	// Despill: where we're near the key, pull the chroma toward luminance so no pink rim remains.
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(vec3(luma), c.rgb, clamp(a + (1.0 - despill), 0.0, 1.0));
	COLOR = vec4(rgb, c.a * a);
}
