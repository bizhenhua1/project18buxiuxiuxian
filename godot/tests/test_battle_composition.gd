extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var session = root.get_node("Journey")
	session.SAVE = "user://battle-composition-test.json"
	session.state = JourneyState.new()
	session.state.pending = session.state.zones[0].id
	root.size = Vector2i(1600,960)
	var app = load("res://scenes/expedition_route.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.arena.set_process(false)
	for frame in range(1200):
		app._process(.05)
		if app.phase in ["sighting","encounter"]: break
	app.start_battle()
	for frame in range(16): app._process(.05)
	app.paused = true
	app.model.paused = true
	app.arena.show_card_names = false
	DirAccess.make_dir_recursive_absolute("res://captures/battle-composition")
	for dims in [Vector2i(1600,960),Vector2i(1000,650),Vector2i(2545,1301)]:
		root.size = dims
		for i in range(3): await process_frame
		app._layout_ui()
		var players: Array = app.arena.cards.filter(func(c):return c.side == "player" and c.visible)
		var enemies: Array = app.arena.cards.filter(func(c):return c.side == "enemy" and c.visible)
		if players.size() != app.model.player.size(): errors.append("visible player count")
		if enemies.is_empty(): errors.append("enemy formation missing")
		for card in players+enemies:
			if absf(card.size.x/card.size.y-130.0/280.0) > .001: errors.append("aspect ratio")
			if not Rect2(Vector2.ZERO,app.arena.size).encloses(Rect2(card.position,card.size)): errors.append("card clipped")
		if not enemies.is_empty() and players[0].position.y-enemies[0].position.y-enemies[0].size.y < 100: errors.append("central gap")
		if not app.arena.scenery.position.is_equal_approx(Vector2.ZERO) or not app.arena.scenery.size.is_equal_approx(app.arena.size): errors.append("continuous scenery")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/battle-composition/%dx%d.png" % [dims.x,dims.y])
	root.size = Vector2i(1600,960)
	await process_frame
	app.arena.show_card_names = true
	app._layout_ui()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/battle-composition/names.png")
	app.phase = "travel"
	app.open_kit()
	app._layout_ui()
	if app.kit_panel.position.y+app.kit_panel.size.y > app.arena.position.y+app.arena.cards[-1].position.y: errors.append("equipment overlaps player cards")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/battle-composition/equipment.png")
	DirAccess.remove_absolute(session.SAVE)
	if errors.is_empty(): print("BATTLE_COMPOSITION_PASS three sizes, aspect ratio, persistent landscape, names, equipment")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
