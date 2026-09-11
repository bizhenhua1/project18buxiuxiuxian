extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model:=IslandModel.new()
	model.cells.clear()
	model.lookup.clear()
	for x in range(-4,5):
		for y in range(-4,5):
			var cell:={"c":x,"r":y,"h":0,"base":IslandAssets.SHROUD,"feat":null,"layer":"land"}
			model.cells.append(cell)
			model.lookup[Vector2i(x,y)]=cell
	model.player=Vector2i.ZERO
	for level in range(5):
		model.explored.clear()
		model.set_reveal_range(level)
		assert(model.explored.size()==[1,5,9,13,25][level])
	var state:=JourneyState.new()
	var start:=state.world.player
	var target:=Vector2i.ZERO
	for offset in IslandModel.NBS:
		if state.world.lookup.has(start+offset):
			target=start+offset
			break
	state.zones[0].cell=[target.x,target.y]
	state.sync_events()
	assert(state.world.go_to(target))
	state.world.advance(IslandModel.AMBUSH_WINDUP)
	assert(state.world.rebounding and state.world.player==start)
	assert(state.world.explored.has(target) and state.pending.is_empty() and not state.world.input_locked)
	var initial:=state.world.avatar()
	assert(is_equal_approx(Vector2(initial.x,initial.z).distance_to(Vector2(start)),IslandModel.AMBUSH_EDGE))
	state.world.advance(IslandModel.REBOUND_SECONDS/2)
	var middle:=state.world.avatar()
	assert(Vector2(middle.x,middle.z).distance_to(Vector2(start))>0.1)
	assert(Vector2(middle.x,middle.z).distance_to(Vector2(target))>0.1)
	state.world.advance(IslandModel.REBOUND_SECONDS/2+0.001)
	assert(not state.world.walking and state.world.player==start)
	state.retreat()
	assert(not state.world.can_visit(target))
	assert(state.world.find_path(target).is_empty())
	assert(state.world.go_to(target) and not state.pending.is_empty())
	assert(not state.world.walking,"Known event asks without entering its tile")
	state.world.set_reveal_range(2)
	# Range saves independently of transient walking animation.
	var saved_world:=IslandModel.new()
	assert(saved_world.restore(state.world.to_save()) and saved_world.reveal_range==2)
	root.size=Vector2i(1200,800)
	root.gui_disable_input=true
	var session=root.get_node("Journey")
	session.SAVE="user://world-events-isolated.json"
	session.state=state
	var app=load("res://scenes/journey.tscn").instantiate()
	root.add_child(app)
	for frame in range(6): await process_frame
	assert(app.encounter_modal.visible)
	assert(app.encounter_panel.get_global_rect().get_center().distance_to(Vector2(root.size)/2)<3.0)
	assert(app.view.tiles[target].event_actor.visible)
	DirAccess.make_dir_recursive_absolute("res://captures/world-events")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/world-events/center-prompt.png")
	for window_size in [Vector2i(1000,650),Vector2i(1920,1080),Vector2i(1200,800)]:
		root.size=window_size
		for frame in range(6): await process_frame
		assert(app.encounter_modal.size==Vector2(window_size))
		assert(app.encounter_panel.get_global_rect().get_center().distance_to(Vector2(window_size)/2)<3.0)
		var card: PanelContainer=app.encounter_panel.get_parent().get_parent()
		assert(card.get_theme_stylebox("panel").bg_color.a==1.0,"Opaque modal backing")
		assert(Rect2(Vector2.ZERO,Vector2(window_size)).encloses(card.get_global_rect()))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/world-events/prompt-%d.png" % window_size.x)
	state.retreat()
	state.cleared[state.zones[0].id]=true
	state.updated.emit()
	assert(state.world.can_visit(target))
	for frame in range(3): await process_frame
	assert(not app.view.tiles[target].event_actor.visible)
	assert(not app.encounter_modal.visible)
	DirAccess.remove_absolute(session.SAVE)
	print("WORLD_EVENTS_PASS: 1/5/9/13/25 reveal, animated rebound, blocking, re-entry, range save, centered modal, marker removal")
	quit()
