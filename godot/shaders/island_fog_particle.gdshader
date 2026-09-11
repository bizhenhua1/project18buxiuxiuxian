shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
	float mask=pow(max(0.0,1.0-length((UV-0.5)*2.0)),2.0);
	ALBEDO=vec3(0.52,0.64,0.59);
	ALPHA=mask*COLOR.a*0.72;
}
