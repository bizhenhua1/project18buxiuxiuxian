shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
uniform float clearing = 0.0;
uniform bool wisp = false;
uniform vec2 origin;
varying vec3 local_pos;
#include "res://shaders/island_fog_field.gdshaderinc"
void vertex() { local_pos=VERTEX; }
void fragment() {
	vec2 p = (wisp ? UV-0.5 : local_pos.xz)+origin;
	float n = fog_density(p,TIME);
	vec3 color = fog_color(p,TIME);
	ALBEDO = color*clamp(brightness,0.72,1.22);
	float cover = 1.0-smoothstep(n*0.22,0.8+n*0.2,clearing);
	if (clearing <= 0.0) cover=1.0;
	if (clearing >= 1.0) cover=0.0;
	float shape = wisp ? pow(max(0.0,1.0-length((UV-0.5)*2.0)),1.1)*smoothstep(0.15,0.75,n)*0.85 : 1.0;
	if (wisp) ALBEDO = mix(color,vec3(0.59,0.68,0.62),0.32)*clamp(brightness,0.72,1.22);
	ALPHA = cover*shape;
}
