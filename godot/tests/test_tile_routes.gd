extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
func snapshot(app: Control, name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/tile-routes/"+name_value+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/tile-routes")
	var session = root.get_node("Journey")
	for id in ["rat","yezhu","caoshe","yewu","huoli"]:
		check(CreatureMotion.sample(id,0).squash.is_equal_approx(Vector2.ONE) and CreatureMotion.sample(id,1).squash.is_equal_approx(Vector2.ONE),"Creature pose returns to neutral at fixed endpoints")
	check(CreatureMotion.sample("rat",.5).squash != CreatureMotion.sample("yezhu",.5).squash,"Scurry and charge have distinct silhouettes")
	session.SAVE = "user://tile-routes-isolated.json"
	for theme_name in ["forest","cave","cloudsea"]:
		var plan := LocalRouteSpec.plan({"theme":theme_name,"route_kind":"short"})
		check(plan.validate().is_empty() and plan.straight,"Valid straight theme plan")
		check(plan.regions.all(func(r):return str(r.space.key) == theme_name),"No implicit cross-biome region")
	for index in [0,1,2]:
		session.state = JourneyState.new()
		var state: JourneyState = session.state
		if index == 2: state.zones[2].route_kind = "short"
		for zone in state.zones:
			check(zone.theme == state.world.lookup[Vector2i(zone.cell[0],zone.cell[1])].theme,"Zone derives biome from actual tile")
		state.pending = state.zones[index].id
		var app = load("res://scenes/expedition_route.tscn").instantiate()
		root.size = Vector2i(1600,960)
		root.add_child(app)
		await process_frame
		app.set_process(false)
		app.arena.set_process(false)
		check(app.phase == "travel" and app.branch == 0 and app.world.plan.straight,"Simple tile starts without a fork")
		var friendly_ids: Array = app.arena.cards.filter(func(c):return c.side == "player").map(func(c):return c.get_instance_id())
		var ratios: Array[float] = []
		for dimensions in [Vector2i(1000,650),Vector2i(1600,960),Vector2i(2545,1301)]:
			root.size = dimensions
			await process_frame
			app._process(0)
			var card = app.arena.cards.filter(func(c):return c.side == "player")[0]
			ratios.append(card.size.y*app.arena.scale.y/dimensions.y)
			check(app.arena.scenery.position.y == 0,"Travel removes enemy row and expands scenery")
			for c in app.arena.cards:
				if c.visible: check(Rect2(Vector2.ZERO,root.size).encloses(c.get_global_rect()),"Scaled cards remain in viewport")
			await snapshot(app,"%d-travel-%d" % [index,dimensions.x])
		check(ratios.max()-ratios.min() < .025,"Card proportion remains stable across window sizes")
		root.size = Vector2i(1600,960)
		var wins := 0
		var marker_seen := false
		var last_phase := ""
		var entrance_samples := {}
		var prior_top := 0.0
		var grass_reacted := false
		for frame in range(1800):
			app._process(.05)
			app.arena._process(.05)
			if not grass_reacted and app.world.sprites.any(func(s):return s.has("rustle_started")):
				grass_reacted = true
				check(not app.world.sprites.any(func(s):return s.kind != 1 and s.has("rustle_started")),"Only nearby ground plants react; trees remain stable")
				await snapshot(app,"%d-brush-rustle" % index)
			if app.phase == "entering":
				check(app.model.elapsed == 0,"No damage simulation before entrance completes")
				check(absf(app.arena.scenery.position.y-prior_top) < 35,"Camera reframing has no per-frame jump")
				var current_rect: Rect2 = app.road_actor.sample_rect()
				check(current_rect.get_center().x >= minf(app.road_actor.start_rect.get_center().x,app.road_actor.end_rect.get_center().x)-.01 and current_rect.get_center().x <= maxf(app.road_actor.start_rect.get_center().x,app.road_actor.end_rect.get_center().x)+.01,"Flight never overshoots destination horizontally")
				if app.road_actor.flight_t >= .72: check(current_rect.is_equal_approx(app.road_actor.end_rect),"Flight arrives at exact card image rectangle without correction")
				check(app.arena.scenery.renderer.horizon_ratio >= .4,"Battle reframing preserves sky above horizon")
				var frame_key := int(app.entrance_time/app.ENTRANCE_SECONDS*5)
				if not entrance_samples.has(frame_key):
					entrance_samples[frame_key] = true
					await snapshot(app,"%d-entry-%d" % [index,frame_key])
				if frame_key == 2:
					app.paused = true
					var clock_before: float = app.entrance_time
					app._process(.05)
					check(app.entrance_time == clock_before,"Pause freezes entrance choreography")
					app.paused = false
			prior_top = app.arena.scenery.position.y
			if not app.scene_actor.is_empty() and not app.scene_actor.hidden:
				marker_seen = true
				check(app.model.enemy.any(func(u):return app.road_actor.art == app.arena.art_for(u)),"Road monster is a member of upcoming enemy formation")
			if app.phase == "sighting" and last_phase != "sighting": await snapshot(app,"%d-road-monster" % index)
			if app.phase == "sighting":
				check(app.companions.size() == app.model.enemy.size()-1,"Mandatory fight stages every companion in the world")
				check(app.pack_time > .28,"Companions emerge before flight begins")
			if app.phase == "encounter" and app.is_social(): app.resolve("supplies")
			if app.phase == "battle":
				check(app.road_actor.companions.size() == app.model.enemy.size()-1,"Every staged companion has its own card flight")
				check(app.arena.enemies_visible,"Automatic battle reveals enemy formation")
				for unit in app.model.player: unit.atk = 1000
				if last_phase != "battle": await snapshot(app,"%d-battle" % index)
			if app.phase == "clearing" and last_phase != "clearing":
				wins += 1
				check(app.reward_notice.visible and "灵石" in app.reward_notice.text,"Battle settlement is visible")
				await snapshot(app,"%d-loot-%d" % [index,wins])
			last_phase = app.phase
			if app.route_complete: break
		check(marker_seen and wins == (1 if index == 1 else 2),"Short route has expected automatic fights")
		check(grass_reacted and is_equal_approx(app.ENTRANCE_SECONDS,.72),"Local grass reacts without extending entrance duration")
		check(app.route_complete and app.event_panel.visible and app.final_reward == int(app.route_zone.reward),"Completion visibly reports actual reward")
		var money := state.stones
		check(not state.finish_local() and state.stones == money,"Completion cannot duplicate payout")
		check(app.arena.cards.filter(func(c):return c.side == "player").map(func(c):return c.get_instance_id()) == friendly_ids,"Party survives all layout and battle changes")
		await snapshot(app,"%d-complete" % index)
		app.queue_free()
		await process_frame
	DirAccess.remove_absolute(session.SAVE)
	var report := FileAccess.open("res://captures/tile-routes/validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":errors.is_empty(),"errors":errors},"\t"))
	for error in errors: push_error(error)
	if errors.is_empty(): print("TILE_ROUTES_PASS biome ownership, short routes, road enemies, auto battle, rewards, responsive layout")
	quit(0 if errors.is_empty() else 1)
