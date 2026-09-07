shader_type spatial;
render_mode unshaded,cull_disabled;
uniform sampler2D art : source_color,filter_linear_mipmap;
uniform float brightness=1.0;
uniform float saturation=1.0;
uniform vec4 banks;
uniform vec2 flow;
uniform vec2 origin;
varying vec3 pos;
#include "res://shaders/island_fog_field.gdshaderinc"
void vertex(){pos=VERTEX;}
void fragment(){
	vec2 p=pos.xz+origin;
	vec2 drift=flow*TIME*0.12;
	float a=fog_noise((p-drift)*12.0+vec2(TIME*0.025,0.0));
	float b=fog_noise((p-drift*0.65)*19.0-vec2(0.0,TIME*0.035));
	vec3 paint=texture(art,UV+vec2(a-0.5,b-0.5)*0.012).rgb;
	vec3 color=mix(vec3(0.10,0.29,0.28),vec3(0.25,0.46,0.38),a*0.65+b*0.35);
	color=mix(color,paint,0.22);
	float s=pos.x+pos.z,t=-pos.x+pos.z;
	vec4 d=vec4(0.5-s,0.5+s,0.5-t,0.5+t)*0.7071;
	vec4 shore=(vec4(1.0)-smoothstep(vec4(0.0),vec4(0.11),d))*banks;
	float bank=max(max(shore.x,shore.y),max(shore.z,shore.w));
	color=mix(color,vec3(0.41,0.51,0.36),bank*0.5);
	float ripple=smoothstep(0.82,0.94,sin((a+b)*15.0-TIME*1.1)*0.5+0.5);
	color+=vec3(0.12,0.16,0.12)*ripple*(0.12+bank*0.35);
	float gray=dot(color,vec3(0.299,0.587,0.114));
	ALBEDO=mix(vec3(gray),color,saturation)*brightness;
}
