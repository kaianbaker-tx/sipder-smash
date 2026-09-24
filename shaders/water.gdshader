// Comic river water: deep purple with wobbly pink reflection streaks,
// halftone ripples and white foam lines.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

global uniform vec4 sky_horizon : source_color;
global uniform vec4 sky_top : source_color;
global uniform vec4 fog_color : source_color;
global uniform vec4 fog_color_high : source_color;
global uniform float fog_start;
global uniform float fog_end;
global uniform float dot_size;
global uniform float noir;
global uniform float world_time;

uniform vec4 deep : source_color = vec4(0.12, 0.05, 0.3, 1.0);
uniform vec4 shallow : source_color = vec4(0.22, 0.12, 0.5, 1.0);

varying vec3 wp;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

float dots(vec2 frag, float coverage, float size) {
	vec2 p = frag / size;
	p = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * p;
	vec2 cell = fract(p) - 0.5;
	float r = sqrt(clamp(coverage, 0.0, 1.0) / 3.14159) * 1.05;
	return 1.0 - smoothstep(r - 0.08, r + 0.08, length(cell));
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float n = noise(p * 0.05 + vec2(world_time * 0.05, 0.0)) * 0.6 + noise(p * 0.13 - vec2(0.0, world_time * 0.08)) * 0.4;
	vec3 col = mix(deep.rgb, shallow.rgb, n);
	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	// sky reflection toward the horizon
	float fres = pow(1.0 - clamp(V.y, 0.0, 1.0), 4.0);
	col = mix(col, mix(sky_horizon.rgb, sky_top.rgb, 0.4), fres * 0.6);
	// streaky reflections
	float streak = step(0.72, noise(vec2(p.x * 0.02, p.y * 0.4 + world_time * 0.6)));
	col = mix(col, sky_horizon.rgb * 1.1, streak * 0.45);
	// ripple rings as halftone
	float rip = sin(n * 30.0 + world_time * 2.0);
	col = mix(col, shallow.rgb * 1.5, dots(FRAGCOORD.xy, smoothstep(0.6, 1.0, rip) * 0.5, dot_size));
	// foam lines
	float foam = smoothstep(0.93, 0.97, sin(n * 18.0 - world_time * 1.5));
	col = mix(col, vec3(0.95, 0.9, 1.0), foam * 0.5);

	float dist = length(wp - CAMERA_POSITION_WORLD);
	float f = smoothstep(fog_start, fog_end, dist);
	col = mix(col, fog_color.rgb, f * 0.85);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(smoothstep(0.08, 0.7, lum)), noir);
	ALBEDO = col;
}
