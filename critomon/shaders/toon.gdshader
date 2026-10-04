// Bright cartoon shading for everything in Crito Mon.
// Two hard light bands (sun and shade), real sun shadows, a soft white rim
// and optional wind sway. Ink outlines are added by post.gdshader.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_tex = true;
uniform vec4 tint : source_color = vec4(1.0);
// colours the white / grey parts of a Kenney model (walls)
uniform vec4 wall_tint : source_color = vec4(1.0);
// turns the colourful parts of a Kenney model to another colour
uniform float hue = 0.0;
// turns only the strong blue parts (Kenney house roofs) to another colour
uniform float roof_hue = 0.0;
// multiplies the warm parts (Kenney house walls)
uniform vec4 warm_tint : source_color = vec4(1.0);
uniform float rim = 0.35;
uniform float emission = 0.0;
uniform float flash = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
// grass and leaves wave in the wind (0 = still)
uniform float wind = 0.0;
// 0..1 fades the thing out with a dither (for a Crito Mon going into a ball)
uniform float fade = 0.0;
// multiply by the mesh's vertex colours / the MultiMesh instance colour
uniform bool use_vcol = false;
uniform bool use_custom = false;
uniform vec2 uv_scale = vec2(1.0);

varying vec4 v_custom;

vec3 hue_shift(vec3 c, float h) {
	const vec3 k = vec3(0.57735);
	float ca = cos(h * 6.2831853);
	return c * ca + cross(k, c) * sin(h * 6.2831853) + k * dot(k, c) * (1.0 - ca);
}

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	UV *= uv_scale;
	if (wind > 0.0) {
		vec3 o = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = max(VERTEX.y, 0.0);
		float w = sin(TIME * 2.1 + o.x * 0.35 + o.z * 0.22) + 0.5 * sin(TIME * 3.7 + o.z * 0.5);
		VERTEX.x += w * wind * h;
		VERTEX.z += cos(TIME * 1.6 + o.x * 0.2) * wind * h * 0.5;
	}
}

void fragment() {
	vec3 c = use_tex ? texture(albedo_tex, UV).rgb : vec3(1.0);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float colourful = smoothstep(0.12, 0.3, sat);
	c = mix(c * wall_tint.rgb, c, colourful);
	if (hue != 0.0) {
		c = mix(c, clamp(hue_shift(c, hue), 0.0, 1.0), colourful);
	}
	if (roof_hue != 0.0) {
		float roof = smoothstep(0.25, 0.4, c.b - max(c.r, c.g));
		c = mix(c, clamp(hue_shift(c, roof_hue), 0.0, 1.0), roof);
	}
	c = mix(c, c * warm_tint.rgb, smoothstep(0.05, 0.15, c.r - c.b));
	c *= tint.rgb;
	if (use_vcol) {
		c *= COLOR.rgb;
	}
	if (use_custom) {
		c *= v_custom.rgb;
	}
	c = mix(c, flash_color.rgb, flash);
	ALBEDO = c;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(1.0, 0.98, 0.92) * smoothstep(0.45, 0.55, fres) * rim * 0.35 + c * emission + flash_color.rgb * flash * 0.5;
	if (fade > 0.0) {
		// ordered dither so it still works without transparency sorting
		vec2 p = floor(FRAGCOORD.xy);
		float d = fract(dot(p, vec2(0.5, 0.25)) + fract(p.y * 0.5) * 0.5);
		if (d < fade) {
			discard;
		}
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, 0.05, ndl) * smoothstep(0.35, 0.55, ATTENUATION);
	// a little extra where the sun hits straight on
	float hot = smoothstep(0.62, 0.68, ndl) * lit;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * (lit * 0.9 + hot * 0.12);
}
