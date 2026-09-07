class_name SegmentView
extends CorridorView
func setup(art: ForestArt, world: ForestWorld, mode: int, font: Font) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground = ColorRect.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://shaders/space_ground.gdshader")
	ground_material.set_shader_parameter("ecology",StyleLibrary.active)
	ground_material.set_shader_parameter("terrain_amplitude",ForestSettings.values.height)
	ground.material = ground_material
	add_child(ground)
	var scene := world as SegmentWorld
	ground_material.set_shader_parameter("straight_route",scene.plan.straight)
	var types: Array[SpaceType] = []
	var regions := PackedVector4Array()
	var blends := PackedFloat32Array()
	for region in scene.plan.regions:
		if region.space not in types: types.append(region.space)
		regions.append(Vector4(region.start,region.end,region.branch,types.find(region.space)))
		blends.append(region.blend_length if region.start > 1000 else 0.0)
	ground_material.set_shader_parameter("region_count", regions.size())
	regions.resize(12)
	blends.resize(12)
	ground_material.set_shader_parameter("blend_lengths", blends)
	ground_material.set_shader_parameter("regions", regions)
	var tints := PackedColorArray()
	var colors := PackedColorArray()
	var textured: Array[bool] = []
	for i in range(3):
		var type := types[mini(i,types.size()-1)]
		tints.append(type.ground_tint)
		colors.append(type.atmosphere.depth_color)
		textured.append(type.ground_texture != null)
		ground_material.set_shader_parameter("floor%d" % i, type.ground_texture if type.ground_texture else art.textures["ground-tile"])
	ground_material.set_shader_parameter("floor_tints", tints)
	ground_material.set_shader_parameter("depth_colors", colors)
	ground_material.set_shader_parameter("textured", textured)
	renderer = SegmentRenderer.new()
	renderer.lantern_enabled=StyleLibrary.active
	renderer.art = art
	renderer.world = world
	renderer.study_mode = mode
	renderer.font = font
	renderer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(renderer)
func sync(camera: Vector2, heading: float, elapsed: float, movement: float, branch: int, labels: bool, bob: bool, route_distance: float = 0.0) -> void:
	(renderer.world as SegmentWorld).update_camera(route_distance, branch)
	ground_material.set_shader_parameter("camera_height",(renderer as SegmentRenderer).camera_height())
	var environment := (renderer.world as SegmentWorld).environment()
	ground_material.set_shader_parameter("sky_top", environment.a.top_color.lerp(environment.b.top_color, environment.weight))
	ground_material.set_shader_parameter("sky_bottom", environment.a.atmosphere.haze_color.lerp(environment.b.atmosphere.haze_color, environment.weight))
	super(camera, heading, elapsed, movement, branch, labels, bob, route_distance)
	ground_material.set_shader_parameter("lantern_enabled",renderer.lantern_enabled)
	ground_material.set_shader_parameter("lantern_position",renderer.lantern_position())
	ground_material.set_shader_parameter("enemy_light_position",renderer.enemy_light_position())
	ground_material.set_shader_parameter("enemy_light_strength",renderer.enemy_light_strength())
	ground_material.set_shader_parameter("atmosphere_time",elapsed)
