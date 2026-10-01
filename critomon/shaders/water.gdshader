// A cartoon pond: bright blue, darker in the middle, moving white sparkles.
shader_type spatial;
render_mode cull_back, specular_disabled, unshaded;

uniform vec4 shallow : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform vec4 deep : source_color = vec4(0.18, 0.5, 0.9, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	vec3 c = mix(deep.rgb, shallow.rgb, smoothstep(0.35, 0.95, r));
	float w = sin(wpos.x * 1.3 + TIME * 1.4) + sin(wpos.z * 1.7 - TIME * 1.1) + sin((wpos.x + wpos.z) * 0.9 + TIME * 0.7);
	c = mix(c, vec3(1.0), step(2.3, w) * 0.8);
	c = mix(c, vec3(1.0), smoothstep(0.9, 0.97, r) * 0.7);
	ALBEDO = c;
}
