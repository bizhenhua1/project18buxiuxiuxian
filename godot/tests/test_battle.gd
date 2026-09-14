extends SceneTree
var errors: Array[String] = []
func check(ok: bool, label: String) -> void:
	if not ok: errors.append(label)
func _initialize() -> void:
	var rules := BattleRules.new()
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_reference.json"))
	for fixture in reference.stats:
		var unit := rules.create_unit(fixture.id,fixture.side,0,int(fixture.stage))
		for key in fixture.expected: check(is_equal_approx(unit[key],fixture.expected[key]),"JS stat parity: %s/%s/%s/%s" % [fixture.id,fixture.side,fixture.stage,key])
	for fixture in reference.damage:
		var target: Dictionary = fixture.input.duplicate(true)
		var events := rules.damage(target,fixture.amount,fixture.type)
		for key in ["hp","shield","status"]: check(target[key] == fixture.expected[key],"JS damage parity: "+key)
		check(events[0].dealt == fixture.expected.dealt,"JS dealt parity")
	var model := BattleModel.new()
	for fixture in reference.actions:
		var action_model := BattleModel.new()
		action_model.player = fixture.input.allies.duplicate(true)
		action_model.enemy = fixture.input.foes.duplicate(true)
		action_model.act(action_model.player[1])
		check(action_model.shots.size() == fixture.shots.size(),"JS shot count: "+fixture.id+"/"+fixture.mode)
		for i in range(mini(action_model.shots.size(),fixture.shots.size())):
			var actual: Dictionary = action_model.shots[i]
			var expected: Dictionary = fixture.shots[i]
			check(actual.from.uid == expected.from and actual.to.uid == expected.to,"JS targets: "+fixture.id)
			check(is_equal_approx(actual.amount,expected.amount) and actual.style == expected.style and actual.crit == expected.crit,"JS action damage/style/crit: "+fixture.id)
		for i in range(fixture.units.size()):
			var actual: Dictionary = (action_model.player+action_model.enemy)[i]
			for key in ["hp","shield","cdLeft","healDone"]: check(is_equal_approx(actual.get(key,0),fixture.units[i][key]),"JS action effect: "+fixture.id+"/"+key)
	model.player = [rules.create_unit("watchful-clock","player"),rules.create_unit("investigator","player",1),rules.create_unit("faceless-mask","player",2,0,"held"),rules.create_unit("scarlet-edict","player",3)]
	check(BattleRules.target(model.player).cardId == "watchful-clock","Leftmost targetable")
	BattleRules.corpse(model.player[0])
	check(BattleRules.target(model.player).cardId == "investigator","Skip corpse")
	check(not BattleRules.targetable(model.player[2]) and not BattleRules.targetable(model.player[3]),"Held and spells untargetable")
	model.emit_events([{"type":"death","unit":model.player[0]}])
	check(model.player[0].reviveLeft == 7000,"Station revive countdown")
	model.phase = "battle"
	model.enemy = [rules.create_unit("ashwing","enemy")]
	model.enemy[0].cdLeft = 100000
	for unit in model.player: unit.cdLeft = 100000
	model.advance(7.01)
	check(model.player[0].status == "alive" and model.player[0].hp == model.player[0].maxHp,"Revive original slot/full health")
	BattleRules.corpse(model.player[1])
	check(model.winner() == "defeat","Hero death defeats surviving artifacts")
	model = BattleModel.new()
	model.player = [rules.create_unit("investigator","player"),rules.create_unit("watchful-clock","player",1,0,"held")]
	model.restat()
	check(model.player[0].maxHp == 48+BattleRules.js_round(model.player[1].maxHp*0.3),"Held HP merge")
	model.act(model.player[1])
	check(model.player[1].shield == 0,"Held seals active shield")
	model.player[1].mode = "station"
	model.act(model.player[1])
	check(model.player[1].shield > 0,"Station casts shield")
	model = BattleModel.new()
	model.player = [rules.create_unit("investigator","player"),rules.create_unit("containment-record","player",1)]
	model.emit_events([{"type":"death","unit":model.enemy[0]}])
	check(model.player[1].soulStacks == 1,"Soul fan stacks on deaths")
	model = BattleModel.new()
	model.start()
	for i in range(20000):
		model.advance(0.01)
		if model.phase != "battle": break
	check(model.phase in ["victory","defeat","draw"],"Full battle reaches terminal outcome")
	var result := model.phase
	model.advance(10)
	check(model.phase == result,"Settlement does not repeat")
	if errors.is_empty(): print("PASS: 210 original-JS stat/damage cases + 48 action cases, targeting, corpses, revival, held modes/HP, fan stacks, terminal battle")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
