extends SceneTree
var folder := "res://captures/journey-review"
func _initialize() -> void: call_deferred("run")
func shot(label_value: String) -> void:
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+label_value+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1600,960)
	var session = root.get_node("Journey")
	session.SAVE = "user://journey-capture-isolated.json"
	session.state = JourneyState.new()
	var app = load("res://scenes/journey.tscn").instantiate()
	root.add_child(app)
	await shot("01-explore")
	for step in range(100):
		if not session.state.pending.is_empty(): break
		session.state.advance_frontier()
		for i in range(200):
			session.state.world.advance(.05)
			if not session.state.world.walking: break
	await shot("02-encounter")
	root.size = Vector2i(1000,650)
	await shot("03-small-window")
	root.size = Vector2i(1600,960)
	app.queue_free()
	await process_frame
	session.state.prepare_battle()
	session.fighting = true
	app = load("res://scenes/battle_study.tscn").instantiate()
	root.add_child(app)
	await shot("04-formation")
	app.start()
	await create_timer(1.5).timeout
	await shot("05-fighting")
	app.set_process(false)
	for i in range(40000):
		app.model.advance(1.0/120)
		if app.model.phase != "battle": break
	app._process(0)
	await shot("06-result")
	app.queue_free()
	await process_frame
	session.fighting = false
	app = load("res://scenes/journey.tscn").instantiate()
	root.add_child(app)
	await shot("07-return")
	DirAccess.remove_absolute(session.SAVE)
	print("CAPTURE_JOURNEY_PASS")
	quit()
