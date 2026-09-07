shader_type spatial;
render_mode unshaded,cull_disabled,depth_prepass_alpha;
uniform sampler2D prop_art : filter_linear_mipmap;
uniform bool has_prop = false;
uniform vec4 prop_rect;
uniform vec2 top_points[4];
uniform vec2 bottom_points[4];
uniform float top_depths[4];
uniform float bottom_depths[4];
uniform float prop_depth;
uniform vec2 field_size;
uniform vec2 origin;
uniform float brightness = 1.0;
uniform float clearing = 0.0;
uniform float fade_start;
uniform float fade_end;
#include "res://shaders/island_fog_field.gdshaderinc"
float cross2(vec2 a,vec2 b) { return a.x*b.y-a.y*b.x; }
float quad_mask(vec2 p,vec2 a,vec2 b,vec2 c,vec2 d) {
	vec4 s=vec4(cross2(b-a,p-a),cross2(c-b,p-b),cross2(d-c,p-c),cross2(a-d,p-d));
	return (all(greaterThanEqual(s,vec4(-0.00001))) || all(lessThanEqual(s,vec4(0.00001)))) ? 1.0 : 0.0;
}
float face_depth(vec2 p,vec2 a,vec2 b,vec2 d,float za,float zb,float zd) {
	vec2 u=b-a,v=d-a,q=p-a;
	float det=cross2(u,v);
	if (abs(det)<0.0000001) return 1000.0;
	return za+cross2(q,v)/det*(zb-za)+cross2(u,q)/det*(zd-za);
}
void fragment() {
	float mask=quad_mask(UV,top_points[0],top_points[1],top_points[2],top_points[3]);
	float scene_depth=1000.0;
	if (mask>0.0) scene_depth=face_depth(UV,top_points[0],top_points[1],top_points[3],top_depths[0],top_depths[1],top_depths[3]);
	for (int i=0;i<4;i++) {
		int j=(i+1)%4;
		float side=quad_mask(UV,top_points[i],top_points[j],bottom_points[j],bottom_points[i]);
		mask=max(mask,side);
		if (side>0.0) scene_depth=min(scene_depth,face_depth(UV,top_points[i],top_points[j],bottom_points[i],top_depths[i],top_depths[j],bottom_depths[i]));
	}
	if (has_prop) {
		vec2 uv=(UV-prop_rect.xy)/prop_rect.zw;
		if (all(greaterThanEqual(uv,vec2(0.0))) && all(lessThanEqual(uv,vec2(1.0)))) {
			float silhouette=texture(prop_art,uv).a;
			mask=max(mask,silhouette);
			if (silhouette>0.01) scene_depth=min(scene_depth,prop_depth);
		}
	}
	vec2 p=UV*field_size+origin;
	float n=fog_density(p,TIME);
	float fringe=1.0-smoothstep(fade_start,fade_end,UV.y+(n-0.5)*0.035);
	float cover=1.0-smoothstep(n*0.22,0.8+n*0.2,clearing);
	if (clearing<=0.0) cover=1.0;
	if (clearing>=1.0) cover=0.0;
	ALBEDO=fog_color(p,TIME)*clamp(brightness,0.72,1.22);
	ALPHA=mask*fringe*cover;
	if (ALPHA<0.001) discard;
	vec4 clip=PROJECTION_MATRIX*vec4(0.0,0.0,-scene_depth+0.002,1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	DEPTH=clip.z/clip.w*0.5+0.5;
#else
	DEPTH=clip.z/clip.w;
#endif
}
