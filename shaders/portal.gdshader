// The Glitch Portal: a swirling rip in the multiverse. Faces the camera.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

global uniform float world_time;
global uniform float noir;
uniform float power = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	// face the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz), INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz), INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float swirl = sin(a * 5.0 + r * 14.0 - world_time * 3.0);
	float swirl2 = sin(a * 3.0 - r * 9.0 + world_time * 2.0);
	vec3 c = mix(vec3(0.0, 0.95, 1.0), vec3(1.0, 0.12, 0.7), 0.5 + 0.5 * swirl);
	c = mix(c, vec3(1.0, 0.9, 0.2), step(0.8, swirl2) * 0.7);
	c = mix(c, vec3(0.04, 0.0, 0.08), smoothstep(0.35, 0.0, r));
	// glitch blocks around the rim
	vec2 bq = floor(q * 7.0 + floor(world_time * 9.0));
	float blocks = step(0.78, hash(bq)) * smoothstep(1.0, 0.75, r) * smoothstep(0.55, 0.8, r);
	c = mix(c, vec3(hash(bq + 1.0), 0.3, 1.0), blocks);
	// ink rim
	float rim = smoothstep(0.93, 0.95, r) * (1.0 - smoothstep(0.98, 1.0, r));
	c = mix(c, vec3(0.04, 0.0, 0.08), rim);
	float alpha = (1.0 - smoothstep(0.97, 1.0, r)) * power;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(smoothstep(0.08, 0.7, lum)), noir);
	ALBEDO = c;
	ALPHA = alpha;
}
