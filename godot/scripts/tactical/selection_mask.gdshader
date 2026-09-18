shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_opaque;
uniform sampler2D base_texture : source_color,filter_linear_mipmap;
uniform bool textured=false;
uniform float opacity=1.0;
#include "res://scripts/world3d/portrait_projection.gdshaderinc"
void vertex(){POSITION=portrait_position(VERTEX,MODELVIEW_MATRIX,PROJECTION_MATRIX,VIEW_MATRIX);}
void fragment(){
 if(opacity<.1 || (textured && texture(base_texture,UV).a*opacity<.3))discard;
 ALBEDO=vec3(1.0);
}
