extends SceneTree
var errors: Array[String] = []
func check(ok: bool, label_value: String) -> void:
	if not ok: errors.append(label_value)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state := JourneyState.new()
	var original_zones := state.zones.duplicate(true)
	check(not state.next_island(),"Next island is gated")
	for encounter in range(3):
		for step in range(200):
			if not state.pending.is_empty(): break
			if not state.advance_frontier(): break
			for frame in range(200):
				state.world.advance(.05)
				if not state.world.walking: break
		check(not state.pending.is_empty(),"Reach encounter %d" % encounter)
		if state.pending.is_empty(): break
		check(state.world.input_locked,"Encounter locks movement")
		var restored := JourneyState.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(state.to_save()))),"Restore pending journey")
		check(restored.zones == original_zones and restored.pending == state.pending,"Stable encounter locations after walking and reloading")
		check(restored.battle.player[3].mode == "held","Held formation preserved")
		if encounter == 0:
			var pending_id := state.pending
			state.retreat()
			check(not state.world.input_locked and state.advance_frontier(),"Retreat unlocks and allows revisiting known encounter")
			for frame in range(200):
				state.world.advance(.05)
				if not state.world.walking: break
			check(state.pending == pending_id,"Revisit triggers same encounter")
		check(state.prepare_battle(),"Prepare encounter")
		state.battle.start()
		for frame in range(40000):
			state.battle.advance(1.0/120)
			if state.battle.phase != "battle": break
		check(state.battle.phase == "victory","Starter formation can win encounter %d: %s" % [encounter,state.battle.phase])
		if state.battle.phase != "victory": break
		check(state.settle("victory"),"Settle victory")
		var reward := state.stones
		check(not state.settle("victory") and state.stones == reward,"No duplicate reward")
	check(state.cleared.size() == 3 and state.stones == 54,"Three encounters award exactly 54 stones")
	check(state.next_island() and state.world.map_index == 1 and state.stones == 54,"Continue to next island with earned stones")
	for map_index in range(32):
		state.world.load_map(map_index)
		state.setup_zones()
		var cells := {}
		for zone in state.zones: cells[str(zone.cell)] = true
		check(cells.size() == 3,"Unique zones on map %d" % map_index)
	var session = root.get_node("Journey")
	session.SAVE = "user://journey-test-isolated.json"
	session.state = state
	check(session.save(),"First atomic save")
	state.stones = 77
	check(session.save(),"Replace existing save")
	session.state = null
	session.resume()
	check(session.state.stones == 77,"Reload saved replacement")
	DirAccess.remove_absolute(session.SAVE)
	if errors.is_empty(): print("JOURNEY_PASS real exploration, three real battles, rewards, reload, 32 maps, atomic save")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
