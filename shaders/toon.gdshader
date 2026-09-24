// Comic-book toon shader used by everything in the city.
// Hard light bands, Ben-Day halftone dots in the mid tones, cross-hatching in
// deep shadow, coloured rim light, glowing windows and a dotted comic haze.
// The black ink outlines are drawn later by post.gdshader.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, fog_disabled;

global uniform vec3 sun_dir;
global uniform vec4 sun_color : source_color;
global uniform vec4 shade_color : source_color;
global uniform vec4 rim_color : source_color;
global uniform vec4 rim_color_b : source_color;
global uniform vec4 fog_color : source_color;
global uniform vec4 fog_color_high : source_color;
global uniform vec4 sky_top : source_color;
global uniform vec4 sky_horizon : source_color;
global uniform float fog_start;
global uniform float fog_end;
global uniform float dot_size;
global uniform float noir;
global uniform float world_time;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
// colours the white / grey walls of Kenney buildings
uniform vec4 wall_tint : source_color = vec4(1.0);
// 0 = normal, 1 = a building (windows reflect the sky and some are lit)
uniform float windows = 0.0;
uniform float character = 0.0;
uniform float emission = 0.0;
uniform vec4 emission_color : source_color = vec4(1.0, 0.3, 0.6, 1.0);
// glitch-bot flicker (0 = off)
uniform float glitch = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float palette_shift = 0.0;

varying vec3 world_pos;
varying vec3 world_nrm;
varying float inst_rand;

float hash1(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

vec3 hue_shift(vec3 c, float h) {
	// rotate hue around the grey axis
	const vec3 k = vec3(0.57735);
	float ca = cos(h * 6.2831853);
	return c * ca + cross(k, c) * sin(h * 6.2831853) + k * dot(k, c) * (1.0 - ca);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 o = MODEL_MATRIX[3].xyz;
	inst_rand = hash1(o.xz * 0.013 + o.y * 0.07);
	if (glitch > 0.0) {
		float band = floor(VERTEX.y * 6.0 + world_time * 23.0);
		float j = step(0.82, hash1(vec2(band, floor(world_time * 15.0))));
		VERTEX.x += (hash1(vec2(band * 1.7, floor(world_time * 30.0))) - 0.5) * 0.35 * glitch * j;
	}
}

// Ben-Day dot mask: returns 1 inside a dot. Dots are on a 45 degree screen grid.
float dots(vec2 frag, float coverage, float size) {
	vec2 p = frag / size;
	p = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * p;
	vec2 cell = fract(p) - 0.5;
	float r = sqrt(clamp(coverage, 0.0, 1.0) / 3.14159) * 1.05;
	return 1.0 - smoothstep(r - 0.08, r + 0.08, length(cell));
}

float hatch(vec2 frag, float size, float amount) {
	float l = sin((frag.x + frag.y) / size * 3.14159);
	float l2 = sin((frag.x - frag.y) / size * 3.14159);
	float a = smoothstep(0.55, 0.9, l) * step(0.15, amount);
	float b = smoothstep(0.55, 0.9, l2) * step(0.55, amount);
	return max(a, b);
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	float mx0 = max(tex.r, max(tex.g, tex.b));
	float mn0 = min(tex.r, min(tex.g, tex.b));
	float sat0 = (mx0 - mn0) / max(mx0, 0.001);
	vec3 N = normalize(world_nrm);
	vec3 V = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 L = normalize(sun_dir);
	float ndl = dot(N, L);
	vec2 frag = FRAGCOORD.xy;
	float ds = dot_size * (1.0 + character * 0.3);

	// --- windows: reflect the dusk sky, some glow warm -----------------------
	float is_window = 0.0;
	if (windows > 0.5) {
		is_window = step(0.3, sat0) * step(tex.r * 1.15, tex.b) * step(tex.g, tex.b) * step(0.35, tex.b);
		is_window *= step(abs(N.y), 0.5);
	}

	vec3 base = tex * tint.rgb;
	base = mix(base * wall_tint.rgb, base, smoothstep(0.12, 0.3, sat0));
	if (palette_shift != 0.0) {
		base = mix(base, hue_shift(base, palette_shift), smoothstep(0.12, 0.3, sat0) * (1.0 - is_window));
	}

	// --- light bands --------------------------------------------------------
	float lit = smoothstep(0.30, 0.34, ndl);
	float mid = smoothstep(-0.06, -0.02, ndl) * (1.0 - lit);
	float shadow = 1.0 - lit - mid;
	float sky = clamp(N.y * 0.5 + 0.5, 0.0, 1.0);

	vec3 lit_col = base * sun_color.rgb * 1.08;
	vec3 mid_col = base * mix(shade_color.rgb, sun_color.rgb, 0.55);
	vec3 shd_col = base * shade_color.rgb * (0.85 + 0.25 * sky);

	vec3 col = lit_col * lit + mid_col * mid + shd_col * shadow;

	// halftone in the mid tones, cross hatch in deep shadow
	float dmid = dots(frag, 0.28, ds) * mid;
	col = mix(col, base * shade_color.rgb * 0.8, dmid * 0.85);
	float dlit = dots(frag + ds * 0.5, 0.12, ds) * lit * (1.0 - is_window);
	col = mix(col, col * 1.18 + vec3(0.04, 0.0, 0.03), dlit * 0.6);
	float h = hatch(frag, ds * 0.9, 0.5 + character * 0.3) * shadow;
	col = mix(col, shd_col * 0.55, h * 0.7);

	// --- windows --------------------------------------------------------------
	if (is_window > 0.5) {
		vec3 R = reflect(-V, N);
		float t = clamp(R.y * 1.6 + 0.35, 0.0, 1.0);
		vec3 refl = mix(sky_horizon.rgb, sky_top.rgb, t);
		refl = mix(refl, base, 0.25);
		// lit rooms: pick per floor, per face, per coarse horizontal segment
		vec3 tng = normalize(cross(N, vec3(0.0, 1.0, 0.0)) + vec3(0.0001));
		float floor_id = floor(world_pos.y / 5.6);
		float seg = floor(dot(world_pos, tng) / 9.0);
		float r = hash1(vec2(floor_id * 3.1 + seg * 17.7, dot(N, vec3(1.0, 3.0, 7.0)) + inst_rand * 91.0));
		float on = step(0.74, r);
		vec3 warm = mix(vec3(1.0, 0.8, 0.42), vec3(1.0, 0.5, 0.72), step(0.92, r));
		col = mix(refl, warm * 1.25, on);
		// comic glass shine: two diagonal streaks
		float sh = fract((world_pos.x + world_pos.z) * 0.035 + world_pos.y * 0.035);
		float streak = step(0.9, sh) * (1.0 - step(0.935, sh)) + step(0.955, sh) * (1.0 - step(0.965, sh));
		col = mix(col, vec3(1.0, 0.97, 1.0), streak * (1.0 - on) * 0.55);
	}

	// --- rim light (two colours, Spider-Verse style) ---------------------------
	float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 3.0);
	float side = dot(N, normalize(cross(L, vec3(0.0, 1.0, 0.0)) + vec3(0.0001)));
	vec3 rim = mix(rim_color.rgb, rim_color_b.rgb, step(0.0, side));
	col += rim * smoothstep(0.35, 0.45, fres) * (0.25 + character * 0.75) * (1.0 - is_window);

	col += emission_color.rgb * emission;

	// --- glitch flicker -------------------------------------------------------
	if (glitch > 0.0) {
		float g = step(0.7, hash1(vec2(floor(frag.y / 6.0), floor(world_time * 20.0))));
		col = mix(col, vec3(col.b, col.r, col.g) * 1.4, g * glitch);
		col += vec3(0.0, 0.9, 1.0) * g * glitch * 0.25;
	}
	col = mix(col, flash_color.rgb, flash);

	// --- comic haze: fog that dissolves into dots ------------------------------
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float f = smoothstep(fog_start, fog_end, dist);
	vec3 fc = mix(fog_color.rgb, fog_color_high.rgb, clamp(world_pos.y / 140.0, 0.0, 1.0));
	float fd = dots(frag, f, ds * 1.3);
	col = mix(col, fc, clamp(f * 0.75 + fd * f * 0.35, 0.0, 1.0));

	// noir mode: black and white comic
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(smoothstep(0.08, 0.7, lum)), noir);

	ALBEDO = col;
}
