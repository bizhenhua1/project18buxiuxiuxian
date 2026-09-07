shader_type spatial;
render_mode unshaded,cull_disabled,depth_prepass_alpha;
uniform float reveal=1.0;
uniform float brightness=1.0;
uniform float saturation=1.0;
uniform vec2 origin;
uniform float surface_height;
varying vec3 local_pos;
#include "res://shaders/island_fog_field.gdshaderinc"
void vertex(){local_pos=VERTEX;}
void fragment(){
	vec2 p=local_pos.xz+origin;
	float y=(local_pos.y+surface_height+TIME*0.95)*5.0;
	float streak=(fog_noise(vec2(p.x*21.0,y))+fog_noise(vec2(p.y*21.0,y+7.1)))*0.5;
	// Keep the whole curtain, but feather its bright flow over broad edge bands.
	float edge_distance=min(UV.x,1.0-UV.x);
	float side_blend=smoothstep(0.0,0.16,edge_distance);
	float drop=max(0.0,0.008-local_pos.y);
	float lip_blend=smoothstep(0.0,0.22,drop);
	float ripples=fog_noise(p*12.0+vec2(TIME*0.025,0.0));
	vec3 lip_color=mix(vec3(0.10,0.29,0.28),vec3(0.25,0.46,0.38),ripples*0.65);
	vec3 falling=mix(vec3(0.17,0.38,0.34),vec3(0.61,0.73,0.61),streak);
	ALBEDO=mix(lip_color,falling,lip_blend*mix(0.20,1.0,side_blend));
	float gray=dot(ALBEDO,vec3(0.299,0.587,0.114));
	ALBEDO=mix(vec3(gray),ALBEDO,saturation)*brightness;
	// Opaque upper flow participates in the depth prepass, preventing rear
	// curtains from double-blending through front curtains after rotation.
	ALPHA=(1.0-smoothstep(0.55,1.0,UV.y))*reveal;
}
