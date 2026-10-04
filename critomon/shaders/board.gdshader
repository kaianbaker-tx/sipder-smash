// The front and back of a Connect Four board: a blue plate with round holes.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 color : source_color = vec4(0.15, 0.4, 0.95, 1.0);
uniform vec2 cells = vec2(7.0, 6.0);
// the plate is a bit bigger than the grid of holes
uniform vec2 margin = vec2(0.04, 0.05);
uniform float hole = 0.36;

void fragment() {
	vec2 g = (UV - margin) / (1.0 - 2.0 * margin);
	vec3 c = color.rgb;
	if (g.x > 0.0 && g.x < 1.0 && g.y > 0.0 && g.y < 1.0) {
		vec2 cell = fract(g * cells) - 0.5;
		cell.x *= 1.0;
		float d = length(cell);
		if (d < hole) {
			discard;
		}
		// a darker ring round each hole
		c = mix(c * 0.72, c, smoothstep(hole + 0.02, hole + 0.07, d));
	}
	ALBEDO = c;
}

void light() {
	float ndl = abs(dot(NORMAL, LIGHT));
	float lit = smoothstep(0.0, 0.05, ndl) * smoothstep(0.35, 0.55, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * 0.9;
}
