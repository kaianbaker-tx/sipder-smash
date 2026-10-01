// The grass ground. Paths, sand and dark grass come from a map picture
// painted by world.gd (r = path, g = dark grass under tall grass, b = sand).
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D map_tex : filter_linear, repeat_disable;
// world rectangle the map covers: x, z, width, depth
uniform vec4 map_rect = vec4(-100.0, -100.0, 200.0, 200.0);
uniform vec4 grass_a : source_color = vec4(0.4, 0.7, 0.34, 1.0);
uniform vec4 grass_b : source_color = vec4(0.34, 0.63, 0.31, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.24, 0.5, 0.26, 1.0);
uniform vec4 path_col : source_color = vec4(0.93, 0.8, 0.56, 1.0);
uniform vec4 path_edge : source_color = vec4(0.78, 0.62, 0.4, 1.0);
uniform vec4 sand_col : source_color = vec4(0.97, 0.9, 0.66, 1.0);

varying vec3 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 muv = (wpos.xz - map_rect.xy) / map_rect.zw;
	vec3 m = texture(map_tex, muv).rgb;
	float n = noise(wpos.xz * 0.08) * 0.6 + noise(wpos.xz * 0.35) * 0.4;
	vec3 g = mix(grass_a.rgb, grass_b.rgb, smoothstep(0.45, 0.55, n));
	// little light speckles like mown grass
	float sp = step(0.93, hash(floor(wpos.xz * 3.0)));
	g = mix(g, g * 1.12, sp * 0.6);
	g = mix(g, grass_dark.rgb, smoothstep(0.3, 0.6, m.g));
	vec3 c = mix(g, sand_col.rgb, smoothstep(0.35, 0.55, m.b));
	// path: a darker rim then the light middle, edges wobble a bit
	float p = m.r + (noise(wpos.xz * 0.9) - 0.5) * 0.18;
	c = mix(c, path_edge.rgb, smoothstep(0.28, 0.34, p));
	vec3 pc = path_col.rgb * (0.94 + 0.12 * noise(wpos.xz * 1.7));
	float pebble = step(0.965, hash(floor(wpos.xz * 4.0)));
	pc = mix(pc, path_edge.rgb, pebble * 0.6);
	c = mix(c, pc, smoothstep(0.42, 0.48, p));
	ALBEDO = c;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.05, ndl) * smoothstep(0.35, 0.55, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit * 0.9;
}
