// Camera-facing sprites drawn in one batch (MultiMesh): tokens and birds.
// Instance scale x / y stretch the sprite (used to fake spinning and flapping).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

global uniform vec4 fog_color : source_color;
global uniform float fog_start;
global uniform float fog_end;
global uniform float noir;
uniform sampler2D tex : source_color, filter_linear_mipmap;
varying vec3 wp;

void vertex() {
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * sx, INV_VIEW_MATRIX[1] * sy, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	wp = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec4 c = texture(tex, UV);
	if (c.a < 0.5) discard;
	vec3 col = c.rgb;
	col = mix(col, fog_color.rgb, smoothstep(fog_start, fog_end, length(wp - CAMERA_POSITION_WORLD)) * 0.8);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(smoothstep(0.02, 0.8, lum)), noir);
	ALBEDO = col;
}
