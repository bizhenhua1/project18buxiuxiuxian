shader_type canvas_item;
render_mode skip_vertex_transform;
#include "res://shaders/lantern_atmosphere.gdshaderinc"
varying vec3 lighting_point;
uniform vec2 camera_world;
uniform vec2 canvas_origin;
uniform vec2 canvas_scale;
uniform vec2 viewport_size;
uniform float heading;
uniform float focal;
uniform float horizon;
uniform float eye;
uniform float terrain_amplitude;
uniform vec4 atlas_regions[64];
uniform vec4 fog_color : source_color;
uniform vec2 fog_range;
varying vec4 tint;
varying float depth;
uniform bool edge_only=false;
varying vec2 art_uv;
varying float mist_patch;
varying float mist_seed;
float terrain(vec2 p){return (2.2*sin(p.y*.009)+1.3*sin(p.x*.017+p.y*.004))*terrain_amplitude;}
void vertex(){
    vec2 p=INSTANCE_CUSTOM.xy;
    vec2 d=p-camera_world;
    float z=dot(d,vec2(sin(heading),cos(heading)));
    float x=dot(d,vec2(cos(heading),-sin(heading)));
    vec2 offset=((MODEL_MATRIX*vec4(VERTEX,0,1)).xy-canvas_origin)/canvas_scale;
    float scale=focal/max(z,1.0);
    float altitude=INSTANCE_CUSTOM.z+terrain(p)-terrain(camera_world);
    vec2 ground_point=p+vec2(cos(heading),-sin(heading))*offset.x;
    lighting_point=vec3(ground_point.x,INSTANCE_CUSTOM.z-offset.y,ground_point.y);
    VERTEX=vec2(viewport_size.x*.5+(x+offset.x)*scale,horizon+(eye-altitude+offset.y)*scale);
    VERTEX=VERTEX*canvas_scale+canvas_origin;
    tint=COLOR;
    if(z<=10.0 || z>=1700.0){VERTEX=vec2(-10000);tint.a=0.0;}
    tint.a*=1.0-smoothstep(1400.0,1700.0,z);
    depth=z;
    mist_patch=step(64.0,INSTANCE_CUSTOM.w);
    mist_seed=sin(p.x*.3+p.y*.11)*10.0;
    vec4 region=atlas_regions[int(mod(INSTANCE_CUSTOM.w,64.0))];
    art_uv=vec2(UV.x,1.0-UV.y);
    // QuadMesh uses upward Y for UVs; the corridor canvas uses downward Y.
    UV=region.xy+vec2(UV.x,1.0-UV.y)*region.zw;
}
float fog_hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float fog_noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(fog_hash(i),fog_hash(i+vec2(1,0)),f.x),mix(fog_hash(i+vec2(0,1)),fog_hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
    vec4 tex=texture(TEXTURE,UV);
    if(mist_patch>.5){
        vec2 q=art_uv*2.0-1.0;
        float shape=1.0-smoothstep(.20,1.0,dot(q,q));
        float cloud=.65*fog_noise(art_uv*vec2(5,3)+vec2(atmosphere_time*.07,mist_seed))+.35*fog_noise(art_uv*vec2(11,7)-vec2(atmosphere_time*.06,mist_seed));
        float density=smoothstep(.2,.75,cloud)*shape*.46;
        vec3 d=lighting_point-lantern_position;
        vec3 e=lighting_point-enemy_light_position;
        float warm=exp(-dot(d,d)/11025.0);
        float cold=exp(-dot(e,e)/10000.0)*enemy_light_strength;
        vec3 mist_color=vec3(.24,.31,.33)+vec3(.42,.25,.075)*warm+vec3(.16,.27,.32)*cold;
        COLOR=vec4(mist_color,density*tint.a);
    }else if(edge_only){
        vec2 pixel=vec2(length(dFdx(UV)),length(dFdy(UV)))*2.2;
        float rim=tex.a-min(min(texture(TEXTURE,UV+vec2(pixel.x,0)).a,texture(TEXTURE,UV-vec2(pixel.x,0)).a),min(texture(TEXTURE,UV+vec2(0,pixel.y)).a,texture(TEXTURE,UV-vec2(0,pixel.y)).a));
        float flow=.55+.25*sin(art_uv.y*32.0-art_uv.x*18.0-TIME*3.8)+.2*sin(art_uv.y*61.0+TIME*2.1);
        float fade=1.0-smoothstep(.48,.96,art_uv.y);
        COLOR=vec4(.82,.035,.065,clamp(rim*flow*fade*1.4,0.0,.8)*tint.a);
    }else{
    vec3 shaded=mix(tex.rgb*tint.rgb,fog_color.rgb,smoothstep(fog_range.x,fog_range.y,depth)*.94);
    if(lantern_enabled)shaded=lantern_atmosphere(shaded,lighting_point,depth);
    COLOR=vec4(shaded,tex.a*tint.a);
    }
}
