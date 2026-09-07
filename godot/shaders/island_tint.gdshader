shader_type canvas_item;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
void fragment() {
	vec4 c = COLOR;
	float gray = dot(c.rgb,vec3(0.2126,0.7152,0.0722));
	COLOR = vec4(mix(vec3(gray),c.rgb,saturation)*brightness,c.a);
}
