// Cartoon ink lines, drawn on a quad in front of the camera.
// Finds edges and creases in the depth buffer and draws dark ink there.
// Only the lines are drawn; everything else stays see-through.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform float line_px = 1.25;
uniform float edge_depth = 0.04;
uniform float edge_crease = 0.02;
uniform float far_start = 45.0;
uniform float far_end = 110.0;
uniform vec4 ink : source_color = vec4(0.12, 0.09, 0.2, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

// 1/z is flat on flat faces, so its second difference finds creases
float inv_z(vec2 uv, mat4 ipm) {
	float d = texture(depth_tex, uv).r;
	vec4 v = ipm * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return -v.w / v.z;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float w = line_px * (VIEWPORT_SIZE.y / 720.0);
	vec2 o = px * max(w, 1.0);
	float c = inv_z(uv, INV_PROJECTION_MATRIX);
	float l = inv_z(uv - vec2(o.x, 0.0), INV_PROJECTION_MATRIX);
	float r = inv_z(uv + vec2(o.x, 0.0), INV_PROJECTION_MATRIX);
	float d = inv_z(uv - vec2(0.0, o.y), INV_PROJECTION_MATRIX);
	float u = inv_z(uv + vec2(0.0, o.y), INV_PROJECTION_MATRIX);
	float zc = 1.0 / max(c, 1e-6);
	float farthest = min(min(l, r), min(d, u));
	float sil = step(edge_depth, (c - farthest) / max(c, 1e-6));
	float lap = abs(l + r - 2.0 * c) + abs(u + d - 2.0 * c);
	float crease = smoothstep(edge_crease, edge_crease * 2.0, lap / max(c, 1e-6));
	float far_fade = 1.0 - smoothstep(far_start, far_end, zc);
	ALBEDO = ink.rgb;
	ALPHA = clamp(max(sil, crease * 0.8), 0.0, 1.0) * far_fade * ink.a;
}
