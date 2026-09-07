extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,960)
	root.gui_disable_input = true
	var session = root.get_node("Journey")
	session.SAVE = "user://selection-head-isolated.json"
	session.home = HomeState.new()
	session.state = JourneyState.new()
	var app = load("res://scenes/home.tscn").instantiate()
	root.add_child(app)
	DirAccess.make_dir_recursive_absolute("res://captures/selection-head")
	for i in range(5):
		app.view.model.hover = [Vector2i(11,11),Vector2i(12,11),Vector2i(9,9),Vector2i(10,8),HomeState.COTTAGE][i]
		app.view.model.heading = 1 if i == 2 else 0
		for frame in range(6): await process_frame
		assert(app.view.ghost_body.visible)
		assert(not app.view.ghost_prop.visible)
		assert(app.view.selection_union.visible == (i >= 2))
		assert(app.view.ghost_body.material_override.get_shader_parameter("unified") == (i >= 2))
		var expected := Color("c5e9a5") if app.view.model.can_visit(app.view.model.hover) else Color("d59075")
		assert(app.view.ghost_body.material_override.get_shader_parameter("tint") == expected)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/selection-head/%d.png" % i)
	DirAccess.remove_absolute(session.SAVE)
	app.queue_free()
	await process_frame
	app = load("res://scenes/world_study.tscn").instantiate()
	root.add_child(app)
	app.focus(2)
	for accessible in [false,true]:
		for cell in app.model.cells:
			var key := IslandModel.key(cell)
			if not app.model.explored.has(key) and app.model.can_visit(key) == accessible:
				app.model.hover = key
				break
		for frame in range(6): await process_frame
		var view: IslandView3D = app.views[1]
		assert(view.ghost_body.material_override.get_shader_parameter("tint") == (Color("c5e9a5") if accessible else Color("d59075")))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/selection-head/fog-%s.png" % str(accessible))
	for accessible in [false,true]:
		var found := false
		for cell in app.model.cells:
			var key := IslandModel.key(cell)
			if cell.feat != null and not app.model.explored.has(key) and app.model.can_visit(key) == accessible:
				app.model.hover = key
				found = true
				break
		assert(found,"Unknown prop fixture exists")
		for frame in range(6): await process_frame
		var view: IslandView3D = app.views[1]
		assert(view.selection_union.visible)
		assert(not view.outline.visible,"No diamond line through the fog prop")
		assert(view.ghost_body.material_override.get_shader_parameter("unified"))
		assert(not view.tiles[app.model.hover].prop.visible,"Selection does not reveal illustration")
		assert(view.selection_union.material.get_shader_parameter("tint") == (Color("c5e9a5") if accessible else Color("d59075")))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/selection-head/fog-prop-%s.png" % str(accessible))
	print("CAPTURE_SELECTION_HEAD_PASS")
	quit()
