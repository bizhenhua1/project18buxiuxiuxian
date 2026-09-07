shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float material_row = 0.0;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
void fragment() {
	vec2 uv = clamp(UV,vec2(0.0),vec2(1.0));
	vec3 color = texture(atlas,uv).rgb;
	float gray = dot(color,vec3(0.299,0.587,0.114));
	ALBEDO = mix(vec3(gray),color,saturation)*brightness;
}
