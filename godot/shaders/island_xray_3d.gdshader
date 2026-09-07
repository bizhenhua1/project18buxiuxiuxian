shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest;
uniform sampler2D art : source_color, filter_linear_mipmap;
uniform bool textured = false;
uniform vec4 tint : source_color = vec4(0.7,0.9,0.6,1.0);
void fragment() {
	float mask = textured ? texture(art,UV).a : 1.0;
	float depth = texture(scene_depth,SCREEN_UV).r;
	// Reconstruct view depth rather than assuming either forward or reverse Z.
	vec3 sampled_ndc = vec3(SCREEN_UV*2.0-1.0,depth);
	vec3 own_ndc = vec3(SCREEN_UV*2.0-1.0,FRAGCOORD.z);
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		sampled_ndc.z = depth*2.0-1.0;
		own_ndc.z = FRAGCOORD.z*2.0-1.0;
	#endif
	vec4 sampled_view = INV_PROJECTION_MATRIX*vec4(sampled_ndc,1.0);
	vec4 own_view = INV_PROJECTION_MATRIX*vec4(own_ndc,1.0);
	float occluded = step(-sampled_view.z/sampled_view.w+0.003,-own_view.z/own_view.w);
	ALBEDO = tint.rgb;
	ALPHA = mask*occluded*0.2;
}
