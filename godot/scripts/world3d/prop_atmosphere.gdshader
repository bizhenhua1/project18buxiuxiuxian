shader_type spatial;
render_mode unshaded,cull_disabled,depth_prepass_alpha;
#include "res://shaders/lantern_atmosphere.gdshaderinc"
uniform sampler2D art:source_color,filter_linear_mipmap;
uniform vec4 region_tint:source_color=vec4(1.0);
uniform vec4 fog_color:source_color=vec4(.06,.09,.13,1);
uniform vec2 fog_range=vec2(240,1400);
uniform float clearance=0.0;
uniform float opacity=1.0;
varying vec3 lighting_point;
varying float depth;
void vertex(){
 vec3 anchor=MODEL_MATRIX[3].xyz;
 vec3 right=normalize(vec3(INV_VIEW_MATRIX[0].x,0.0,INV_VIEW_MATRIX[0].z));
 vec3 world=anchor+right*VERTEX.x+vec3(0.0,VERTEX.y,0.0);
 lighting_point=vec3(world.x*20.0,clearance+VERTEX.y*20.0,-world.z*20.0);
 depth=-(VIEW_MATRIX*vec4(anchor,1.0)).z*20.0;
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(world,1.0);
}
void fragment(){
 vec4 tex=texture(art,UV);
 vec3 color=tex.rgb*region_tint.rgb;
 color=mix(color,fog_color.rgb,smoothstep(fog_range.x,fog_range.y,depth)*.94);
 if(lantern_enabled)color=lantern_atmosphere(color,lighting_point,depth);
 ALBEDO=color;
 ALPHA=tex.a*opacity*(1.0-smoothstep(1400.0,1700.0,depth));
}
