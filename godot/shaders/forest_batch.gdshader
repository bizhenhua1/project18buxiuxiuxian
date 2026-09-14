shader_type canvas_item;
render_mode skip_vertex_transform;
#include "res://shaders/lantern_atmosphere.gdshaderinc"
varying vec3 lighting_point;
uniform sampler2D live_ally_0 : filter_linear;
uniform sampler2D live_ally_1 : filter_linear;
uniform sampler2D live_ally_2 : filter_linear;
uniform sampler2D live_ally_3 : filter_linear;
uniform sampler2D live_ally_4 : filter_linear;
uniform sampler2D live_ally_5 : filter_linear;
uniform sampler2D live_ally_6 : filter_linear;
uniform sampler2D live_ally_7 : filter_linear;
uniform sampler2D live_ally_8 : filter_linear;
varying float ally_texture_slot;
uniform float character_fill=0.0;
uniform float character_brightness_cap=.78;
uniform sampler2D crowd_atlas : filter_linear;
varying float crowd_slot;
uniform sampler2D near_atlas : filter_linear;
varying float near_slot;
uniform sampler2D live_character : filter_linear;
uniform sampler2D live_companion : filter_linear;
uniform sampler2D live_enemy : filter_linear;
uniform sampler2D live_discovery : filter_linear;
uniform vec3 edge_color=vec3(.82,.035,.065);
uniform bool discovery_edge=false;
varying float is_live_character;
uniform vec2 camera_world;
uniform vec2 dynamic_positions[256];
uniform vec2 canvas_origin;
uniform vec2 canvas_scale;
uniform vec2 viewport_size;
uniform float heading;
uniform float focal;
uniform float horizon;
uniform float eye;
uniform float terrain_amplitude;
uniform vec4 atlas_regions[64];
uniform float rock_contact[9];
uniform vec4 fog_color : source_color;
uniform vec2 fog_range;
varying vec4 tint;
varying float depth;
uniform bool edge_only=false;
varying vec2 art_uv;
varying float mist_patch;
varying float mist_seed;
varying vec2 uv_over_depth;
varying float inverse_depth;
varying vec4 art_region;
float terrain(vec2 p){return (2.2*sin(p.y*.009)+1.3*sin(p.x*.017+p.y*.004))*terrain_amplitude;}
void vertex(){
    float category=floor(INSTANCE_CUSTOM.w/64.0);
    near_slot=category>=105.0 && category<120.0?category-105.0:-1.0;
    crowd_slot=category>=25.0 && category<105.0?category-25.0:-1.0;
    ally_texture_slot=category>=16.0 && category<=24.0?category-16.0:-1.0;
    bool dynamic_actor=near_slot>=0.0 || crowd_slot>=0.0 || ally_texture_slot>=0.0 || category==1.0 || category==2.0 || category==4.0 || category==5.0 || category==12.0 || category==13.0 || category==14.0 || category==15.0;
    vec2 d=dynamic_actor?dynamic_positions[int(INSTANCE_CUSTOM.x)]:INSTANCE_CUSTOM.xy-camera_world;
    vec2 p=dynamic_actor?camera_world+d:INSTANCE_CUSTOM.xy;
    float z=dot(d,vec2(sin(heading),cos(heading)));
    float center_depth=z;
    float x=dot(d,vec2(cos(heading),-sin(heading)));
    vec2 offset=((MODEL_MATRIX*vec4(VERTEX,0,1)).xy-canvas_origin)/canvas_scale;
    is_live_character=category==15.0?4.0:category==14.0?3.0:category==13.0?2.0:(category==12.0?1.0:0.0);
    if(near_slot>=0.0 || crowd_slot>=0.0 || ally_texture_slot>=0.0 || category==12.0 || category==13.0 || category==14.0 || category==15.0)category=5.0;
    if(category==9.0){
        float column=clamp(UV.x*8.0,0.0,8.0);
        int a=int(floor(column));int b=min(a+1,8);
        float contact=mix(rock_contact[a],rock_contact[b],fract(column));
        offset.y+=(.92-contact)*length(MODEL_MATRIX[1].xy/canvas_scale);
    }
    bool grounded=biome_kind==1 && (category>=9.0 || category==6.0 || category==3.0);
    vec2 right=vec2(cos(heading),-sin(heading));
    float base_altitude=category>=9.0?0.0:INSTANCE_CUSTOM.z;
    if(category>=9.0){float angle=INSTANCE_CUSTOM.z;right=vec2(cos(angle),-sin(angle));}
    vec2 ground_point=p+right*offset.x;
    if(grounded){
        // The artwork below its marked contact line is a ground footprint, not a hanging vertical skirt.
        ground_point-=vec2(-right.y,right.x)*max(offset.y,0.0)*1.6;
        offset.y=min(offset.y,0.0);
        d=ground_point-camera_world;
        z=dot(d,vec2(sin(heading),cos(heading)));
        x=dot(d,vec2(cos(heading),-sin(heading)));
    }
    float scale=focal/max(z,10.0);
    float altitude=base_altitude+terrain(p)-terrain(camera_world);
    if(category==8.0 || grounded)altitude=base_altitude+terrain(ground_point)-terrain(camera_world);
    lighting_point=vec3(ground_point.x,base_altitude-offset.y,ground_point.y);
    VERTEX=vec2(viewport_size.x*.5+(x+(grounded?0.0:offset.x))*scale,horizon+(eye-altitude+offset.y)*scale);
    VERTEX=VERTEX*canvas_scale+canvas_origin;
    tint=COLOR;
    if(center_depth<=10.0 || center_depth>=1700.0)tint.a=0.0;
    // Keep clipped vertices finite: moving one vertex offscreen stretches its triangles across the view.
    tint.a*=1.0-smoothstep(1400.0,1700.0,z);
    depth=z;
    mist_patch=category;
    // Complete the fade before the hard near plane, including luminous props and shells.
    if(mist_patch==6.0 || mist_patch==3.0 || mist_patch==0.0 || mist_patch>=10.0)tint.a*=smoothstep(16.0,70.0,center_depth);
    if(mist_patch==8.0 || mist_patch==9.0)tint.a*=smoothstep(18.0,95.0,center_depth);
    mist_seed=sin(p.x*.3+p.y*.11)*10.0;
    vec4 region=atlas_regions[int(mod(INSTANCE_CUSTOM.w,64.0))];
    art_uv=vec2(UV.x,1.0-UV.y);
    inverse_depth=1.0/max(z,10.0);
    uv_over_depth=art_uv*inverse_depth;
    art_region=region;
    // QuadMesh uses upward Y for UVs; the corridor canvas uses downward Y.
    UV=region.xy+vec2(UV.x,1.0-UV.y)*region.zw;
}
float fog_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float fog_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(fog_hash(i),fog_hash(i+vec2(1,0)),f.x),mix(fog_hash(i+vec2(0,1)),fog_hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
    if(depth<=10.0 || depth>=1700.0)discard;
    vec2 projected_uv=uv_over_depth/max(inverse_depth,.000001);
    vec4 tex=is_live_character>3.5?texture(live_discovery,projected_uv):is_live_character>2.5?texture(live_companion,projected_uv):is_live_character>1.5?texture(live_enemy,projected_uv):(is_live_character>.5?texture(live_character,projected_uv):texture(TEXTURE,art_region.xy+projected_uv*art_region.zw));
    if(ally_texture_slot==0.0)tex=texture(live_ally_0,projected_uv);
    else if(ally_texture_slot==1.0)tex=texture(live_ally_1,projected_uv);
    else if(ally_texture_slot==2.0)tex=texture(live_ally_2,projected_uv);
    else if(ally_texture_slot==3.0)tex=texture(live_ally_3,projected_uv);
    else if(ally_texture_slot==4.0)tex=texture(live_ally_4,projected_uv);
    else if(ally_texture_slot==5.0)tex=texture(live_ally_5,projected_uv);
    else if(ally_texture_slot==6.0)tex=texture(live_ally_6,projected_uv);
    else if(ally_texture_slot==7.0)tex=texture(live_ally_7,projected_uv);
    else if(ally_texture_slot==8.0)tex=texture(live_ally_8,projected_uv);
    if(crowd_slot>=0.0){
        vec2 tile=vec2(mod(crowd_slot,5.0),floor(crowd_slot/5.0));
        vec2 safe_uv=clamp(projected_uv,vec2(.002),vec2(.998));
        tex=texture(crowd_atlas,(tile+safe_uv)/vec2(5.0,16.0));
    }
    if(near_slot>=0.0){
        vec2 tile=vec2(mod(near_slot,5.0),floor(near_slot/5.0));
        tex=texture(near_atlas,(tile+clamp(projected_uv,vec2(.001),vec2(.999)))/vec2(5.0,3.0));
    }
    if(mist_patch>6.5 && mist_patch<7.5){
        float edge=1.0-smoothstep(.22,.5,abs(art_uv.x-.5));
        float falling=art_uv.y*8.0-atmosphere_time*3.2;
        float stream=pow(.5+.5*sin(art_uv.x*29.0+.65*sin(falling)),3.0);
        stream*=.65+.35*fog_noise(vec2(art_uv.x*8.0,falling));
        vec3 water=mix(vec3(.10,.20,.11),vec3(.30,.43,.27),stream);
        water=lantern_atmosphere(water,lighting_point,depth);
        COLOR=vec4(water,edge*.86*tint.a*(1.0-smoothstep(.9,1.0,art_uv.y))*(edge_only?0.0:1.0));
    }else if(mist_patch>3.5 && mist_patch<4.5){
        float shape=(1.0-smoothstep(.1,.5,abs(art_uv.x-.5)))*sin(art_uv.y*3.14159);
        vec3 drop=biome_kind==4?vec3(.53,.18,.20):biome_kind==3?vec3(.30,.46,.26):vec3(.42,.61,.64);
        COLOR=vec4(drop,shape*tint.a*(edge_only?0.0:1.0));
    }else if(mist_patch>1.5 && mist_patch<2.5){
        float d=length(art_uv-.5)*2.0;
        COLOR=vec4(.48,.78,1.0,(exp(-d*d*10.0)+.4*exp(-d*d*3.0))*tint.a*(edge_only?0.0:1.0));
    }else if(mist_patch>.5 && mist_patch<1.5){
        vec2 q=art_uv*2.0-1.0;
        float shape=1.0-smoothstep(.20,1.0,dot(q,q));
        float cloud=.65*fog_noise(art_uv*vec2(5,3)+vec2(atmosphere_time*.07,mist_seed))+.35*fog_noise(art_uv*vec2(11,7)-vec2(atmosphere_time*.06,mist_seed));
        float density=smoothstep(.2,.75,cloud)*shape*.46;
        vec3 d=lighting_point-lantern_position;
        vec3 e=lighting_point-enemy_light_position;
        float warm=exp(-dot(d,d)/max(team_light_radius*team_light_radius*1.64,1.0))*team_light_energy;
        float cold=exp(-dot(e,e)/10000.0)*enemy_light_strength;
        vec3 mist_color=environment_mist(vec3(.24,.31,.33))+vec3(.24,.17,.075)*team_light_color.rgb*warm+vec3(.08,.12,.16)*enemy_scene_tint.rgb*cold;
        if(biome_kind<2)mist_color=vec3(.24,.31,.33)+vec3(.42,.25,.075)*team_light_color.rgb*warm+vec3(.16,.27,.32)*enemy_scene_tint.rgb*cold;
        COLOR=vec4(mist_color,density*tint.a);
    }else if(edge_only){
        vec2 pixel=vec2(length(dFdx(UV)),length(dFdy(UV)))*2.2;
        float rim=tex.a-min(min(texture(TEXTURE,UV+vec2(pixel.x,0)).a,texture(TEXTURE,UV-vec2(pixel.x,0)).a),min(texture(TEXTURE,UV+vec2(0,pixel.y)).a,texture(TEXTURE,UV-vec2(0,pixel.y)).a));
        if(is_live_character>1.5 && is_live_character<2.5){
            vec2 pixel_live=vec2(length(dFdx(projected_uv)),length(dFdy(projected_uv)))*2.2;
            rim=step(.5,tex.a)-step(.5,min(min(texture(live_enemy,projected_uv+vec2(pixel_live.x,0)).a,texture(live_enemy,projected_uv-vec2(pixel_live.x,0)).a),min(texture(live_enemy,projected_uv+vec2(0,pixel_live.y)).a,texture(live_enemy,projected_uv-vec2(0,pixel_live.y)).a)));
        }
        if(is_live_character>3.5){
            vec2 px=vec2(length(dFdx(projected_uv)),length(dFdy(projected_uv)))*2.2;
            rim=step(.5,tex.a)-step(.5,min(min(texture(live_discovery,projected_uv+vec2(px.x,0)).a,texture(live_discovery,projected_uv-vec2(px.x,0)).a),min(texture(live_discovery,projected_uv+vec2(0,px.y)).a,texture(live_discovery,projected_uv-vec2(0,px.y)).a)));
        }
        float flow=.55+.25*sin(art_uv.y*32.0-art_uv.x*18.0-TIME*3.8)+.2*sin(art_uv.y*61.0+TIME*2.1);
        float fade=1.0-smoothstep(.48,.96,art_uv.y);
        COLOR=vec4(edge_color,clamp(rim*(discovery_edge?1.0:flow)*fade*1.4,0.0,.8)*tint.a);
    }else{
    vec3 surface=tex.rgb*tint.rgb;
    if(mist_patch<.5 || (mist_patch>2.5 && mist_patch<3.5) || mist_patch==6.0 || mist_patch>=8.0)surface=environment_surface(surface,lighting_point,art_uv);
    vec3 shaded=mix(surface,fog_color.rgb,smoothstep(fog_range.x,fog_range.y,depth)*.94);
    if(lantern_enabled)shaded=lantern_atmosphere(shaded,lighting_point,depth);
    if((mist_patch>2.5 && mist_patch<3.5) || mist_patch==11.0){
        float bright=max(tex.r,max(tex.g,tex.b));
        shaded=mix(shaded,tex.rgb*1.3,smoothstep(.38,.85,bright)*.85);
    }
    if(character_fill>0.0 && (near_slot>=0.0 || crowd_slot>=0.0 || ally_texture_slot>=0.0 || is_live_character>.5)){
        float distance_fade=1.0-smoothstep(140.0,420.0,depth);
        vec3 fill=surface*vec3(.83,.93,1.0)*character_fill*distance_fade;
        shaded=min(max(shaded,fill),vec3(character_brightness_cap));
    }
    COLOR=vec4(shaded,tex.a*tint.a);
    }
}
