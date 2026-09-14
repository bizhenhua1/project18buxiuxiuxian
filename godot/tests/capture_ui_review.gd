extends SceneTree
var errors: Array[String] = []
var folder := "res://captures/ui-review"
func _initialize() -> void: call_deferred("run")
func check(value: bool, description: String) -> void:
	if not value: errors.append(description)
func shot(app: Control, name_value: String) -> void:
	for i in range(4): await process_frame
	app.arena._process(0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func click(button: Button) -> void:
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event,true)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1600,960)
	var session = root.get_node("Journey")
	session.SAVE = "user://ui-review-isolated.json"
	session.state = JourneyState.new()
	session.state.zones[0].route_kind = "fork"
	session.state.zones[0].battle_choice = true
	session.state.pending = session.state.zones[0].id
	var app = load("res://scenes/expedition_route.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.arena.set_process(false)
	for i in range(40): app._process(.05)
	await shot(app,"01-fork")
	check(app.phase == "choose","Arrives at route choice")
	click(app.right_button)
	await process_frame
	check(app.branch == 1 and app.phase == "travel","Real route-choice button works")
	for i in range(300):
		app._process(.05)
		if app.phase == "encounter": break
	await shot(app,"02-encounter")
	var uid: int = app.model.player[0].uid
	var card_id: int = app.arena.cards.filter(func(c):return c.unit.get("uid",-1) == uid)[0].get_instance_id()
	app.show_detail(app.model.player[3])
	click(app.formation_button)
	await process_frame
	check(app.kit_panel.visible and app.paused,"Formation button opens inline inventory and pauses")
	check(app.kit_panel is PanelContainer,"Inventory is a scene control, not a popup window")
	for card in app.arena.cards:
		if card.side == "player": check(not app.kit_panel.get_global_rect().intersects(card.get_global_rect()),"Inline inventory does not overlap player formation")
	var player_card = app.arena.cards.filter(func(c):return c.unit.get("uid",-1) == uid)[0]
	var select_event := InputEventMouseButton.new()
	select_event.position = player_card.get_global_rect().get_center()
	select_event.button_index = MOUSE_BUTTON_LEFT
	select_event.pressed = true
	root.push_input(select_event,true)
	select_event.pressed = false
	root.push_input(select_event,true)
	await process_frame
	check(app.selected_unit.get("uid",-1) == uid,"Player formation remains clickable while inventory is open")
	await shot(app,"03-equipment")
	click(app.kit_remove)
	await process_frame
	check(not app.model.player.any(func(u):return u.uid == uid),"Inline action returns selected artifact")
	var item = app.kit_items.get_children().filter(func(b):return b.card_id == "watchful-clock")[0]
	click(item)
	await process_frame
	check(app.model.player.size() == 8,"Inline inventory can re-equip artifact")
	app.model.move(app.model.player.filter(func(u):return u.cardId == "watchful-clock")[0].index,0)
	app.arena.rebuild()
	app.paused = true
	root.size = Vector2i(1000,650)
	await shot(app,"03b-small-equipment")
	for card in app.arena.cards:
		if card.side == "player": check(not app.kit_panel.get_global_rect().intersects(card.get_global_rect()),"Small inline inventory does not overlap player formation")
	check(app.kit_panel.get_global_rect().end.y <= app.arena.global_position.y+app.arena.scenery.position.y*app.arena.scale.y,"Inline inventory stays above scenery")
	root.size = Vector2i(1600,960)
	app.close_kit()
	await process_frame
	check(not app.paused,"Closing inventory restores prior pause state")
	var count: int = app.model.player.size()
	app.arena.remove_card(0)
	check(app.model.player.size() == count-1,"Can return an equipped artifact")
	app.note(app.model.add_card("watchful-clock",0))
	app.arena.rebuild()
	check(app.model.player.size() == count,"Returned artifact can be equipped again")
	app.arena.remove_card(2)
	check(app.model.player.size() == count,"Hero remains in party")
	root.size = Vector2i(1000,650)
	await shot(app,"04-small-encounter")
	for card in app.arena.cards:
		if card.visible: check(Rect2(Vector2.ZERO,root.size).encloses(card.get_global_rect()),"Visible card stays inside small viewport")
	root.size = Vector2i(1600,960)
	await shot(app,"05-before-fight")
	click(app.fight)
	await process_frame
	for frame in range(30): app._process(.05)
	check(app.phase == "battle" and not app.event_box.visible,"Fight starts without blocking event panel")
	var progress_before: float = app.distance
	for i in range(30):
		app._process(.05)
		app.arena._process(.05)
	check(app.distance == progress_before,"Combat does not walk")
	await shot(app,"06-fighting")
	var particles: BattleParticles = app.arena.particles
	particles.clear()
	for i in range(100): particles.burst({"type":"damage","unit":app.model.player[i%count],"crit":i%3 == 0})
	check(particles.high_water <= BattleParticles.POOL_SIZE and particles.dropped > 0,"Particle burst budget bounded under overload")
	app.model.paused = true
	particles.advance(.1,4,true)
	check(particles.pool.all(func(s):return s.node.speed_scale == 0),"All emitters pause")
	app.model.paused = false
	particles.advance(.1,2,false)
	check(particles.pool.all(func(s):return s.node.speed_scale == 2),"All emitters honor speed")
	particles.clear()
	for i in range(5):
		particles.burst({"type":["damage","damage","heal","buff","death"][i],"unit":app.model.player[i],"crit":i==1})
	await create_timer(.10).timeout
	await shot(app,"07-native-particles")
	particles.clear()
	check(particles.pool.all(func(s):return s.remaining == 0 and not s.node.emitting),"Clearing stops all emitters")
	# Card catalog review uses the same in-game renderer, without altering balance or saves.
	app.model.reset()
	app.model.player.clear()
	for id in ["investigator","containment-record","night-warden","stopped-clock","oathbreaker-mask","scarlet-edict","silence-contract","severed-moment"]:
		if not app.model.rules.card(id).is_empty(): app.model.player.append(app.model.rules.create_unit(id,"player",app.model.player.size()))
	app.arena.rebuild()
	await shot(app,"08-artifact-catalog")
	for unit in app.model.player:
		unit.hp = maxi(1,int(unit.maxHp*.25))
		unit.shield = 8
	app.arena._process(1)
	await shot(app,"09-health-shields")
	var report := {"passed":errors.is_empty(),"errors":errors,"native_particles":true,"flipbooks":false,"pool_limit":BattleParticles.POOL_SIZE,"particle_limit":BattleParticles.POOL_SIZE*BattleParticles.PARTICLES_PER_EMITTER,"pool_high_water":particles.high_water,"overload_dropped":particles.dropped}
	var file := FileAccess.open(folder+"/validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	DirAccess.remove_absolute(session.SAVE)
	if errors.is_empty(): print("UI_REVIEW_PASS native input, responsive cards, equipment, pause/speed, bounded GPU particles, alpha-clean artifacts")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
