shader_type canvas_item;

// Static micro-surface treatment for procedural cutout geometry. The pattern is local-space, so it
// remains attached to cloth/metal while the actor moves. It preserves CanvasItem lighting instead of
// opting out with `unshaded`, allowing the existing nocturnal Light2D pass to keep doing real work.
uniform float grain_seed = 0.0;
uniform float grain_strength : hint_range(0.0, 0.18) = 0.065;
uniform float directional_relief : hint_range(0.0, 0.20) = 0.075;
uniform float edge_falloff : hint_range(0.0, 0.18) = 0.045;

varying vec2 local_coord;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + vec2(45.32 + grain_seed));
	return fract(p.x * p.y);
}

void vertex() {
	local_coord = VERTEX;
}

void fragment() {
	vec4 base = COLOR;
	vec2 cell = floor(local_coord * 0.72 + vec2(grain_seed * 7.1, grain_seed * 3.7));
	float coarse = hash21(cell) - 0.5;
	float fine = hash21(cell * 2.73 + 19.17) - 0.5;
	float weave = sin(local_coord.x * 1.38 + grain_seed) * sin(local_coord.y * 1.91 - grain_seed * 0.4);
	float relief = dot(normalize(vec2(0.82, -0.57)), normalize(local_coord + vec2(0.001))) * directional_relief;
	float grain = coarse * grain_strength + fine * grain_strength * 0.38 + weave * grain_strength * 0.19;
	float radial = smoothstep(28.0, 110.0, length(local_coord)) * edge_falloff;
	base.rgb *= clamp(1.0 + grain + relief - radial, 0.72, 1.18);
	COLOR = base;
}
