// Neon signs and graffiti: bright, unshaded, flickers now and then.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;

global uniform vec4 fog_color : source_color;
global uniform float fog_start;
global uniform float fog_end;
global uniform float noir;
global uniform float world_time;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float flicker = 1.0;
varying vec3 wp;
varying float seed;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) discard;
	float f = 1.0;
	if (flicker > 0.0) {
		float ph = world_time * (1.0 + seed * 2.0) + seed * 40.0;
		f = mix(1.0, 0.45, step(0.97, fract(ph * 0.37)) * step(0.5, fract(ph * 11.0)));
	}
	vec3 col = c.rgb * f * 1.1;
	float dist = length(wp - CAMERA_POSITION_WORLD);
	col = mix(col, fog_color.rgb, smoothstep(fog_start, fog_end, dist) * 0.8);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(smoothstep(0.08, 0.7, lum)), noir);
	ALBEDO = col;
}
