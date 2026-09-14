shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
#define WORLD3D_SHARED_CLOCK
#include "res://shaders/lantern_atmosphere.gdshaderinc"
#include "res://scripts/world3d/portrait_projection.gdshaderinc"
uniform sampler2D scene_color : hint_screen_texture,filter_nearest;
uniform sampler2D base_texture : source_color,filter_linear_mipmap;
uniform bool textured=true;
uniform float actor_opacity=1.0;
uniform float health_ghost_progress=0.0;
uniform vec4 region_tint : source_color=vec4(1.0);
uniform vec4 fog_color : source_color=vec4(.06,.09,.13,1);
uniform vec2 fog_range=vec2(240,1400);
uniform vec3 actor_anchor;
uniform float actor_clearance=0.0;
varying vec3 lighting_point;
varying float scene_depth;
void vertex(){
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 // A portrait uses one camera-facing lighting plane at the actor's anchor.
 // Match that sampling only when the corresponding projection is selected.
 vec3 right=INV_VIEW_MATRIX[0].xyz;
 vec3 plane=actor_anchor+right*dot(world-actor_anchor,right);
 vec3 sampled=mix(world,plane,portrait_weight);
 lighting_point=vec3(sampled.x*20.0,actor_clearance+(world.y-actor_anchor.y+portrait_vertical_offset*portrait_weight)*20.0,-sampled.z*20.0);
 scene_depth=-(VIEW_MATRIX*vec4(actor_anchor,1)).z*20.0;
 POSITION=portrait_position(VERTEX,MODELVIEW_MATRIX,PROJECTION_MATRIX,VIEW_MATRIX);
}
void fragment(){
 if(health_ghost_progress>0.0 && UV2.x<mix(-.02,1.02,health_ghost_progress)+.025)discard;
 if(fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453)>=actor_opacity)discard;
 if(textured && texture(base_texture,UV).a<.3)discard;
 vec3 color=textureLod(scene_color,SCREEN_UV,0.0).rgb*region_tint.rgb;
 color=mix(color,fog_color.rgb,smoothstep(fog_range.x,fog_range.y,scene_depth)*.94);
 if(lantern_enabled)color=lantern_atmosphere(color,lighting_point,scene_depth);
 ALBEDO=color;ALPHA=1.0;
}
