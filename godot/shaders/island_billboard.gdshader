shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D art : source_color, filter_linear_mipmap;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
uniform float reveal = 1.0;
uniform float fog_cover = 0.0;
uniform vec2 fog_origin;
#include "res://shaders/island_fog_field.gdshaderinc"
void fragment() {
	vec4 c = texture(art,UV);
	float gray = dot(c.rgb,vec3(0.2126,0.7152,0.0722));
	ALBEDO = mix(vec3(gray),c.rgb,saturation)*brightness;
	ALPHA = c.a*reveal;
	if (fog_cover > 0.0) {
		// Only the silhouette shapes the cloud; illustration RGB never enters it.
		vec2 p = UV*vec2(1.0,1.6)+fog_origin;
		float n = fog_density(p,TIME);
		vec2 uv = UV+vec2(sin(TIME*0.18+n*6.0),cos(TIME*0.13+n*5.0))*0.012*fog_cover;
		float mask = texture(art,uv).a*0.2;
		for (int i=0;i<8;i++) {
			float angle = float(i)*0.785398;
			mask += texture(art,clamp(uv+vec2(cos(angle),sin(angle))*0.018,vec2(0.001),vec2(0.999))).a*0.1;
		}
		mask = smoothstep(0.03,0.8,mask);
		vec3 mist = fog_color(p,TIME)*clamp(brightness,0.72,1.22);
		ALBEDO = mix(ALBEDO,mist,fog_cover);
		ALPHA = mix(ALPHA,mask*0.94,fog_cover);
	}
}
