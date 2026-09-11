shader_type spatial;
render_mode unshaded, cull_back, depth_prepass_alpha;

uniform sampler2D art : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool textured = true;
uniform bool themed_art = false;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
uniform float depth = 1.15;
uniform float top_height = 0.0;
uniform vec2 grid_origin = vec2(0.0);
uniform float edge_softness = 0.085;
uniform float fade_height = 0.85;
uniform float fog_reveal = 1.0;
uniform vec2 fog_origin;
#include "res://shaders/island_fog_field.gdshaderinc"
varying vec3 stone_position;
varying vec3 stone_normal;

void vertex() {
	stone_position = VERTEX;
	stone_normal = NORMAL;
}
void fragment() {
	float below_top = depth * 0.5 - stone_position.y;
	// Local box axes coincide with grid columns/rows before the map rotates.
	float horizontal = abs(stone_normal.x) > 0.5 ? stone_position.z + grid_origin.y : stone_position.x + grid_origin.x;
	vec2 rock_uv = vec2(horizontal, top_height - below_top) * 1.6;
	float rock = dot(texture(art, rock_uv).rgb, vec3(0.299, 0.587, 0.114));
	vec3 color = tint.rgb * (themed_art ? texture(art, rock_uv).rgb : vec3(1.0));
	if (textured && abs(stone_normal.y) < 0.5) {
		color *= themed_art ? vec3(1.0) : vec3(clamp(0.62 + rock * 3.2, 0.65, 1.65));
		float soil = 1.0 - smoothstep(0.025, 0.19, below_top);
		color = mix(color, tint.rgb * 0.82, soil * (themed_art ? 0.0 : 0.65));
		color *= mix(1.0, 0.68, smoothstep(0.45, 1.0, below_top / depth));

	}
	// Rounded lighting at the rim keeps the exact grid footprint sealed.
	vec3 half_size = vec3(0.35355339, depth * 0.5, 0.35355339);
	vec3 rounded_normal = normalize(sign(stone_position) * max(abs(stone_position) - (half_size - vec3(edge_softness)), vec3(0.00001)));
	vec3 world_normal = normalize((MODEL_MATRIX * vec4(rounded_normal, 0.0)).xyz);
	color *= 0.72 + 0.28 * max(0.0, dot(world_normal, normalize(vec3(-1.0, 0.5, 1.0))));
	float gray = dot(color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(gray), color, saturation) * brightness;
	float above_bottom = depth - below_top;
	float dissolve = smoothstep(0.02, fade_height, above_bottom + (rock - 0.3) * 0.12);
	ALPHA = dissolve;
	if (fog_reveal < 1.0) {
		// Undo the body's 45-degree local rotation to meet the top's field exactly.
		vec2 cap = vec2(stone_position.x+stone_position.z,-stone_position.x+stone_position.z)*0.70710678+fog_origin;
		float drop = max(0.0,below_top);
		vec2 curl = vec2(sin(drop*5.0+fog_density(cap,TIME)*3.0),drop*1.2)*drop*0.25;
		vec2 p = cap+curl;
		float density = fog_density(p,TIME);
		vec3 mist = fog_color(p,TIME)*clamp(brightness,0.72,1.22);
		mist *= 1.0-0.24*smoothstep(0.015,0.55,drop);
		float fringe = 1.0-smoothstep(0.13,0.62+0.18*density,drop);
		float reveal = smoothstep(0.0,1.0,fog_reveal);
		ALBEDO = mix(mist,ALBEDO,reveal);
		ALPHA = mix(fringe*dissolve,dissolve,reveal);
	}
}
