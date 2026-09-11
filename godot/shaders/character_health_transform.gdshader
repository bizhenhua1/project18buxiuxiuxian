shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled, depth_prepass_alpha;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform bool textured = true;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 shadow_color : source_color = vec4(.15,.20,.26,1);
uniform float threshold = .45;
uniform float softness = .06;
uniform float ambient = .25;
uniform float environment_fill = 0.0;
uniform vec4 environment_fill_color : source_color = vec4(.596,.686,.749,1.0);
uniform float saturation = .8;
uniform int style = 1;
uniform float ink = .3;
uniform float health_progress=0.0;
uniform int health_mode=0;
uniform vec4 health_color : source_color=vec4(.3,.9,.85,1.0);
uniform float health_opacity=.4;
uniform float health_energy=1.5;
uniform int material_style=0;
#include "res://shaders/transformation_pattern.gdshaderinc"
varying vec2 screen_uv;
#include "res://shaders/transformation_edge.gdshaderinc"
void fragment(){
 vec4 tex=base_color;
 if(textured)tex*=texture(base_texture,UV);
 if(tex.a<.3)discard;
 vec3 color=mix(vec3(dot(tex.rgb,vec3(.299,.587,.114))),tex.rgb,saturation);
 ALBEDO=color;
 ROUGHNESS=1.0;
 // Explicit fill keeps stylized shading while making the team ambient control effective.
 EMISSION=color*(shadow_color.rgb*ambient+environment_fill_color.rgb*environment_fill*.25);
 screen_uv=FRAGCOORD.xy;
 float line=mix(-.02,1.02,health_progress);
 float h=UV2.x;
 bool below=health_progress>=1.0 || (health_progress>0.0 && h<line);
 if(health_mode==1 && below)discard;
 float weight=health_progress>=1.0?1.0:health_progress<=0.0?0.0:smoothstep(-.025,.025,line-h);
 if(health_mode==1)weight=0.0;
 float fres=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),1.8);
 float scan=occult_pattern(UV,h,TIME,material_style);
 ALBEDO=mix(ALBEDO,health_color.rgb*.55,weight);
 EMISSION=mix(EMISSION,health_color.rgb*(.45+fres)*scan*health_energy,weight);
 ALPHA=mix(1.0,health_opacity+fres*(1.0-health_opacity)*.5,weight);
 vec2 edge=transformation_edge(h,line,health_progress);
 vec3 edge_core=mix(health_color.rgb,vec3(1.0),0.8);
 ALBEDO=mix(ALBEDO,edge_core,edge.x);
 EMISSION+=(edge_core*edge.x*3.0+health_color.rgb*edge.y*1.4)*max(1.0,health_energy);
 ALPHA=max(ALPHA,max(edge.x*0.98,edge.y*0.65));
 if(material_style>0)ALPHA=max(ALPHA,weight*scan*.85);
}
void light(){
 float n=max(dot(NORMAL,LIGHT),0.0);
 float shade=smoothstep(threshold-softness,threshold+softness,n);
 if(style==2){
  float middle=smoothstep(.18,.26,n)*.38;
  shade=max(middle,shade);
  float hatch=step(.72,fract((screen_uv.x+screen_uv.y)*.13));
  shade*=1.0-hatch*ink*(1.0-shade);
 }else if(style==3){
  shade=mix(n,smoothstep(.15,.8,n),.55);
 }
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*mix(shadow_color.rgb*.2,vec3(1.0),shade)/3.14159265;
}
