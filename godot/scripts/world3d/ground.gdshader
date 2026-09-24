shader_type spatial;
#include "res://shaders/fairytale_floor.gdshaderinc"
#include "res://shaders/lantern_atmosphere.gdshaderinc"
render_mode unshaded, cull_disabled;
uniform sampler2D floor0 : repeat_enable, filter_linear_mipmap;
uniform sampler2D floor1 : repeat_enable, filter_linear_mipmap;
uniform sampler2D floor2 : repeat_enable, filter_linear_mipmap;
uniform vec4 floor_tints[3];
uniform vec4 depth_colors[3];
uniform bool textured[3];
uniform bool seam_blend_floor[3];
uniform vec4 regions[12]; // start, end, branch, type slot
uniform int region_count = 0;
uniform float blend_lengths[12];
uniform vec2 resolution;
uniform vec2 camera_world;
uniform float heading;
uniform bool straight_route = false;
uniform bool three_way = false;
uniform bool cave_fork = false;
uniform float cave_half_sep = 265.0;
uniform float junction=700.0;
uniform float turn_length=420.0;
uniform vec2 route_origin=vec2(0.0);
uniform float route_origin_s=0.0;
uniform float route_origin_heading=0.0;
// At most three adjacent immutable route segments: old, active, prepared.
uniform int segment_count=0;
uniform vec4 segment_frames[3]; // world origin xy, heading, absolute start
uniform vec4 segment_shapes[3]; // junction, signed turn length (negative=cave), end, exits
float cave_x(float y,float j,float transfer,float side){
 float t=clamp((y-j)/transfer,0.0,1.0);
 return side*cave_half_sep*t*t*(3.0-2.0*t);
}
float cave_lane(vec2 p,float j,float transfer,float end_s,float exits){
 float best=length(p-vec2(0.0,clamp(p.y,0.0,j)));
 if(exits>2.5)best=min(best,abs(p.x));
 for(int i=0;i<2;i++){
  float side=i==0?-1.0:1.0;
  float y=clamp(p.y,j,j+transfer);
  // Project to the smooth sideways transfer, then to its parallel tail.
  for(int step=0;step<3;step++){
   float t=clamp((y-j)/transfer,0.0,1.0);
   float x=cave_x(y,j,transfer,side);
   float dx=side*cave_half_sep*6.0*t*(1.0-t)/transfer;
   float ddx=side*cave_half_sep*(6.0-12.0*t)/(transfer*transfer);
   float delta=(y-p.y)+(x-p.x)*dx;
   y=clamp(y-delta/max(0.2,1.0+dx*dx+(x-p.x)*ddx),j,j+transfer);
  }
  best=min(best,length(p-vec2(cave_x(y,j,transfer,side),y)));
  best=min(best,length(p-vec2(side*cave_half_sep,clamp(p.y,j+transfer,end_s))));
 }
 return best;
}
float segment_lane(vec2 world,int index){
 vec4 frame=segment_frames[index];vec4 shape=segment_shapes[index];
 vec2 delta=world-frame.xy;float c=cos(frame.z);float s=sin(frame.z);
 vec2 p=vec2(delta.x*c-delta.y*s,delta.x*s+delta.y*c);
 float j=shape.x-frame.w;float end_s=shape.z-frame.w;
 if(shape.y<0.0)return cave_lane(p,j,-shape.y,end_s,shape.w);
 float best=length(p-vec2(0,clamp(p.y,0.0,j)));
 if(shape.w>2.5)best=min(best,length(p-vec2(0,clamp(p.y,0.0,end_s))));
 float r=shape.y/.5;
 for(int side_index=0;side_index<2;side_index++){
  float side=side_index==0?-1.0:1.0;
  vec2 d=p-vec2(side*r,j);
  float a=clamp(atan(d.y,-side*d.x),0.0,.5);
  best=min(best,length(p-vec2(side*r*(1.0-cos(a)),j+r*sin(a))));
  vec2 end=vec2(side*r*(1.0-cos(.5)),j+r*sin(.5));
  vec2 tangent=vec2(side*sin(.5),cos(.5));
  float t=clamp(dot(p-end,tangent),0.0,max(0.0,shape.z-shape.x-shape.y));
  best=min(best,length(p-end-tangent*t));
 }
 return best;
}
vec2 route_local(vec2 p){
 vec2 d=p-route_origin;float c=cos(route_origin_heading);float s=sin(route_origin_heading);
 return vec2(d.x*c-d.y*s,d.x*s+d.y*c+route_origin_s);
}
uniform bool ecology = false;
uniform float terrain_amplitude = 1.0;
uniform float focal;
uniform float camera_height = 58.0;
uniform float horizon;
uniform vec4 sky_top;
uniform vec4 sky_bottom;

float terrain_height(vec2 p) {
    return (2.2*sin(p.y*.009)+1.3*sin(p.x*.017+p.y*.004))*terrain_amplitude;
}
// Same circular transition and tangent as ForestRoute; floor and props share lanes.
float lane_distance(vec2 p) {
    if(segment_count>0){
        float best=1e20;
        for(int i=0;i<3;i++){
            if(i>=segment_count)break;
            best=min(best,segment_lane(p,i));
        }
        return best;
    }
    p=route_local(p);
    if(straight_route)return abs(p.x);
    if(cave_fork)return cave_lane(p,junction,turn_length,100000.0,three_way?3.0:2.0);
    float radius=turn_length/.5;
    float best=p.y<=junction || three_way?abs(p.x):length(p-vec2(0,junction));
    for(int i=0;i<2;i++){
        float side=i==0?-1.0:1.0;
        vec2 delta=p-vec2(side*radius,junction);
        float a=atan(delta.y,-side*delta.x);
        if(a>=0.0 && a<=.5)best=min(best,abs(length(delta)-radius));
        vec2 end=vec2(side*radius*(1.0-cos(.5)),junction+radius*sin(.5));
        vec2 dir=vec2(side*sin(.5),cos(.5));
        best=min(best,length(p-end-dir*max(0.0,dot(p-end,dir))));
    }
    return best;
}

vec2 route_coordinate(vec2 world) {
    world=route_local(world);
    if (straight_route) return vec2(world.y,0.0);
    if (cave_fork) return vec2(world.y,world.y<junction?0.0:(world.x<0.0?-1.0:1.0));
    float branch = world.x < 0.0 ? -1.0 : 1.0;
    float s = world.y;
    if (world.y < junction) branch = 0.0;
    else {
        float radius=turn_length/.5;
        vec2 end = vec2(branch*radius*(1.0-cos(0.5)),junction+radius*sin(0.5));
        s = max(junction,junction+turn_length+dot(world-end,vec2(branch*sin(0.5),cos(0.5))));
        if(three_way && abs(world.x)<abs(world.x-end.x-(world.y-end.y)*branch*tan(.5))){branch=2.0;s=world.y;}
    }
    return vec2(s,branch);
}
int slot_at(vec2 coordinate) {
    int slot = 0;
    float last = -1e10;
    for (int i=0; i<12; i++) {
        if(i >= region_count) break;
        if(regions[i].z == coordinate.y && coordinate.x >= regions[i].x && regions[i].x >= last) {
            slot = int(regions[i].w);
            last = regions[i].x;
        }
    }
    return slot;
}
vec3 floor_color(int slot, vec2 world, float z) {
    vec3 ground = depth_colors[slot].rgb;
    if(textured[slot]) {
        vec2 floor_uv=world/(biome_kind>=6?80.0:145.0);
        vec3 tex = slot == 0 ? fairytale_floor_sample(floor0,floor_uv,seam_blend_floor[slot]) : (slot == 1 ? fairytale_floor_sample(floor1,floor_uv,seam_blend_floor[slot]) : fairytale_floor_sample(floor2,floor_uv,seam_blend_floor[slot]));
        ground = tex * floor_tints[slot].rgb;
        if(ecology && biome_kind<6) {
            // Broad habitat modulation in world space breaks the identical tile rhythm.
            float habitat=.5+.25*sin(world.x*.018+sin(world.y*.011))+.25*sin(world.y*.025+world.x*.008);
            vec3 alternate=texture(floor0,world/231.0+vec2(.37,.61)).rgb;
            ground=mix(ground,alternate*floor_tints[slot].rgb,.28+.22*habitat);
            ground*=mix(vec3(.75,.88,.79),vec3(1.04,.96,.87),habitat);
        }
    }
    return mix(ground,depth_colors[slot].rgb,smoothstep(300.0,1700.0,z));
}
varying vec2 floor_world;
varying float depth3d;
void vertex(){
 vec3 p=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 floor_world=vec2(p.x,-p.z)*20.0;
 VERTEX.y=terrain_height(floor_world)/20.0;
 depth3d=-(VIEW_MATRIX*MODEL_MATRIX*vec4(VERTEX,1)).z*20.0;
}
void fragment(){
 vec2 world=floor_world;float z=depth3d;
        vec2 coordinate = route_coordinate(world);
        vec3 color = floor_color(slot_at(coordinate),world,z);
        if(biome_kind==1 && !straight_route)color*=mix(1.0,.56,smoothstep(48.0,90.0,lane_distance(world)));
        for(int i=0; i<12; i++) {
            if(i >= region_count) break;
            float span = max(1.0,blend_lengths[i]);
            if(regions[i].z == coordinate.y && abs(coordinate.x-regions[i].x) < span) {
                int before = slot_at(vec2(regions[i].x-0.01,coordinate.y));
                float weight = smoothstep(regions[i].x-span,regions[i].x+span,coordinate.x);
                color = mix(floor_color(before,world,z),floor_color(int(regions[i].w),world,z),weight);
            }
        }
        if(biome_kind==2 || biome_kind==3 || biome_kind==4 || biome_kind==5){
            float side=lane_distance(world);
            float bank=biome_kind==3?36.0:biome_kind==5?78.0:80.0+17.0*sin(world.y*.019)+9.0*sin(world.y*.037);
            float wet=smoothstep(bank,bank+10.0,side)*(1.0-smoothstep(160.0,210.0,side));
            float ripple=sin(world.y*.35+world.x*.12-atmosphere_time*1.7)*sin(world.x*.27+atmosphere_time*.9);
            vec3 water=biome_kind==4?vec3(.12,.035,.045):vec3(.035,.095,.04);
            color=mix(color,water+vec3(.025,.035,.029)*ripple,wet*.85);
            if(biome_kind==3){
                float channel=smoothstep(36.0,40.0,side)*(1.0-smoothstep(138.0,145.0,side));
                float foam=pow(.5+.5*sin(world.y*.26-atmosphere_time*3.8+sin(world.x*.14)*2.0),12.0);
                float broken=.4+.6*pow(.5+.5*sin(world.x*.51+world.y*.07),2.0);
                color=mix(color,vec3(.045,.13,.065)+vec3(.24,.34,.18)*foam*broken,channel);
                float rim=1.0-smoothstep(1.0,3.0,abs(side-37.0));
                color=mix(color,vec3(.28,.30,.22),rim*.75);
            }
        }
        color=environment_surface(color,vec3(world.x,0.0,world.y),world/145.0);
        if(lantern_enabled)color=lantern_atmosphere(color,vec3(world.x,0.0,world.y),z);
 ALBEDO=color;
}
