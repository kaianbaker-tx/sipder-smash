// Comic dusk sky: purple-to-pink gradient printed with big halftone dots,
// ink-edged clouds, a moon, twinkling stars and the swirling Glitch Portal.
shader_type sky;

global uniform vec4 sky_top : source_color;
global uniform vec4 sky_mid : source_color;
global uniform vec4 sky_horizon : source_color;
global uniform vec4 fog_color : source_color;
global uniform float dot_size;
global uniform float noir;
global uniform float world_time;
global uniform vec3 portal_dir;
global uniform float portal_power;
global uniform float portal_size;

uniform vec3 moon_dir = vec3(-0.45, 0.42, -0.78);

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

float dots(vec2 frag, float coverage, float size) {
	vec2 p = frag / size;
	p = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * p;
	vec2 cell = fract(p) - 0.5;
	float r = sqrt(clamp(coverage, 0.0, 1.0) / 3.14159) * 1.05;
	return 1.0 - smoothstep(r - 0.08, r + 0.08, length(cell));
}

void sky() {
	vec3 dir = EYEDIR;
	float y = dir.y;
	vec2 frag = FRAGCOORD.xy;

	// gradient
	float t1 = smoothstep(-0.05, 0.22, y);
	float t2 = smoothstep(0.18, 0.75, y);
	vec3 col = mix(sky_horizon.rgb, sky_mid.rgb, t1);
	col = mix(col, sky_top.rgb, t2);
	// printed look: dots of the next colour up
	float band = fract(t1 * 0.999) * (1.0 - t2);
	col = mix(col, sky_mid.rgb * 1.1, dots(frag, band * 0.55, dot_size * 2.2) * (1.0 - t1) * 0.9);
	col = mix(col, sky_top.rgb * 0.85, dots(frag, t2 * 0.45, dot_size * 2.2) * 0.6);

	// stars
	if (y > 0.15) {
		vec2 sp = dir.xz / (y + 0.4) * 60.0;
		float st = step(0.985, hash(floor(sp)));
		float tw = 0.5 + 0.5 * sin(world_time * 3.0 + hash(floor(sp) + 3.0) * 20.0);
		vec2 f = fract(sp) - 0.5;
		col += vec3(1.0, 0.95, 0.85) * st * tw * (1.0 - smoothstep(0.05, 0.2, length(f))) * smoothstep(0.15, 0.4, y);
	}

	// moon with an ink rim and halftone shading
	float md = dot(dir, normalize(moon_dir));
	float moon = smoothstep(0.9978, 0.9981, md);
	float moon_rim = smoothstep(0.9972, 0.9975, md) - moon;
	vec3 mcol = vec3(1.0, 0.94, 0.82);
	vec3 mside = normalize(cross(normalize(moon_dir), vec3(0.0, 1.0, 0.0)));
	float shade = dot(dir - normalize(moon_dir), mside) * 40.0;
	mcol = mix(mcol, vec3(0.95, 0.6, 0.7), dots(frag, clamp(shade + 0.3, 0.0, 0.7), dot_size * 0.9));
	col = mix(col, mcol, moon);
	col = mix(col, vec3(0.1, 0.02, 0.15), moon_rim);
	col += vec3(0.8, 0.5, 0.9) * pow(max(md, 0.0), 400.0) * 0.4;

	// clouds: flat comic shapes with ink edges
	if (y > -0.02) {
		vec2 cp = dir.xz / (y + 0.12) * 1.3 + vec2(world_time * 0.01, 0.0);
		float n = fbm(cp * 1.2);
		float th = 0.62;
		float cloud = smoothstep(th - 0.005, th + 0.005, n);
		float edge = smoothstep(th - 0.025, th - 0.012, n) * (1.0 - cloud);
		float fade = smoothstep(-0.02, 0.1, y) * (1.0 - smoothstep(0.5, 0.8, y));
		vec3 ccol = mix(vec3(1.0, 0.55, 0.62), vec3(0.62, 0.32, 0.8), smoothstep(0.02, 0.35, y));
		float inner = smoothstep(th + 0.02, th + 0.12, n);
		ccol = mix(ccol, ccol * vec3(0.75, 0.7, 1.0), dots(frag, inner * 0.5, dot_size * 1.2));
		col = mix(col, ccol, cloud * fade);
		col = mix(col, vec3(0.12, 0.03, 0.2), edge * fade * 0.9);
	}

	// the Glitch Portal: a swirling multiverse rip
	if (portal_power > 0.0) {
		vec3 pd = normalize(portal_dir);
		float pdot = dot(dir, pd);
		if (pdot > 0.3) {
			vec3 px = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
			vec3 py = cross(px, pd);
			vec2 q = vec2(dot(dir, px), dot(dir, py)) / portal_size;
			float r = length(q);
			float a = atan(q.y, q.x);
			float swirl = sin(a * 5.0 + r * 12.0 - world_time * 3.0);
			float ring = smoothstep(1.0, 0.2, r);
			vec3 pc = mix(vec3(0.0, 0.95, 1.0), vec3(1.0, 0.1, 0.7), 0.5 + 0.5 * swirl);
			pc = mix(pc, vec3(1.0, 0.9, 0.2), step(0.85, swirl) * 0.8);
			pc = mix(pc, vec3(0.05, 0.0, 0.1), smoothstep(0.35, 0.0, r));
			// glitchy squares at the edge
			vec2 bq = floor(q * 6.0 + floor(world_time * 8.0));
			float blocks = step(0.8, hash(bq)) * smoothstep(1.3, 0.7, r) * (1.0 - ring * 0.5);
			col = mix(col, pc, ring * portal_power);
			col = mix(col, vec3(hash(bq + 1.0), 0.2, 1.0), blocks * portal_power);
			float prim = smoothstep(1.02, 0.98, r) - smoothstep(0.98, 0.94, r);
			col = mix(col, vec3(0.05, 0.0, 0.08), prim * portal_power);
		}
	}

	// below the horizon: haze colour
	col = mix(col, fog_color.rgb, smoothstep(0.0, -0.08, y));

	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(smoothstep(0.02, 0.8, lum)), noir);
	COLOR = col;
}
