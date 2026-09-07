extends SceneTree
var errors: Array[String] = []
var capture := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label_value: String) -> void:
	if not ok: errors.append(label_value)
func snapshot(app: Control, name_value: String) -> void:
	if not capture: return
	for i in range(3): await process_frame
	app.arena._process(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/continuous-battle/"+name_value+".png")
func run() -> void:
	capture = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute("res://captures/continuous-battle")
	root.size = Vector2i(1600,960)
	var timing := BattleModel.new()
	timing.phase = "battle"
	for unit in timing.player+timing.enemy: unit.cdLeft = 100000
	var source: Dictionary = timing.player[0]
	var target: Dictionary = timing.enemy[0]
	source.atkType = "beam"
	var hits := {"count":0}
	timing.emitted.connect(func(e):
		if e.type == "damage": hits.count += 1)
	timing.shoot(source,target,1)
	timing.advance(.13)
	check(hits.count == 1 and timing.shots.size() == 1,"Beam hits at 68 percent while tail remains")
	timing.advance(.06)
	check(hits.count == 1 and timing.shots.is_empty(),"Beam tail never deals damage twice")
	var session = root.get_node("Journey")
	session.SAVE = "user://continuous-battle-test.json"
	for direction in [1,-1]:
		session.state = JourneyState.new()
		var state: JourneyState = session.state
		state.zones[0].route_kind = "fork"
		state.pending = state.zones[0].id
		var zone: String = state.pending
		var app = load("res://scenes/expedition_route.tscn").instantiate()
		root.add_child(app)
		await process_frame
		app.set_process(false)
		app.arena.set_process(false)
		app.choose(direction)
		var scenery_id: int = app.arena.scenery.get_instance_id()
		var player_ids: Array = app.arena.cards.filter(func(c):return c.side == "player").map(func(c):return c.get_instance_id())
		await snapshot(app,"%d-01-travel" % direction)
		for encounter in range(3 if direction == -1 else 2):
			for frame in range(1200):
				app._process(.05)
				if app.phase in ["encounter","sighting"]: break
			check(app.phase in ["encounter","sighting"],"Reaches next encounter in same scene")
			if app.is_social():
				app.resolve("fortune")
				app.resolve("fortune")
				check(state.reward_bonus == 2 and not state.cleared.has(zone),"Social reward once without exiting route")
				continue
			await snapshot(app,"%d-%d-encounter" % [direction,encounter])
			var position_before: Vector2 = app.camera
			var space_key: String = app.world.camera_region.space.key
			app.start_battle()
			for frame in range(54):
				app._process(.05)
				app.arena._process(.05)
			await snapshot(app,"%d-%d-fighting" % [direction,encounter])
			app.paused = true
			var battle_time: float = app.model.elapsed
			var sky_time: float = app.elapsed
			app._process(.05)
			check(app.model.elapsed == battle_time and app.elapsed == sky_time,"Pause freezes combat and environment")
			app.paused = false
			for frame in range(5000):
				app._process(.05)
				app.arena._process(.05)
				if app.phase != "battle": break
			check(app.phase == "clearing","Actual original-stat battle wins")
			check(app.camera.distance_to(position_before) < 5,"Battle retains location")
			check(str(app.world.camera_region.space.key) == space_key,"Battle retains space family")
			check(space_key == "forest","Forest tile remains forest on both branches")
			check(app.elapsed > sky_time,"Environment time continues while combat stops walking")
			check(state.stones == (encounter if direction == -1 else encounter+1)*2,"Battle loot awarded separately from route completion")
			var defeated_ids: Array = app.model.enemy.map(func(u):return u.uid)
			for frame in range(22): app._process(.05)
			check(app.phase == "travel" and not app.arena.enemies_visible and not app.model.enemy.any(func(u):return u.uid in defeated_ids),"Defeated enemies clear; next encounter may already exist in the distance")
			check(app.arena.scenery.get_instance_id() == scenery_id,"Same scenery instance across battle")
			check(app.arena.cards.filter(func(c):return c.side == "player").map(func(c):return c.get_instance_id()) == player_ids,"Player card instances persist")
			await snapshot(app,"%d-%d-onward" % [direction,encounter])
			if direction == 1 and encounter == 0:
				var checkpoint := JourneyState.new()
				check(checkpoint.restore(JSON.parse_string(JSON.stringify(state.to_save()))),"Restore between battles")
				checkpoint.zones[0].route_kind = "fork"
				app.queue_free()
				await process_frame
				session.state = checkpoint
				state = checkpoint
				app = load("res://scenes/expedition_route.tscn").instantiate()
				root.add_child(app)
				await process_frame
				app.set_process(false)
				app.arena.set_process(false)
				check(app.encounter_step == 1 and app.distance > 1350 and app.branch == 1,"Reentry resumes completed checkpoint and selected direction")
				scenery_id = app.arena.scenery.get_instance_id()
				player_ids = app.arena.cards.filter(func(c):return c.side == "player").map(func(c):return c.get_instance_id())
		for frame in range(1200): app._process(.05)
		check(app.route_complete and state.pending.is_empty() and state.stones == 16+state.reward_bonus,"Route ends after multiple encounters, awards once")
		check(not state.finish_local(),"No duplicate route reward")
		var copy := JourneyState.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(state.to_save()))) and copy.local_steps == state.local_steps,"Checkpoint survives JSON roundtrip")
		root.size = Vector2i(1000,650)
		await snapshot(app,"%d-small" % direction)
		root.size = Vector2i(1600,960)
		app.queue_free()
		await process_frame
	DirAccess.remove_absolute(session.SAVE)
	var report := FileAccess.open("res://captures/continuous-battle/validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":errors.is_empty(),"errors":errors,"rendered":capture,"engine":Engine.get_version_info().string,"branches":2,"battles_per_branch":2,"sizes":[[1600,960],[1000,650]],"checkpoint_reentry":true,"beam_timing":true},"\t"))
	report.close()
	if errors.is_empty(): print("CONTINUOUS_BATTLE_PASS two fights per branch, persistent cards/scenery, cloud/cave, pause, cleanup, event, checkpoint, one reward")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
