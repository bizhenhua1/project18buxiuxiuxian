shader_type spatial;
render_mode cull_back, depth_prepass_alpha, specular_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.25,0.9,1.0,1.0);
uniform float progress=0.0;
uniform float height_min=0.0;
uniform float height_max=1.9;
uniform float opacity=0.4;
uniform float emission_strength=1.5;
uniform float scan_density=65.0;
uniform int mode=0;
uniform bool skeleton_part=false;
uniform int material_style=0;
#include "res://shaders/transformation_pattern.gdshaderinc"
varying float world_height;
varying float reference_height;
#include "res://shaders/transformation_edge.gdshaderinc"
void vertex(){reference_height=UV2.x;world_height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y;}
void fragment(){
 vec4 original=texture(base_texture,UV)*base_color;
 float line=mix(-0.02,1.02,progress);
 bool below=progress>=1.0 || (progress>0.0 && reference_height<line);
 if(skeleton_part && (!below || mode==0)) discard;
 if(!skeleton_part && mode==1 && below) discard;
 if(original.a<0.2 && !skeleton_part) discard;
 float holo=skeleton_part?1.0:(mode==0?(progress>=1.0?1.0:progress<=0.0?0.0:smoothstep(-0.025,0.025,line-reference_height)):0.0);
 vec2 edge=transformation_edge(reference_height,line,progress);
 float fres=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),1.8);
 float scan=occult_pattern(UV,reference_height,TIME,material_style);
 ALBEDO=mix(original.rgb,glow_color.rgb*0.55,holo);
 EMISSION=glow_color.rgb*holo*(0.45+fres)*scan*emission_strength;
 vec3 edge_core=mix(glow_color.rgb,vec3(1.0),0.8);
 ALBEDO=mix(ALBEDO,edge_core,edge.x);
 EMISSION+=(edge_core*edge.x*3.0+glow_color.rgb*edge.y*1.4)*max(1.0,emission_strength);
 ROUGHNESS=0.9;
 ALPHA=mix(original.a,opacity+fres*(1.0-opacity)*0.5,holo);
 ALPHA=max(ALPHA,max(edge.x*0.98,edge.y*0.65));
 if(material_style>0)ALPHA=max(ALPHA,holo*scan*.85);
}
