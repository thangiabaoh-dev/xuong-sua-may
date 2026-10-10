shader_type spatial;
render_mode unshaded, cull_disabled;

// NOTE: mesh chibi khong co UV (mat OBJ dang f v//vn) nen shader nay
// co tinh khong dung UV/albedo texture — mau lay tu base_color.

uniform vec4 base_color : source_color = vec4(0.96, 0.84, 0.74, 1.0);
uniform vec4 shadow_color = vec4(0.75, 0.62, 0.52, 1.0);
uniform vec4 outline_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform vec4 rim_color = vec4(1.0, 0.95, 0.9, 1.0);

uniform float shadow_threshold = 0.5;
uniform float shadow_softness = 0.15;
uniform float outline_width = 0.035;
uniform float rim_power = 3.0;
uniform float rim_intensity = 0.4;

uniform bool use_vertex_colors = false;
uniform bool use_ramp = false;
uniform sampler2D ramp_texture : hint_default_white;

varying vec3 world_normal;
varying vec3 world_pos;
varying float face_dot;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	face_dot = dot(world_normal, view_dir);

	VERTEX += NORMAL * outline_width * (1.0 - face_dot * 0.3);
}

void fragment() {
	vec3 light_dir = normalize(vec3(0.5, 1.0, 0.3));
	float ndotl = max(dot(world_normal, light_dir), 0.0);

	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_pos);
	float ndotv = max(dot(world_normal, view_dir), 0.0);

	float shadow = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, ndotl);

	vec4 color = use_vertex_colors ? COLOR * base_color : base_color;

	vec3 final_color = mix(shadow_color.rgb, color.rgb, shadow);

	if (use_ramp) {
		final_color = texture(ramp_texture, vec2(shadow, 0.0)).rgb;
	}

	float rim = pow(1.0 - ndotv, rim_power) * rim_intensity;
	final_color += rim_color.rgb * rim * (1.0 - shadow);

	ALBEDO = final_color;
	ALPHA = color.a;
}

void light() {
}
