extends SceneTree
## Exercise the same preview entry shipped to the user, with real renderers.
var theme := "forest"
var native := true
var output := ""
var app
var evidence:Array = []

func _initialize() -> void:call_deferred("run")

func capture(label:String) -> void:
	for frame in 4:await process_frame
	await RenderingServer.frame_post_draw
	var path := output + "/" + label + ".png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	evidence.append({"phase":app.phase,"distance":app.distance,"branch":app.branch,"heading_deg":rad_to_deg(app.heading),"capture":path})

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="):theme = arg.trim_prefix("--theme=")
		if arg == "--2d":native = false
		if arg.begins_with("--output="):output = arg.trim_prefix("--output=")
		if arg.begins_with("--seed="):preload("res://scripts/spaces/biome_catalog.gd").seed_value = int(arg.trim_prefix("--seed="))
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	set_meta("native_route_view", native)
	set_meta("tour_biome", theme)
	set_meta("tour_exits", 2 if "--two" in OS.get_cmdline_user_args() else 3)
	set_meta("tour_event_placement", "after")
	app = load("res://scenes/original_six_route.tscn").instantiate()
	root.add_child(app)
	app.set_process(false)
	app.arena.set_process(false)
	app._process(1.0 / 60.0)
	assert(app.route_zone.theme == theme, "Wrong scene loaded")
	assert(is_instance_valid(app.native_route_view) == native, "Wrong rendering mode")
	assert(app.world.sprites.size() > 0)
	await capture("01-entry")
	var ticks := 0
	while app.phase != "choose" and ticks < 1600:
		app._process(.05);ticks += 1
		if ticks % 30 == 0:await process_frame
	assert(app.phase == "choose", "Travel did not reach fork")
	await capture("02-fork")
	var direction := 1 if "--right" in OS.get_cmdline_user_args() else -1
	app.choose(direction)
	assert(app.branch == direction)
	var fork_frames := "--fork-frames" in OS.get_cmdline_user_args()
	var checkpoints := []
	if "--dense-fork" in OS.get_cmdline_user_args():
		for step in range(0,380,15):checkpoints.append(ForestRoute.PAUSE_AT+step)
	elif fork_frames:
		checkpoints = [ForestRoute.JUNCTION-10.0,ForestRoute.JUNCTION+10.0,ForestRoute.JUNCTION+40.0,ForestRoute.JUNCTION+80.0,ForestRoute.JUNCTION+120.0,ForestRoute.JUNCTION+200.0,ForestRoute.JUNCTION+280.0]
	for tick in 60:
		app._process(.05)
		if tick % 15 == 0:await process_frame
		if not checkpoints.is_empty() and app.distance >= float(checkpoints[0]):
			await capture("fork-%d" % int(checkpoints.pop_front()))
	await capture("03-turn")
	ticks = 0
	while app.phase not in ["encounter", "sighting"] and ticks < 1600:
		app._process(.05);ticks += 1
		if ticks % 30 == 0:await process_frame
		if not checkpoints.is_empty() and app.distance >= float(checkpoints[0]):
			await capture("fork-%d" % int(checkpoints.pop_front()))
	assert(app.phase in ["encounter", "sighting"], "Selected road did not reach event")
	await capture("04-event")
	if "--fork-only" in OS.get_cmdline_user_args():
		var fork_report := {"theme":theme,"mode":"3D" if native else "2D","sprites":app.world.sprites.size(),"captures":evidence,"passed":true}
		var fork_file := FileAccess.open(output + "/result.json", FileAccess.WRITE)
		fork_file.store_string(JSON.stringify(fork_report, "  "));fork_file.close()
		quit();return
	app.start_battle()
	for tick in 120:
		app._process(.05)
		if tick % 30 == 0:await process_frame
	assert(app.phase == "battle", "Battle did not start")
	await capture("05-battle")
	var report := {"theme":theme,"mode":"3D" if native else "2D","sprites":app.world.sprites.size(),"captures":evidence,"passed":true}
	var file := FileAccess.open(output + "/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "));file.close()
	print("ORIGINAL_SIX_RECOVERY_PASS ", theme, " ", report.mode)
	quit()
