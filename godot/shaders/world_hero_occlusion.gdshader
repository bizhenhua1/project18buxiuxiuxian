shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled;
uniform sampler2D actor_mask : source_color, repeat_disable, filter_nearest;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec2 pixel_size=vec2(0.001);
void vertex(){ POSITION=vec4(VERTEX.xy,0.0,1.0); }
void fragment(){
 vec3 mask=texture(actor_mask,SCREEN_UV).rgb;
 if(mask.b<0.5) discard;
 float depth=texture(scene_depth,SCREEN_UV).r;
 vec3 ndc=vec3(SCREEN_UV*2.0-1.0,depth);
 #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
 ndc.z=depth*2.0-1.0;
 #endif
 vec4 scene=INV_PROJECTION_MATRIX*vec4(ndc,1.0);
 float actor_distance=(mask.r+mask.g/255.0)*100.0;
 float behind=actor_distance+scene.z/scene.w;
 if(behind<0.07) discard;
 float inside=1.0;
 for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
  inside=min(inside,texture(actor_mask,SCREEN_UV+vec2(float(x),float(y))*pixel_size*2.0).b);
 }
 float rim=1.0-step(0.5,inside);
 ALBEDO=vec3(0.43,0.77,0.84);
 ALPHA=mix(0.09,0.85,rim)*smoothstep(0.07,0.13,behind);
}
