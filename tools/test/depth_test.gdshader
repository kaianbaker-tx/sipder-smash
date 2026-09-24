shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
void vertex() { POSITION = vec4(VERTEX.xy * 2.0, 1.0, 1.0); }
float lin(vec2 uv, mat4 ipm) {
	float d = texture(depth_tex, uv).r;
	vec4 v = ipm * vec4(uv * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	return -v.z / v.w;
}
void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float z = lin(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float e = 0.0;
	e += abs(lin(SCREEN_UV + vec2(px.x, 0), INV_PROJECTION_MATRIX) - z);
	e += abs(lin(SCREEN_UV + vec2(0, px.y), INV_PROJECTION_MATRIX) - z);
	float edge = step(0.02 * z, e);
	ALBEDO = SCREEN_UV.x < 0.5 ? vec3(clamp(e / z * 10.0, 0.0, 1.0)) : vec3(fract(z / 20.0));
}
