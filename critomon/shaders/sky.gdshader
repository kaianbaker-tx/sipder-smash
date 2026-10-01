// Sunny cartoon sky: blue on top, pale near the ground, a soft sun.
shader_type sky;

uniform vec4 top : source_color = vec4(0.22, 0.52, 0.98, 1.0);
uniform vec4 horizon : source_color = vec4(0.72, 0.9, 1.0, 1.0);
uniform vec4 ground : source_color = vec4(0.75, 0.9, 1.0, 1.0);
uniform vec4 sun_col : source_color = vec4(1.0, 0.97, 0.8, 1.0);
uniform vec3 sun_dir = vec3(0.4, 0.6, 0.5);

void sky() {
	float y = EYEDIR.y;
	vec3 c = mix(horizon.rgb, top.rgb, smoothstep(0.0, 0.55, y));
	c = mix(c, ground.rgb, smoothstep(0.0, -0.08, y));
	float s = dot(normalize(EYEDIR), normalize(sun_dir));
	c = mix(c, sun_col.rgb, smoothstep(0.9985, 0.999, s));
	c += sun_col.rgb * pow(max(s, 0.0), 40.0) * 0.25;
	COLOR = c;
}
