shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D art:source_color,filter_linear_mipmap;
uniform vec4 tint:source_color=vec4(1.0);
uniform vec2 tiles=vec2(1.0);
uniform float gain=1.0;
uniform vec2 uv_scale=vec2(1);
uniform vec2 uv_offset=vec2(0);
varying float tile_index;
void vertex(){tile_index=INSTANCE_CUSTOM.r;}
void fragment(){
 vec2 cell=vec2(mod(floor(tile_index),tiles.x),floor(tile_index/tiles.x));
 vec4 tex=texture(art,((UV*uv_scale+uv_offset)+cell)/tiles);
 ALBEDO=tex.rgb*COLOR.rgb*tint.rgb*gain;
 ALPHA=clamp(tex.a*COLOR.a*tint.a*gain,0.0,1.0);
}
