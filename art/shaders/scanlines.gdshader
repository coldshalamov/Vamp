// scanlines.gdshader — surveillance/CRT atmosphere overlay. Put on a full-rect ColorRect above
// the menu/HUD: faint horizontal scanlines, edge vignette, and a slow travelling scan-sweep band.
shader_type canvas_item;

uniform float scan_strength = 0.07;
uniform float vignette_strength = 0.55;
uniform float sweep_speed = 0.08;
uniform float line_count = 360.0;

void fragment() {
	vec2 uv = UV;
	// Horizontal scanlines.
	float scan = sin(uv.y * line_count * 6.2831853) * 0.5 + 0.5;
	float scan_dark = (1.0 - scan) * scan_strength;
	// Edge vignette.
	float d = distance(uv, vec2(0.5));
	float vig = (1.0 - smoothstep(0.30, 0.85, d)) ;
	float vig_dark = (1.0 - vig) * vignette_strength;
	// Slow travelling scan-sweep highlight (very subtle).
	float band = fract(uv.y - TIME * sweep_speed);
	float sweep = smoothstep(0.0, 0.04, band) * (1.0 - smoothstep(0.04, 0.10, band));
	float a = clamp(scan_dark + vig_dark, 0.0, 1.0);
	// Composite: mostly darkening, with a faint cyan sweep line.
	vec3 tint = vec3(0.0);
	vec3 sweep_col = vec3(0.25, 0.7, 0.78) * sweep * 0.12;
	COLOR = vec4(tint + sweep_col, a + sweep * 0.06);
}
