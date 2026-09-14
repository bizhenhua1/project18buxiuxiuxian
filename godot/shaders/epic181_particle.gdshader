shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D art:source_color,filter_linear_mipmap;
uniform vec4 tint:source_color=vec4(1.0);
uniform vec2 tiles=vec2(1.0);
uniform float gain=1.0;
uniform vec2 uv_scale=vec2(1);
uniform vec2 uv_offset=vec2(0);
// A particle's sheet frame is discrete; interpolating it can turn N into
// N-epsilon and floor() then samples the preceding tile inside a triangle.
varying flat float tile_index;
uniform bool gpu_curves_enabled=false;
uniform highp sampler2D particle_curves:filter_nearest,repeat_disable;
uniform vec4 curve_counts=vec4(1.0);
uniform vec4 particle_start_min=vec4(1.0);
uniform vec4 particle_start_max=vec4(1.0);
vec4 curve_at(float t,float count,int row){
 float index=clamp(t,0.0,1.0)*max(0.0,count-1.0);
 int lo=int(index);int hi=min(int(count)-1,lo+1);
 return mix(texelFetch(particle_curves,ivec2(lo,row),0),texelFetch(particle_curves,ivec2(hi,row),0),index-float(lo));
}
void vertex(){
 tile_index=INSTANCE_CUSTOM.r;
 if(gpu_curves_enabled && INSTANCE_CUSTOM.a>=0.0){
  // Compatibility custom attributes lose precision: send age as high + residual.
  // Initial size stays in the instance transform. Random-size curves use CPU.
  float t=INSTANCE_CUSTOM.g+INSTANCE_CUSTOM.b/2048.0;
  float size=curve_at(t,curve_counts.x,0).r;
  VERTEX*=max(INSTANCE_CUSTOM.a,size);
  float random=(round(COLOR.r*255.0)*256.0+round(COLOR.g*255.0))/65535.0;
  COLOR=mix(particle_start_min,particle_start_max,random)*mix(curve_at(t,curve_counts.z,1),curve_at(t,curve_counts.w,2),random);
 }
}
void fragment(){
 vec2 cell=vec2(mod(floor(tile_index),tiles.x),floor(tile_index/tiles.x));
 vec4 tex=texture(art,((UV*uv_scale+uv_offset)+cell)/tiles);
 ALBEDO=tex.rgb*COLOR.rgb*tint.rgb*gain;
 ALPHA=clamp(tex.a*COLOR.a*tint.a*gain,0.0,1.0);
}
