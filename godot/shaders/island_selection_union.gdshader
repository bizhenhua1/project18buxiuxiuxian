shader_type canvas_item;
uniform sampler2D prop_art : filter_linear;
uniform vec4 prop_rect;
uniform vec2 top_origin;
uniform vec2 top_u;
uniform vec2 top_v;
uniform vec2 view_size;
uniform vec4 tint : source_color;
float prop_mask(vec2 p) {
	vec2 uv = (p-prop_rect.xy)/max(prop_rect.zw,vec2(1.0));
	if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) return 0.0;
	return texture(prop_art,uv).a;
}
float union_mask(vec2 p) {
	vec2 d = p-top_origin;
	float det = top_u.x*top_v.y-top_u.y*top_v.x;
	vec2 uv = vec2(d.x*top_v.y-d.y*top_v.x,top_u.x*d.y-top_u.y*d.x)/det;
	float ground = step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
	return max(ground,prop_mask(p));
}
void fragment() {
	vec2 p = UV*view_size;
	float center = union_mask(p);
	float expanded = center;
	for (int i=0;i<8;i++) {
		float angle = float(i)*0.78539816;
		expanded = max(expanded,union_mask(p+vec2(cos(angle),sin(angle))*1.2));
	}
	float edge = max(0.0,expanded-center);
	float gray = dot(tint.rgb,vec3(0.299,0.587,0.114));
	vec3 rich_color = clamp(mix(vec3(gray),tint.rgb,1.65)*1.12,vec3(0.0),vec3(1.0));
	vec3 fill_color = min(rich_color*1.10,vec3(1.0));
	// One wash over the union: never accumulate top, prop and x-ray tint layers.
	COLOR = vec4(mix(fill_color,tint.rgb,edge),max(edge*0.95,center*0.34)*tint.a);
}
