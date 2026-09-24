// Full-screen comic pass, drawn on a quad in front of the camera.
// - black ink outlines from the depth buffer (silhouettes + creases)
// - red / cyan print misregistration (stronger far away, at the edges, and fast)
// - speed lines, impact frames, glitch bands, paper grain, vignette, noir mode
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

global uniform float noir;
global uniform float world_time;

uniform float line_px = 1.4;
uniform float edge_depth = 0.035;
uniform float edge_crease = 0.012;
uniform vec4 ink : source_color = vec4(0.06, 0.02, 0.1, 1.0);
uniform float ca_base = 0.9;
uniform float ca_far = 2.0;
uniform float focus_dist = 90.0;
uniform float speed = 0.0;
uniform float impact = 0.0;
uniform float glitch = 0.0;
uniform float hurt = 0.0;
uniform float fade = 0.0;
uniform float saturation = 1.18;
uniform vec4 vignette_col : source_color = vec4(0.12, 0.0, 0.18, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0);
}

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
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
	float t = world_time;

	// glitch: horizontal band tearing
	if (glitch > 0.0) {
		float band = floor(uv.y * 24.0);
		float g = step(1.0 - glitch * 0.5, hash(vec2(band, floor(t * 18.0))));
		uv.x += (hash(vec2(band, floor(t * 31.0))) - 0.5) * 0.08 * g;
	}

	// --- ink lines ---------------------------------------------------------------
	// wobble the sample offset a little so lines feel hand drawn
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

	// --- misregistration (red / cyan offset) ----------------------------------
	vec2 cen = uv - 0.5;
	float defocus = smoothstep(focus_dist, focus_dist * 3.5, zc);
	float amt = ca_base * dot(cen, cen) * 4.0 + ca_far * defocus + speed * 4.0 + glitch * 8.0 + hurt * 5.0;
	vec2 off = normalize(cen + vec2(0.0001)) * amt * px * 1.5 + vec2(amt * px.x, 0.0);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;

	// punchier colours
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);

	col = mix(col, ink.rgb, edge);

	// --- speed lines ----------------------------------------------------------------
	if (speed > 0.01) {
		float ang = atan(cen.y, cen.x);
		float rad = length(cen * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0));
		float ln = hash(vec2(floor(ang * 70.0), floor(t * 12.0)));
		float s = step(0.86, ln) * smoothstep(0.32, 0.75, rad) * clamp(speed, 0.0, 1.0);
		col = mix(col, vec3(1.0, 0.97, 0.92), s * 0.75);
	}

	// --- impact frame: stark two-tone flash --------------------------------------
	if (impact > 0.0) {
		float lum2 = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 poster = mix(vec3(0.05, 0.0, 0.08), vec3(1.0, 0.15, 0.3), step(0.45, lum2));
		poster = mix(poster, vec3(1.0, 0.96, 0.9), step(0.8, lum2));
		col = mix(col, poster, clamp(impact, 0.0, 1.0));
	}

	// hurt: red edges
	col = mix(col, vec3(0.9, 0.05, 0.15), hurt * smoothstep(0.15, 0.6, length(cen)) * 0.7);

	// paper grain and vignette
	float grain = hash(floor(FRAGCOORD.xy / 2.0) + floor(t * 12.0)) - 0.5;
	col += grain * 0.035;
	float vig = smoothstep(0.45, 0.9, length(cen * vec2(1.1, 1.0)));
	col = mix(col, vignette_col.rgb, vig * 0.38);

	// noir mode
	float lum3 = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(smoothstep(0.03, 0.85, lum3)), noir);

	col = mix(col, vec3(0.03, 0.0, 0.05), fade);
	ALBEDO = col;
}
