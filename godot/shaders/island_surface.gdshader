shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D art : source_color, filter_linear_mipmap;
uniform bool textured = true;
uniform vec4 tint : source_color = vec4(1.0);
uniform float brightness = 1.0;
uniform float saturation = 1.0;
void fragment() {
	vec4 c = tint;
	if (textured) c *= texture(art,UV);
	if (c.a < 0.08) discard;
	float gray = dot(c.rgb,vec3(0.2126,0.7152,0.0722));
	ALBEDO = mix(vec3(gray),c.rgb,saturation)*brightness;
	if (!textured) {
		vec3 world_normal = (INV_VIEW_MATRIX*vec4(NORMAL,0.0)).xyz;
		ALBEDO *= 0.72+0.28*max(0.0,dot(world_normal,normalize(vec3(-1.0,0.5,1.0))));
	}
}
