extends SceneTree
var errors: Array[String] = []
func check(ok: bool, label_value: String) -> void:
	if not ok: errors.append(label_value)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,960)
	var app = load("res://scenes/battle_study.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var first: BattleCard = app.arena.cards[app.model.cap()]
	var second: BattleCard = app.arena.cards[app.model.cap()+1]
	var hero_uid: int = first.unit.uid
	check(second._can_drop_data(Vector2.ZERO,{"formation_index":0}),"Formation allows dragging")
	second._drop_data(Vector2.ZERO,{"formation_index":0})
	check(app.model.player[1].uid == hero_uid,"Drop moves real formation order")
	app.guard_lineup()
	check(app.model.player[0].cardId == "watchful-clock" and app.model.player[3].mode == "held","Guard sample shields hero and holds sword")
	check(app.model.player[2].maxHp > 48,"Held HP inherited in rendered formation")
	app.start_button.pressed.emit()
	check(app.model.phase == "battle","Start button launches battle")
	app.pause_button.pressed.emit()
	var time: float = app.model.elapsed
	app._process(.1)
	check(app.model.elapsed == time,"Pause freezes combat model")
	app.pause_button.pressed.emit()
	var settlement := {"count":0}
	app.model.finished.connect(func(_value):settlement.count += 1)
	for i in range(40000):
		app.model.advance(1.0/120)
		if app.model.phase != "battle": break
	check(app.model.phase == "victory","Guard formation wins original first-stage opponents")
	app.model.advance(100)
	check(settlement.count == 1 and "此战告捷" in app.log_text.get_parsed_text(),"Single settlement includes battle report")
	app.reset()
	check(app.model.phase == "prepare" and app.model.shots.is_empty(),"Reset clears flight and reopens formation")
	# Every selectable catalog card can act without a UI-specific special case.
	for spec in app.model.rules.cards:
		var model := BattleModel.new()
		model.player = [model.rules.create_unit(spec.id,"player")]
		model.enemy = [model.rules.create_unit("bell-guardian","enemy")]
		model.act(model.player[0])
		for shot in model.shots: model.resolve(shot)
	# Hero death cannot be postponed by continually launching new casts.
	var ending := BattleModel.new()
	ending.start()
	BattleRules.corpse(ending.player[0])
	for unit in ending.player: unit.cdLeft = 0
	ending.advance(.01)
	check(ending.phase == "defeat" and ending.shots.is_empty(),"Hero death stops fresh attacks and settles")
	if errors.is_empty(): print("PASS: formation drag/drop, held mode/HP, start/pause/reset, guard victory, one settlement, all 24 card actions, hero defeat")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
