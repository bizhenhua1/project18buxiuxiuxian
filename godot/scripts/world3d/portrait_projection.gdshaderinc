uniform vec3 portrait_anchor=vec3(0.0);
uniform float portrait_weight=0.0;
uniform float portrait_vertical_offset=0.0;
uniform mat4 portrait_near_view;
uniform vec3 portrait_near_params=vec3(0.0);
vec4 portrait_position(vec3 local_vertex,mat4 model_view,mat4 projection,mat4 view_matrix){
 vec4 view=model_view*vec4(local_vertex,1.0);
 vec4 clip=projection*view;
 vec4 anchor_view=view_matrix*vec4(portrait_anchor,1.0);
 vec4 anchor_clip=projection*anchor_view;
 if(anchor_clip.w>.05 && clip.w>.05){
  vec2 offset=vec2(projection[0][0],projection[1][1])*(view.xy-anchor_view.xy)/anchor_clip.w;
  vec2 weak_ndc=anchor_clip.xy/anchor_clip.w+offset+vec2(0.0,projection[1][1]*portrait_vertical_offset/anchor_clip.w);
  if(portrait_near_params.x>0.0){
   vec3 q=(portrait_near_view*view).xyz;
   if(q.z<-.05){
    vec2 near_offset=vec2(q.x/-q.z,q.y/-q.z-portrait_near_params.z)*portrait_near_params.y;
    vec2 near_ndc=anchor_clip.xy/anchor_clip.w+vec2(projection[0][0],projection[1][1])*near_offset/anchor_clip.w;
    weak_ndc=mix(weak_ndc,near_ndc,portrait_near_params.x);
   }
  }
  clip.xy=mix(clip.xy,weak_ndc*clip.w,portrait_weight);
 }
 return clip;
}
