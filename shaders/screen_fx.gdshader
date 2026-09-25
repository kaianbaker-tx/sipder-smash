// The finishing comic pass, a 2D shader over the whole finished 3D picture
// (so glowing and see-through things are included):
// red / cyan print misregistration, punchy colours, speed lines, impact
// frames, glitch tearing, hurt flash, paper grain, vignette and noir.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

global uniform float noir;
global uniform float noir_keep;
global uniform float world_time;

uniform float ca_base = 0.9;
uniform float speed = 0.0;
uniform float impact = 0.0;
uniform float glitch = 0.0;
uniform float hurt = 0.0;
uniform float fade = 0.0;
uniform float saturation = 1.18;
uniform vec4 vignette_col : source_color = vec4(0.12, 0.0, 0.18, 1.0);

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423));
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	float t = world_time;

	// glitch: horizontal band tearing
	if (glitch > 0.0) {
		float band = floor(uv.y * 24.0);
		float g = step(1.0 - glitch * 0.5, hash(vec2(band, floor(t * 18.0))));
		uv.x += (hash(vec2(band, floor(t * 31.0))) - 0.5) * 0.08 * g;
	}

	// misregistration: stronger at the edges, when fast, glitching or hurt
	vec2 cen = uv - 0.5;
	float amt = ca_base * dot(cen, cen) * 4.0 + 0.6 + speed * 4.0 + glitch * 8.0 + hurt * 5.0;
	vec2 off = normalize(cen + vec2(0.0001)) * amt * px * 1.5 + vec2(amt * px.x, 0.0);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;

	// punchier colours
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, saturation);

	// speed lines
	if (speed > 0.01) {
		float ang = atan(cen.y, cen.x);
		float rad = length(cen * vec2(res.x / res.y, 1.0));
		float ln = hash(vec2(floor(ang * 70.0), floor(t * 12.0)));
		float s = step(0.86, ln) * smoothstep(0.32, 0.75, rad) * clamp(speed, 0.0, 1.0);
		col = mix(col, vec3(1.0, 0.97, 0.92), s * 0.75);
	}

	// impact frame: stark two-tone flash
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

	// noir mode (the Noir-Verse keeps heroes and bots in colour, so skip it there)
	float lum3 = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(smoothstep(0.03, 0.85, lum3)), noir * (1.0 - noir_keep));

	col = mix(col, vec3(0.03, 0.0, 0.05), fade);
	COLOR = vec4(col, 1.0);
}
