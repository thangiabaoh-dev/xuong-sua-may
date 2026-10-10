shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.96, 0.84, 0.74, 1.0);
uniform vec4 shadow_color = vec4(0.75, 0.62, 0.52, 1.0);
uniform vec4 outline_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform float shadow_threshold = 0.5;
uniform float shadow_softness = 0.1;
uniform float outline_width = 0.03;
uniform bool use_vertex_colors = false;

uniform sampler2D ramp_texture : hint_white;

varying vec3 world_normal;
varying vec3 world_pos;
varying float face_dot;

void vertex() {
	world_pos = (WORLD_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((WORLD_MATRIX * vec4(NORMAL, 0.0)).xyz);
	
	vec3 view_dir = normalize(CAMERA_POSITION - world_pos);
	face_dot = dot(world_normal, view_dir);
	
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	vec3 light_dir = normalize(VERTEX_LIGHTING ? vec3(0.3, 0.7, 0.5) : vec3(0.5, 1.0, 0.3));
	float ndotl = max(dot(world_normal, light_dir), 0.0);
	
	float shadow = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, ndotl);
	
	vec4 color = use_vertex_colors ? COLOR * base_color : base_color;
	color.rgb = mix(shadow_color.rgb, color.rgb, shadow);
	
	if (ramp_texture != null) {
		color.rgb = texture(ramp_texture, vec2(shadow, 0.0)).rgb;
	}
	
	ALBEDO = color.rgb;
	ALPHA = color.a;
}

void light() {
}