shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform, depth_draw_never;
#include "res://shaders/lantern_atmosphere.gdshaderinc"
uniform sampler2D art : source_color, filter_linear_mipmap;
uniform vec4 fog_color : source_color=vec4(.06,.09,.13,1);
uniform vec2 fog_range=vec2(240,1400);
uniform float heading=0.0;
uniform float terrain_amplitude=1.0;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float intersection_softness=.45;
varying vec3 point;
varying float depth;
varying vec4 tint;
varying float patch_seed;
varying float category;
void vertex(){
 category=INSTANCE_CUSTOM.w;
 patch_seed=sin(MODEL_MATRIX[3].x*20.0*.3-MODEL_MATRIX[3].z*20.0*.11)*10.0;
 vec2 size=vec2(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz));
 vec2 p=(VERTEX.xy+vec2(.5-INSTANCE_CUSTOM.x,INSTANCE_CUSTOM.y-.5))*size;
 p.x*=INSTANCE_CUSTOM.z;
 vec3 world=MODEL_MATRIX[3].xyz+vec3(cos(heading),0,sin(heading))*p.x+vec3(0,p.y,0);
 vec2 anchor=vec2(MODEL_MATRIX[3].x,-MODEL_MATRIX[3].z)*20.0;
 float terrain=(2.2*sin(anchor.y*.009)+1.3*sin(anchor.x*.017+anchor.y*.004))*terrain_amplitude;
 float altitude=MODEL_MATRIX[3].y*20.0-terrain;
 point=vec3(world.x*20.0,altitude+p.y*20.0,-world.z*20.0);
 VERTEX=(VIEW_MATRIX*vec4(world,1)).xyz;depth=-VERTEX.z*20.0;tint=COLOR;
}
float fog_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float fog_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(fog_hash(i),fog_hash(i+vec2(1,0)),f.x),mix(fog_hash(i+vec2(0,1)),fog_hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 if(depth<=10.0 || depth>=1700.0)discard;
 if(category==2.0){
  float d=length(UV-.5)*2.0;
  ALBEDO=vec3(.48,.78,1.0);ALPHA=(exp(-d*d*10.0)+.4*exp(-d*d*3.0))*tint.a;
 }else if(category==4.0){
  float shape=(1.0-smoothstep(.1,.5,abs(UV.x-.5)))*sin(UV.y*3.14159);
  ALBEDO=biome_kind==4?vec3(.53,.18,.20):biome_kind==3?vec3(.30,.46,.26):vec3(.42,.61,.64);
  ALPHA=shape*tint.a;
 }else{
 vec2 uv=UV;vec2 q=uv*2.0-1.0;
 float seed=patch_seed;
 float shape=1.0-smoothstep(.20,1.0,dot(q,q));
 float cloud=.65*fog_noise(uv*vec2(5,3)+vec2(atmosphere_time*.07,seed))+.35*fog_noise(uv*vec2(11,7)-vec2(atmosphere_time*.06,seed));
 float density=smoothstep(.2,.75,cloud)*shape*.46;
 vec3 d=point-lantern_position;
 float warm=exp(-dot(d,d)/max(team_light_radius*team_light_radius*1.64,1.0))*team_light_energy;
 vec3 color=environment_mist(vec3(.24,.31,.33))+vec3(.24,.17,.075)*team_light_color.rgb*warm;
 if(biome_kind<2)color=vec3(.24,.31,.33)+vec3(.42,.25,.075)*team_light_color.rgb*warm;
 float sampled=texture(scene_depth,SCREEN_UV).r;
 vec3 ndc=vec3(SCREEN_UV*2.0-1.0,sampled);
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 ndc.z=sampled*2.0-1.0;
 #endif
 vec4 surface=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
 float gap=-surface.z/surface.w-depth/20.0;
 float contact=intersection_softness>0.0?smoothstep(0.0,intersection_softness,gap):1.0;
 ALBEDO=color;ALPHA=density*tint.a*contact;
 }
}
