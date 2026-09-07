extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1800,1100)
	var app = load("res://scenes/rim_study.tscn").instantiate()
	root.add_child(app)
	DirAccess.make_dir_recursive_absolute("res://captures/rim-study")
	for heading in [0,1,2]:
		for view in app.views: view.model.heading = heading
		for frame in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/rim-study/compare-%d.png" % heading)
	print("CAPTURE_RIM_STUDY_PASS")
	quit()
