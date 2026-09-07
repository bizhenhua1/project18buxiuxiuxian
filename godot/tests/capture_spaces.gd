extends SceneTree
func _initialize() -> void:
	call_deferred("capture_samples")
func capture_samples() -> void:
	var app = load("res://scenes/space_study.tscn").instantiate()
	root.add_child(app)
	var directory := ProjectSettings.globalize_path("res://captures/spaces-review")
	DirAccess.make_dir_recursive_absolute(directory)
	var samples := [["connected",-1,1550.0,"01-forest-entrance"],["connected",-1,1800.0,"02-near-entrance"],["connected",-1,1950.0,"03-crossing"],["connected",-1,2450.0,"04-inside"],["connected",1,1800.0,"05-cloud-boundary"],["connected",1,2450.0,"06-cloud-interior"],["cave",-1,460.0,"07-cave-fork"],["cloudsea",1,460.0,"08-cloud-fork"]]
	for sample in samples:
		if app.preset != sample[0]: app.load_preset(sample[0])
		app.paused = true
		app.phase = "choose" if sample[2] == 460 else "travel"
		app.branch = sample[1]
		app.distance = sample[2]
		app.elapsed = 8
		app.bob = false
		var pose := ForestRoute.pose(app.distance,app.branch)
		app.camera = pose.position
		app.heading = pose.heading
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var error := root.get_texture().get_image().save_png(directory.path_join(sample[3]+".png"))
		assert(error == OK)
		print("SPACE_CAPTURE ",sample[3])
	quit()
