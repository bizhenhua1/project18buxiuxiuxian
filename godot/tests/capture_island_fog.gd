extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1000,760)
	root.gui_disable_input = true
	var model := IslandModel.new()
	model.zoom = 1.8
	model.zoom_goal = 1.8
	var view := IslandView3D.new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.setup(model,IslandAssets.new())
	view.world.get_child(0).environment.background_color = Color("172c2d")
	view.set_process(false)
	view._process(0.0)
	var destination := Vector2i(-999,-999)
	for cell in model.cells:
		var key := IslandModel.key(cell)
		if not model.explored.has(key) and model.can_visit(key):
			destination = key
			if cell.feat != null: break
	assert(view.tiles.has(destination))
	var tile: Dictionary = view.tiles[destination]
	assert(not tile.top.visible)
	assert(not tile.body.visible)
	assert(tile.prop == null or not tile.prop.visible)
	assert(tile.fog.material_override.get_shader_parameter("has_prop") == (tile.prop != null))
	DirAccess.make_dir_recursive_absolute("res://captures/island-fog")
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/island-fog/idle.png")
	var count := model.explored.size()
	assert(model.go_to(destination))
	model.advance(IslandModel.STEP_SECONDS*0.5)
	view._process(0.0)
	assert(model.explored.size() == count and not tile.top.visible)
	model.advance(IslandModel.STEP_SECONDS*0.5+0.001)
	assert(not model.walking and not model.input_locked)
	assert(model.explored.size() == count+1)
	for frame in range(16):
		view._process(0.02 if frame > 0 else 0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/island-fog/clear-%02d.png" % frame)
		if frame == 0:
			assert(tile.fog.visible and tile.top.visible)
			assert(tile.root.get_child_count() == 5, "One transient particle emitter")
	assert(not tile.fog.visible and not tile.wisp.visible)
	assert(tile.body.material_override.get_shader_parameter("fog_reveal") == 1.0)
	assert(tile.prop == null or tile.prop.material_override.get_shader_parameter("reveal") == 1.0)
	assert(tile.prop == null or tile.prop.material_override.get_shader_parameter("fog_cover") == 0.0)
	await create_timer(0.5).timeout
	assert(tile.root.get_child_count() == 4,"Particles freed after the burst")
	model.preview_all = true
	view._process(0.0)
	for other in view.tiles.values(): assert(not other.fog.visible)
	print("ISLAND_FOG_PASS: hidden contents; arrival-only reveal; 0.28s clear; no input lock; transient particles cleaned; preview skips fog")
	quit()
