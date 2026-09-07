shader_type canvas_item;
#include "res://shaders/lantern_atmosphere.gdshaderinc"
render_mode unshaded;
uniform sampler2D floor0 : repeat_enable, filter_linear_mipmap;
uniform sampler2D floor1 : repeat_enable, filter_linear_mipmap;
uniform sampler2D floor2 : repeat_enable, filter_linear_mipmap;
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

vec2 route_coordinate(vec2 world) {
    if (straight_route) return vec2(world.y,0.0);
    float branch = world.x < 0.0 ? -1.0 : 1.0;
    float s = world.y;
    if (world.y < 700.0) branch = 0.0;
    else {
        vec2 end = vec2(branch*840.0*(1.0-cos(0.5)),700.0+840.0*sin(0.5));
        s = max(700.0,1120.0+dot(world-end,vec2(branch*sin(0.5),cos(0.5))));
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
        for(int i=0; i<12; i++) {
            if(i >= region_count) break;
            float span = max(1.0,blend_lengths[i]);
            if(regions[i].z == coordinate.y && abs(coordinate.x-regions[i].x) < span) {
                int before = slot_at(vec2(regions[i].x-0.01,coordinate.y));
                float weight = smoothstep(regions[i].x-span,regions[i].x+span,coordinate.x);
                color = mix(floor_color(before,world,z),floor_color(int(regions[i].w),world,z),weight);
            }
        }
        if(lantern_enabled)color=lantern_atmosphere(color,vec3(world.x,0.0,world.y),z);
        COLOR = vec4(color,1.0);
    }
}
