extends SceneTree
var folder := "res://captures/home-review"
func _initialize() -> void: call_deferred("run")
func shot(label_value: String) -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label_value+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1600,960)
	var session = root.get_node("Journey")
	session.SAVE = "user://home-capture-isolated.json"
	session.state = JourneyState.new()
	session.home = HomeState.new()
	var app = load("res://scenes/home.tscn").instantiate()
	root.add_child(app)
	await shot("01-home")
	session.home.plant(Vector2i(10,11),"herbs")
	session.home.selected = Vector2i(10,11)
	await shot("02-planted")
	root.size = Vector2i(1000,650)
	await shot("03-small-home")
	root.size = Vector2i(1600,960)
	app.queue_free()
	await process_frame
	session.depart(0)
	for step in range(200):
		if not session.state.pending.is_empty(): break
		session.state.advance_frontier()
		for frame in range(200):
			session.state.world.advance(.05)
			if not session.state.world.walking: break
	app = load("res://scenes/expedition_route.tscn").instantiate()
	root.add_child(app)
	await shot("04-route")
	app.set_process(false)
	app.choose(-1)
	for frame in range(1600): app._process(.05)
	await shot("05-cave-traveler")
	root.size = Vector2i(1000,650)
	await shot("06-small-event")
	DirAccess.remove_absolute(session.SAVE)
	print("CAPTURE_HOME_PASS")
	quit()
