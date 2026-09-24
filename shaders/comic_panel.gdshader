// Comic panel background for chapter cards and menus:
// radial speed burst, halftone dots and a thick ink frame.
shader_type canvas_item;

uniform vec4 col_a : source_color = vec4(0.95, 0.15, 0.45, 1.0);
uniform vec4 col_b : source_color = vec4(0.25, 0.05, 0.45, 1.0);
uniform vec4 dot_col : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform float burst = 1.0;
uniform float frame_px = 14.0;
uniform float alpha = 0.94;

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = FRAGCOORD.xy;
	vec2 c = res * 0.5;
	vec2 d = (p - c) / res.y;
	float a = atan(d.y, d.x);
	float r = length(d);
	// alternating burst rays
	float ray = step(0.5, fract(a / 6.2831853 * 28.0 + hash(floor(a * 4.5)) * 0.2));
	vec3 col = mix(col_a.rgb, col_b.rgb, smoothstep(0.1, 0.9, r));
	col = mix(col, col * 0.78, ray * burst);
	// halftone dots getting bigger toward the edges
	vec2 q = p / 14.0;
	q = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * q;
	float cov = smoothstep(0.15, 0.85, r) * 0.55;
	float dotm = 1.0 - smoothstep(sqrt(cov / 3.14159) - 0.06, sqrt(cov / 3.14159) + 0.06, length(fract(q) - 0.5));
	col = mix(col, dot_col.rgb, dotm * 0.5);
	// ink frame
	vec2 e = min(p, res - p);
	float fr = step(min(e.x, e.y), frame_px);
	col = mix(col, vec3(0.03, 0.0, 0.06), fr);
	COLOR = vec4(col, max(alpha, fr));
}
