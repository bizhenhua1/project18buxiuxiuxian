shader_type canvas_item;
uniform sampler2D target_mask : filter_linear;
uniform sampler2D occlusion_mask : filter_linear;
uniform vec2 pixel = vec2(0.001);
uniform vec4 tint : source_color = vec4(0.7,0.9,0.6,1.0);
void fragment() {
	float a = texture(target_mask,UV).a;
	float o = texture(occlusion_mask,UV).a;
	float edge = 0.0;
	for(int x=-2;x<=2;x++) for(int y=-2;y<=2;y++) {
		edge=max(edge,texture(target_mask,UV+vec2(float(x),float(y))*pixel).a);
	}
	COLOR = vec4(tint.rgb,max(a*o*0.18,(edge-a)*0.85));
}
