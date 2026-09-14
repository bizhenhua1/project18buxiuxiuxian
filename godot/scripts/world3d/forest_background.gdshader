shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
#include "res://shaders/lantern_atmosphere.gdshaderinc"
uniform vec4 sky_top;
uniform vec4 sky_bottom;
uniform float horizon=.235;
uniform float far_distance=110.0;
uniform vec4 far_ground;
uniform vec2 camera_world;
uniform vec2 resolution;
uniform float heading=0.0;
uniform float camera_height=38.0;
uniform float focal=640.0;
void vertex(){
 vec4 far_clip=PROJECTION_MATRIX*vec4(0.0,0.0,-far_distance*.999,1.0);
 POSITION=vec4(VERTEX.xy*far_clip.w,far_clip.z,far_clip.w);
}
void fragment(){
 vec3 color=mix(sky_top.rgb,sky_bottom.rgb,smoothstep(0.0,max(.001,horizon),SCREEN_UV.y));
 if(lantern_enabled)color*=vec3(.28,.35,.44);
 if(SCREEN_UV.y>horizon){
  // Beyond the finite mesh, the original floor has already reached its
  // depth color. Preserve that field rather than exposing blue sky below it.
  float z=camera_height*focal/max(.2,(SCREEN_UV.y-horizon)*resolution.y);
  float x=(SCREEN_UV.x-.5)*resolution.x*z/focal;
  vec2 world=camera_world+vec2(cos(heading)*x+sin(heading)*z,-sin(heading)*x+cos(heading)*z);
  color=far_ground.rgb;
  if(lantern_enabled)color=lantern_atmosphere(color,vec3(world.x,0.0,world.y),z);
 }
 ALBEDO=color;
}
