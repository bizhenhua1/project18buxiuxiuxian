shader_type spatial;
render_mode unshaded, cull_back, depth_prepass_alpha;

uniform sampler2D art : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool textured = true;
uniform float brightness = 1.0;
uniform float saturation = 1.0;
uniform float depth = 1.15;
uniform float top_height = 0.0;
uniform vec2 grid_origin = vec2(0.0);
uniform float edge_softness = 0.085;
uniform float fade_height = 0.85;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float material_row = 0.0;
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
	// Preserve A geometry, directional shading and bottom fade; change albedo only.
	float u = fract(horizontal / 0.70710678 + 0.5);
	// Square swatches use equal world density on both axes, never stretch with depth.
	float v = 1.0 - abs(mod(below_top / 0.70710678, 2.0) - 1.0);
	vec2 atlas_uv = vec2(u,v);
	vec3 color = texture(atlas,atlas_uv).rgb;
	color *= mix(1.0, 0.68, smoothstep(0.45, 1.0, below_top / depth));
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
}
