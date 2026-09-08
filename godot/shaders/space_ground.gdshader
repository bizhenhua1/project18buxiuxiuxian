shader_type canvas_item;
#include "res://shaders/lantern_atmosphere.gdshaderinc"
render_mode unshaded;
uniform sampler2D floor0 : repeat_enable, filter_linear_mipmap;
uniform sampler2D floor1 : repeat_enable, filter_linear_mipmap;
uniform sampler2D floor2 : repeat_enable, filter_linear_mipmap;
uniform sampler2D ceiling_texture : repeat_enable, filter_linear_mipmap;
uniform vec4 floor_tints[3];
uniform vec4 depth_colors[3];
uniform bool textured[3];
uniform vec4 regions[12]; // start, end, branch, type slot
uniform int region_count = 0;
uniform float blend_lengths[12];
uniform vec2 resolution;
uniform vec2 camera_world;
uniform float heading;
uniform bool straight_route = false;
uniform bool three_way = false;
uniform float junction=700.0;
uniform float turn_length=420.0;
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
    if(straight_route)return abs(p.x);
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
    if (straight_route) return vec2(world.y,0.0);
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
        vec3 tex = slot == 0 ? texture(floor0,world/145.0).rgb : (slot == 1 ? texture(floor1,world/145.0).rgb : texture(floor2,world/145.0).rgb);
        ground = tex * floor_tints[slot].rgb;
        if(ecology) {
            // Broad habitat modulation in world space breaks the identical tile rhythm.
            float habitat=.5+.25*sin(world.x*.018+sin(world.y*.011))+.25*sin(world.y*.025+world.x*.008);
            vec3 alternate=texture(floor0,world/231.0+vec2(.37,.61)).rgb;
            ground=mix(ground,alternate*floor_tints[slot].rgb,.28+.22*habitat);
            ground*=mix(vec3(.75,.88,.79),vec3(1.04,.96,.87),habitat);
        }
    }
    return mix(ground,depth_colors[slot].rgb,smoothstep(300.0,1700.0,z));
}
void fragment() {
    float y = UV.y;
    if(y <= horizon){
        COLOR = mix(sky_top, sky_bottom, smoothstep(0.0, horizon, y));
        if(lantern_enabled)COLOR.rgb*=vec3(.28,.35,.44);
        if(biome_kind==1){
            // Continuous world-space ceiling behind the layered rock silhouettes.
            // Use the opaque rock band of the existing shell, never its transparent mouth.
            float roof_height=245.0;
            float z=min(1700.0,(roof_height-camera_height)*focal/max(.2,(horizon-y)*resolution.y));
            float x=(UV.x-.5)*resolution.x*z/focal;
            vec2 world=camera_world+vec2(cos(heading)*x+sin(heading)*z,-sin(heading)*x+cos(heading)*z);
            vec2 rock_uv=vec2(fract(world.x/72.0)*.16,fract(world.y/72.0)*.12);
            vec3 rock=texture(ceiling_texture,rock_uv).rgb*.48;
            COLOR=vec4(lantern_atmosphere(rock,vec3(world.x,roof_height,world.y),z),1.0);
        }
    }
    else {
        float z = camera_height*focal/max(0.2, (y-horizon)*resolution.y);
        float x = (UV.x-0.5)*resolution.x*z/focal;
        vec2 world = camera_world + vec2(cos(heading)*x+sin(heading)*z, -sin(heading)*x+cos(heading)*z);
        if(ecology) {
            // Same shallow surface as the sprite feet; solve ray/surface intersection.
            float ray=max(.2,(y-horizon)*resolution.y)/focal;
            float camera_level=camera_height+terrain_height(camera_world);
            float lo=(camera_level-3.5*terrain_amplitude)/ray;
            float hi=(camera_level+3.5*terrain_amplitude)/ray;
            for(int step=0;step<12;step++) {
                z=(lo+hi)*.5;
                x=(UV.x-.5)*resolution.x*z/focal;
                world=camera_world+vec2(cos(heading)*x+sin(heading)*z,-sin(heading)*x+cos(heading)*z);
                if(camera_level-z*ray>terrain_height(world))lo=z;else hi=z;
            }
        }
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
        COLOR = vec4(color,1.0);
    }
}
