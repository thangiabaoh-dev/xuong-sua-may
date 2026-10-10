shader_type spatial;
render_mode cull_front, unshaded;

uniform float outline_width = 0.05;
uniform vec4 outline_color = vec4(0.05, 0.05, 0.07, 1.0);
uniform bool use_normal_offset = true;

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz);
	float ndotv = max(dot(world_normal, view_dir), 0.0);
	
	float thickness = outline_width * (1.0 - ndotv * 0.5);
	
	if (use_normal_offset) {
		VERTEX += NORMAL * thickness;
	} else {
		VERTEX += view_dir * thickness;
	}
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}

void light() {
}