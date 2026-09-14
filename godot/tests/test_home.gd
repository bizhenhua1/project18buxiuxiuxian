extends SceneTree
var errors: Array[String] = []
func check(ok: bool, label_value: String) -> void:
	if not ok: errors.append(label_value)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,960)
	var home := HomeState.new()
	check(home.plant(Vector2i(10,11),"herbs"),"Plant on free unlocked tile")
	check(not home.plant(Vector2i(10,11),"grove"),"Occupied tile rejects planting")
	check(home.unlock(Vector2i(8,9)) and home.bank == 6,"Unlock adjacent land consumes currency once")
	check(not home.unlock(Vector2i(8,9)),"Cannot buy same land twice")
	home.advance(30)
	check(home.relocate(Vector2i(10,11),Vector2i(8,9)) and home.plots[Vector2i(8,9)].growth == 30,"Relocation preserves growth")
	check(home.harvest() == 0,"Cannot harvest early")
	home.advance(90)
	check(home.harvest() == 11 and home.harvest() == 0,"Mature plots harvest once")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(home.to_save()))
	var copy := HomeState.new()
	check(copy.restore(saved) and copy.bank == home.bank and copy.plots == home.plots,"Home save preserves layout and funds")
	var session = root.get_node("Journey")
	session.SAVE = "user://home-test-isolated.json"
	session.state = JourneyState.new()
	session.home = home
	session.depart(0)
	var state: JourneyState = session.state
	for step in range(200):
		if not state.pending.is_empty(): break
		state.advance_frontier()
		for frame in range(200):
			state.world.advance(.05)
			if not state.world.walking: break
	check(not state.pending.is_empty(),"Expedition reaches local route entrance")
	state.active_zone().route_kind = "fork"
	var app = load("res://scenes/expedition_route.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	for frame in range(400):
		if app.phase == "choose": break
		app._process(.05)
	app.choose(-1)
	for frame in range(1600): app._process(.05)
	check(app.phase == "encounter" and state.event_kind() == "traveler","Explicit forest fork reaches traveler")
	check(state.resolve_event("fortune") and state.reward_bonus == 2,"Local choice grants temporary expedition growth")
	check(not state.resolve_event("supplies"),"Completed event cannot award twice")
	app.queue_free()
	await process_frame
	for step in range(200):
		if not state.pending.is_empty(): break
		state.advance_frontier()
		for frame in range(200):
			state.world.advance(.05)
			if not state.world.walking: break
	state.active_zone().route_profile = "short_battle"
	state.active_zone().route_kind = "short"
	app = load("res://scenes/expedition_route.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.choose(1)
	for frame in range(1600):
		app._process(.05)
		if app.phase == "sighting": break
	check(app.phase == "sighting" and state.event_kind() == "battle","Short route reaches actual road monster")
	state.prepare_battle()
	state.battle.start()
	for frame in range(40000):
		state.battle.advance(1.0/120)
		if state.battle.phase != "battle": break
	check(state.settle("victory") and state.stones == 20,"Battle victory applies run-only boon")
	app.queue_free()
	await process_frame
	state.stones = 19
	var before := home.bank
	check(session.return_home(),"Return from expedition")
	await process_frame
	await process_frame
	check(home.bank == before+19 and state.stones == 0 and not session.expedition_active,"Loot transfers exactly once into home storage")
	check(not session.return_home() and home.bank == before+19,"No double return award")
	var home_app = current_scene
	var point: Vector2 = home_app.view.global_position+home_app.view.camera.unproject_position(home_app.view.world_position(10,11,0))
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	check(home.selected == Vector2i(10,11),"Native click selects construction cell instead of walking")
	session.depart(1)
	check(session.state.reward_bonus == 0 and session.state.stones == 0 and session.home.bank == before+19,"New expedition clears temporary growth, keeps home")
	var event_state := JourneyState.new()
	event_state.pending = event_state.zones[1].id
	event_state.route_choices[event_state.pending] = -1
	check(event_state.event_kind() == "merchant" and not event_state.resolve_event("fortune"),"Merchant cannot charge an empty bag")
	event_state.stones = 4
	check(event_state.resolve_event("fortune") and event_state.stones == 0 and event_state.reward_bonus == 3,"Merchant charges bag, grants temporary boon")
	var event_copy := JourneyState.new()
	check(event_copy.restore(JSON.parse_string(JSON.stringify(event_state.to_save()))) and event_copy.reward_bonus == 3 and event_copy.route_choices == event_state.route_choices,"Reload preserves event choices and boon")
	var legacy := FileAccess.open(session.SAVE,FileAccess.WRITE)
	legacy.store_string(JSON.stringify(JourneyState.new().to_save()))
	legacy.close()
	session.state = null
	session.home = HomeState.new()
	session.resume()
	check(FileAccess.file_exists(session.SAVE+".before-home.json") and session.home.bank == 24,"Legacy journey remains backed up before home migration")
	DirAccess.remove_absolute(session.SAVE)
	DirAccess.remove_absolute(session.SAVE+".before-home.json")
	if errors.is_empty(): print("HOME_PASS planting, unlock, relocation, harvest, storage, actual cave route, traveler, run reset")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
