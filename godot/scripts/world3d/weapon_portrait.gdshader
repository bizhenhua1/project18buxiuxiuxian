shader_type spatial;
render_mode cull_disabled;
#include "res://scripts/world3d/portrait_projection.gdshaderinc"
uniform vec4 base_color:source_color=vec4(1.0);
uniform sampler2D base_texture:source_color;
uniform bool textured=false;
uniform float roughness=.8;
uniform float metallic=0.0;
uniform float actor_opacity=1.0;
void vertex(){POSITION=portrait_position(VERTEX,MODELVIEW_MATRIX,PROJECTION_MATRIX,VIEW_MATRIX);}
void fragment(){
 if(fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453)>=actor_opacity)discard;
 vec4 color=base_color;
 if(textured)color*=texture(base_texture,UV);
 if(color.a<.3)discard;
 ALBEDO=color.rgb;ROUGHNESS=roughness;METALLIC=metallic;
}
