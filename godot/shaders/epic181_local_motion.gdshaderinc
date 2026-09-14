uniform mat4 motion_emitter;
uniform mat4 motion_inverse;
uniform mat3 motion_billboard;
uniform mat3 motion_mesh;
uniform bool motion_mesh_mode=false;
uniform vec2 motion_rotation=vec2(0.0);
uniform float motion_age=0.0;
uniform bool motion_current_state=false;
uniform bool motion_local=true;
uniform bool motion_stretch=false;
uniform vec2 motion_stretch_parameters=vec2(1,0);
uniform bool motion_noise_enabled=false;
uniform sampler2D motion_noise_curve : filter_nearest, repeat_disable;
uniform vec2 motion_noise_counts=vec2(1);
float motion_noise_sample(float t,float random){
 vec2 index=clamp(t,0.0,1.0)*(motion_noise_counts-vec2(1));
 ivec2 left=ivec2(floor(index));ivec2 right=min(left+ivec2(1),ivec2(motion_noise_counts)-ivec2(1));
 float low=mix(texelFetch(motion_noise_curve,ivec2(left.x,0),0).r,texelFetch(motion_noise_curve,ivec2(right.x,0),0).r,fract(index.x));
 float high=mix(texelFetch(motion_noise_curve,ivec2(left.y,0),0).g,texelFetch(motion_noise_curve,ivec2(right.y,0),0).g,fract(index.y));
 return mix(low,high,random)*.025;
}
void vertex(){
 // Instance matrix carries immutable spawn data at full transform precision.
 mat4 data=motion_inverse*MODEL_MATRIX;
 float elapsed=motion_current_state?data[1].x:max(0.0,motion_age-data[1].x);
 float life=max(.01,data[1].y);float t=clamp(elapsed/life,0.0,1.0);
 float random=data[2].y;tile_index=round(data[2].z);
 float angle=data[2].x+(motion_current_state?0.0:mix(motion_rotation.x,motion_rotation.y,random)*elapsed);
 float c=cos(angle);float s=sin(angle);
 mat3 turn=mat3(vec3(c,s,0),vec3(-s,c,0),vec3(0,0,1));
 mat3 frame=motion_mesh_mode?turn*motion_mesh:motion_billboard*turn;
 float size=max(.001,data[1].z*mix(curve_at(t,curve_counts.x,0).r,curve_at(t,curve_counts.y,0).g,random));
 float noise_amount=motion_current_state?data[0].x:(motion_noise_enabled?motion_noise_sample(t,random):0.0);
 vec3 noise=vec3(0);
 if(noise_amount!=0.0)noise=vec3(sin(elapsed*13.0+random*12.0),cos(elapsed*17.0+random*6.0),sin(elapsed*11.0))*noise_amount;
 vec3 center=data[3].xyz+(motion_current_state?vec3(0):data[0].xyz*elapsed);
 vec3 offset=frame*VERTEX*size;
 // Basis.scaled in the CPU reference scales the frame's rows, not the
 // particle's local Y axis. Match that operation before adding local noise.
 if(motion_stretch)offset.y*=max(1.0,motion_stretch_parameters.x+motion_stretch_parameters.y*data[0].y/size);
 offset+=noise;
 vec4 world=motion_local?motion_emitter*vec4(center+offset,1.0):vec4(center+mat3(motion_emitter)*offset,1.0);
 VERTEX=(VIEW_MATRIX*world).xyz;
 NORMAL=vec3(0,0,1);
 COLOR=mix(particle_start_min,particle_start_max,random)*mix(curve_at(t,curve_counts.z,1),curve_at(t,curve_counts.w,2),random);
 // CPU ownership decides expiry; a second float32 lifetime comparison can
 // hide a short-lived particle one frame earlier at an exact boundary.
}
