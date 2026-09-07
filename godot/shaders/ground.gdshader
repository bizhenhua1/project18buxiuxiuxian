shader_type canvas_item;
render_mode unshaded;
uniform sampler2D ground_tex : repeat_enable, filter_linear_mipmap;
uniform vec2 resolution = vec2(760.0, 640.0);
uniform vec2 camera_world;
uniform float heading = 0.0;
uniform float focal = 530.0;
uniform float horizon = 0.48;
uniform float camera_height = 58.0;

void fragment() {
	float y = UV.y;
	vec3 sky = mix(vec3(0.22, 0.38, 0.56), vec3(0.65, 0.74, 0.73), smoothstep(0.0, horizon, y));
	if (y <= horizon) {
		COLOR = vec4(sky, 1.0);
	} else {
		float z = camera_height * focal / max(0.2, (y - horizon) * resolution.y);
		float x = (UV.x - 0.5) * resolution.x * z / focal;
		vec2 world = camera_world + vec2(cos(heading)*x + sin(heading)*z, -sin(heading)*x + cos(heading)*z);
		vec3 ground = texture(ground_tex, world / 145.0).rgb * vec3(0.56, 0.61, 0.46);
		float fog = smoothstep(300.0, 1700.0, z);
		COLOR = vec4(mix(ground, vec3(0.13, 0.19, 0.14), fog), 1.0);
	}
}
