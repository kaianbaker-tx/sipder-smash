// Comic ink lines, drawn on a quad in front of the camera.
// Finds silhouettes and creases in the depth buffer and draws black ink
// there. Only the lines are drawn (the rest stays see-through), so glowing
// and transparent things behind it still show. The colour effects live in
// screen_fx.gdshader, a 2D pass over the finished picture.
shader_type spatial;
render_mode unshaded, blend_mix, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform float line_px = 1.4;
uniform float edge_depth = 0.035;
uniform float edge_crease = 0.012;
uniform vec4 ink : source_color = vec4(0.06, 0.02, 0.1, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

// inverse linear depth (1/z) is affine in screen space for flat faces,
// so its Laplacian is zero on a plane and big on a crease.
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
	// silhouettes: we are the near side of a big depth jump
	float farthest = min(min(l, r), min(d, u));
	float sil = step(edge_depth, (c - farthest) / max(c, 1e-6));
	// creases: second difference of 1/z
	float lap = abs(l + r - 2.0 * c) + abs(u + d - 2.0 * c);
	float crease = smoothstep(edge_crease, edge_crease * 2.0, lap / max(c, 1e-6));
	// fade lines out in the far haze so the skyline stays soft
	float far_fade = 1.0 - smoothstep(260.0, 520.0, zc);
	float edge = clamp(max(sil, crease * 0.9), 0.0, 1.0) * far_fade;
	ALBEDO = ink.rgb;
	ALPHA = edge;
}
