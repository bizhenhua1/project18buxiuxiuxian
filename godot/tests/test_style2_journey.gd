extends SceneTree
var folder := "res://captures/style2"
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func shot(name_value: String) -> void:
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func run() -> void:
	StyleLibrary.active = true
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1600,960)
	var session = root.get_node("Journey")
	session.SAVE = "user://style2-test.json"
	session.state = JourneyState.new()
	session.expedition_active = true
	for zone in session.state.zones: zone.title = "雾林巡查 · "+str(int(zone.tier)+1)
	session.state.world.set_reveal_range(2)
	var world_app = load("res://scenes/journey.tscn").instantiate()
	root.add_child(world_app)
	await shot("01-world-fog")
	# Walk the real grid until an uncleared event blocks progression.
	for step in range(100):
		if not session.state.pending.is_empty(): break
		session.state.advance_frontier()
		for i in range(200):
			session.state.world.advance(.05)
			if not session.state.world.walking: break
	await shot("02-world-event")
	if session.state.pending.is_empty(): errors.append("No reachable event")
	var active: String = session.state.pending
	world_app.queue_free()
	await process_frame
	var app = load("res://scenes/expedition_route.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.arena.scene_mode = true
	app.set_process(false)
	app.arena.set_process(false)
	await shot("03-forest-travel")
	var scenery_id: int = app.arena.scenery.get_instance_id()
	var battles := 0
	var fx_captured := false
	for i in range(6000):
		app._process(.05)
		app.arena._process(.05)
		if app.phase == "encounter" and app.is_social(): app.resolve("supplies")
		if app.phase == "encounter" and not app.is_social(): app.start_battle()
		if app.phase == "battle" and app.model.elapsed > .7 and battles == app.encounter_step:
			battles += 1
			await shot("04-combat-%d" % battles)
		if not fx_captured and app.model.shots.size() > 0 and app.model.elapsed > 1.2:
			fx_captured = true
			await shot("04-fx-in-motion")
		if app.route_complete: break
	if battles < 2: errors.append("Expected two real combats")
	if not app.route_complete: errors.append("Route did not finish")
	if not session.state.cleared.has(active): errors.append("Tile event was not cleared")
	if app.arena.scenery.get_instance_id() != scenery_id: errors.append("Scenery replaced during combat")
	if app.arena.particles.emitted_count == 0: errors.append("No native particle effects")
	await shot("05-reward")
	app.queue_free()
	await process_frame
	world_app = load("res://scenes/journey.tscn").instantiate()
	root.add_child(world_app)
	await shot("06-world-return")
	# Review all external tiles with the same actual shader/geometry, not a generated mockup.
	for cell in session.state.world.cells: session.state.world.explored[IslandModel.key(cell)] = true
	session.state.world.update_sight()
	for i in range(30): await process_frame
	await shot("07-world-materials")
	DirAccess.remove_absolute(session.SAVE)
	var report := {"passed":errors.is_empty(),"errors":errors,"cleared":session.state.cleared.size(),"reward":session.state.stones,"battles":battles,"alpha_qc":"assets/generated/style2-production/alpha-qc.json"}
	FileAccess.open(folder+"/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STYLE2_JOURNEY ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
