shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform, depth_prepass_alpha;
#include "res://shaders/lantern_atmosphere.gdshaderinc"
uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 fog_color : source_color=vec4(.06,.09,.13,1);
uniform vec2 fog_range=vec2(240,1400);
uniform float heading=0.0;
uniform float terrain_amplitude=1.0;
uniform float cave_branch_side=0.0;
uniform float cave_handoff=0.0;
uniform float rock_contact[17];
uniform float base_contact[17];
float ground_height(vec2 p){return (2.2*sin(p.y*.009)+1.3*sin(p.x*.017+p.y*.004))*terrain_amplitude/20.0;}
#include "res://scripts/world3d/triangle_support.gdshaderinc"
uniform bool precise_ground_contact=false;
varying vec3 point;
varying float depth;
varying vec4 tint;
varying float luminous;
varying float near_fade;
varying float root_clearance;
varying float root_blend;
varying float root_band;
varying float junction_bridge;
void vertex(){
 vec2 size=vec2(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz));
 vec2 p=(VERTEX.xy+vec2(.5-INSTANCE_CUSTOM.x,INSTANCE_CUSTOM.y-.5))*size;
 p.x*=sign(INSTANCE_CUSTOM.z);
 float mode=abs(INSTANCE_CUSTOM.z);
 junction_bridge=step(128.0,mode);mode-=junction_bridge*128.0;
 float cave_arch=step(64.0,mode);mode-=cave_arch*64.0;
 float root_cover=step(32.0,mode);mode-=root_cover*32.0;
 float shell=step(16.0,mode);mode-=shell*16.0;
 luminous=step(8.0,mode);mode-=luminous*8.0;
 float center_depth=-(VIEW_MATRIX*MODEL_MATRIX[3]).z*20.0;
 near_fade=mix(smoothstep(16.0,70.0,center_depth),smoothstep(18.0,95.0,center_depth),shell);
 // The ring must fade before its side wall sweeps across the turning camera.
 near_fade=mix(near_fade,smoothstep(18.0,90.0,center_depth),cave_arch);
 if(center_depth>=1700.0)near_fade=0.0;
 if(root_cover>.5 && (mode==1.0 || mode==3.0 || mode==6.0)){
  vec3 parent_limit=MODEL_MATRIX[3].xyz+vec3(0.0,INSTANCE_CUSTOM.w,0.0);
  vec4 limit_clip=PROJECTION_MATRIX*VIEW_MATRIX*vec4(parent_limit,1.0);
  // Match parent visibility, with a narrow fade instead of a hard pop.
  near_fade*=smoothstep(-1.03,-1.0,limit_clip.y/max(.001,limit_clip.w));
 }
 float plane_angle=(mode==2.0 || mode==4.0 || mode==5.0 || mode==7.0)?INSTANCE_CUSTOM.w:heading;
 if(mode==5.0){
  float column=clamp(UV.x*16.0,0.0,16.0);int a=int(floor(column));int b=min(a+1,16);
  float foot=mix(rock_contact[a],rock_contact[b],fract(column));
  float foot_weight=smoothstep(max(0.0,foot-.25),foot,UV.y);
  p.y+=(foot-INSTANCE_CUSTOM.y)*size.y*foot_weight;
 }
 vec3 world=MODEL_MATRIX[3].xyz+vec3(cos(plane_angle),0,sin(plane_angle))*p.x+vec3(0,p.y,0);
 float altitude=MODEL_MATRIX[3].y-ground_height(vec2(MODEL_MATRIX[3].x,-MODEL_MATRIX[3].z)*20.0);
 // Off-center root foliage keeps its silhouette and its parent-relative placement,
 // but stands on the terrain beneath its own center, including when mirrored.
 if(root_cover>.5 && mode<6.0){
  float offset=(.5-INSTANCE_CUSTOM.x)*size.x*sign(INSTANCE_CUSTOM.z);
  vec3 support=MODEL_MATRIX[3].xyz+vec3(cos(plane_angle),0,sin(plane_angle))*offset;
  world.y+=ground_height(vec2(support.x,-support.z)*20.0)-ground_height(vec2(MODEL_MATRIX[3].x,-MODEL_MATRIX[3].z)*20.0);
 }
 if(mode>=3.0 && mode<=5.0){
  world+=vec3(-sin(plane_angle),0,cos(plane_angle))*max(-p.y,0.0)*1.6;
  // The floor is a 1 m triangulated grid. A tiny support clearance covers its
  // interpolation error relative to the analytic height, avoiding coplanar loss.
  float support_clearance=.001+.0025*abs(terrain_amplitude);
  if(precise_ground_contact)world.y=triangle_support(world.xz)+altitude+max(p.y,0.0)+.001;
  else world.y=ground_height(vec2(world.x,-world.z)*20.0)+altitude+max(p.y,0.0)+support_clearance;
 }
 if(mode>=6.0){
  float column=clamp(UV.x*16.0,0.0,16.0);int a=int(floor(column));int b=min(a+1,16);
  float foot=(INSTANCE_CUSTOM.y-mix(base_contact[a],base_contact[b],fract(column)))*size.y;
  float displacement=ground_height(vec2(world.x,-world.z)*20.0)+altitude-(MODEL_MATRIX[3].y+foot);
  // Wider correction bands for low anchors prevent the raised base from
  // folding over the unchanged upper mesh (smoothstep slope is at most 1.5).
  float band=max(max(.08,size.y*.08),abs(displacement)*2.0);
  world.y+=displacement*(1.0-smoothstep(0.0,band,max(p.y-foot,0.0)));
 }
 // The formal lighting field uses height above the sprite's local ground,
 // including signed artwork below the anchor. Ground footprints alone clamp it.
 root_blend=(mode>=6.0 && root_cover<.5)?1.0:0.0;
 root_band=clamp(size.x*.025,.06,.18);
 root_clearance=1.0;
 if(root_blend>.5)root_clearance=world.y-ground_height(vec2(world.x,-world.z)*20.0);
 float light_altitude=(mode==2.0 || mode==4.0 || mode==5.0 || mode==7.0)?0.0:altitude;
 point=vec3(world.x*20.0,(light_altitude+(mode>=3.0?max(0.0,p.y):p.y))*20.0,-world.z*20.0);
 VERTEX=(VIEW_MATRIX*vec4(world,1)).xyz;depth=-VERTEX.z*20.0;tint=COLOR;
}
void fragment(){
 vec4 tex=texture(art,UV)*tint;
 float fade=near_fade*(1.0-smoothstep(1400.0,1700.0,depth));
 if(tex.a<=0.0)discard;
 // Preserve the formal renderer's fractional alpha during near-camera fading.
 // Alpha scissor makes surviving fragments opaque and defeats that fade.
 // A short world-space contact transition removes the cut-off artwork edge.
 // Covers and upright loose foliage retain their original silhouettes.
 // Artwork-space variation stays attached to the tree under camera rotation.
 // Keep a short opaque-base transition, widening only for large cutouts.
 float root_edge=.75+.15*sin(UV.x*173.0)+.10*sin(UV.x*419.0+1.7);
 ALPHA=tex.a*fade*mix(1.0,smoothstep(0.0,root_band*root_edge,root_clearance),root_blend);
 if(junction_bridge>.5 && abs(cave_branch_side)>.5){
  // Preserve only the outer wing of the shared arch after taking a turn.
  // Its inner wing is the wall that used to block the selected tunnel.
  float outer=cave_branch_side>0.0?1.0-smoothstep(.45,.56,UV.x):smoothstep(.44,.55,UV.x);
  ALPHA*=mix(1.0,outer,cave_handoff);
 }
 vec3 surface=environment_surface(tex.rgb,point,UV);
 vec3 shaded=mix(surface,fog_color.rgb,smoothstep(fog_range.x,fog_range.y,depth)*.94);
 if(lantern_enabled)shaded=lantern_atmosphere(shaded,point,depth);
 if(luminous>.5){
  vec3 original=texture(art,UV).rgb;
  float bright=max(original.r,max(original.g,original.b));
  shaded=mix(shaded,original*1.3,smoothstep(.38,.85,bright)*.85);
 }
 ALBEDO=shaded;
}
