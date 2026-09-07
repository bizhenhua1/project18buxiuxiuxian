shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back;
uniform vec4 tint : source_color = vec4(0.7,0.9,0.6,1.0);
uniform float body_depth = 1.15;
uniform float head_depth = 0.24;
uniform bool unified = false;
uniform sampler2D prop_art : filter_linear;
uniform vec4 prop_rect;
uniform vec2 view_size;
varying vec3 local_position;
varying vec3 local_normal;
void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}
void fragment() {
	float below_top = body_depth * 0.5 - local_position.y;
	if (below_top >= head_depth || local_normal.y < -0.5) discard;
	float fade = 1.0 - smoothstep(0.0,head_depth,below_top);
	float along_face = abs(local_normal.x) > 0.5 ? abs(local_position.z) : abs(local_position.x);
	bool top = local_normal.y > 0.5;
	if (unified && top) discard;
	// Visibility comes from a translucent wash, not a graphic border.
	float gray = dot(tint.rgb,vec3(0.299,0.587,0.114));
	vec3 rich_color = clamp(mix(vec3(gray),tint.rgb,1.65)*1.12,vec3(0.0),vec3(1.0));
	float corner = smoothstep(0.339,0.35355339,along_face);
	float opacity = top ? 0.34 : mix(0.48,0.56,corner);
	vec3 color = mix(rich_color, min(rich_color*1.10,vec3(1.0)),top ? 1.0 : fade);
	ALBEDO = color;
	ALPHA = opacity*(top ? 1.0 : fade)*tint.a;
	if (unified) {
		vec2 uv = (SCREEN_UV*view_size-prop_rect.xy)/max(prop_rect.zw,vec2(1.0));
		if (all(greaterThanEqual(uv,vec2(0.0))) && all(lessThanEqual(uv,vec2(1.0)))) ALPHA *= 1.0-texture(prop_art,uv).a;
	}
}
