// Ink outline for characters and Crito Mon (inverted hull, same width on screen).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, fog_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.1, 0.07, 0.16, 1.0);
uniform float px = 2.0;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(n, 0.0)).xy;
	if (length(dir) > 0.0001) {
		dir = normalize(dir);
	}
	clip.xy += dir * px * (VIEWPORT_SIZE.y / 720.0) * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = color.rgb;
}
