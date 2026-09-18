class_name CorridorView
extends Control

var renderer: CorridorRenderer
var ground: ColorRect
var ground_material: ShaderMaterial

func setup(art: ForestArt, world: ForestWorld, mode: int, font: Font) -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground = ColorRect.new()
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://shaders/ground.gdshader")
	ground_material.set_shader_parameter("ground_tex", art.textures["ground-tile"])
	ground.material = ground_material
	add_child(ground)
	renderer = CorridorRenderer.new()
	renderer.art = art
	renderer.world = world
	renderer.study_mode = mode
	renderer.font = font
	renderer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(renderer)

func sync(camera: Vector2, heading: float, elapsed: float, movement: float, branch: int, labels: bool, bob: bool, _route_distance: float = 0.0) -> void:
	# Hidden legacy drawing may still supply the native presenter's camera state.
	# Visibility suppresses rendering, never publication of the route transform.
	if not renderer:
		return
	renderer.view_size = size
	renderer.camera_world = camera
	renderer.heading = heading
	renderer.elapsed = elapsed
	renderer.movement = movement
	renderer.selected = branch
	renderer.show_landmarks = labels
	renderer.bob_enabled = bob
	sync_projection()
func sync_projection() -> void:
	# Ground and vegetation consume the very same finalized projection values.
	renderer.view_size=size
	ground_material.set_shader_parameter("resolution",size)
	ground_material.set_shader_parameter("camera_world",renderer.camera_world)
	ground_material.set_shader_parameter("heading",renderer.heading)
	ground_material.set_shader_parameter("focal",renderer.focal())
	ground_material.set_shader_parameter("horizon",renderer.horizon_y()/maxf(size.y,1))
	renderer.queue_redraw()
