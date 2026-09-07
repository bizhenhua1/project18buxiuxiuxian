extends SceneTree
var folder := "res://captures/modules-review"
func _initialize() -> void: call_deferred("run")
func shot(name_value: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+"/"+name_value+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1600,960)
	var app = load("res://scenes/world_study.tscn").instantiate()
	root.add_child(app)
	await create_timer(.3).timeout
	await shot("world-01-exploration")
	app.reveal_button.button_pressed = true
	await shot("world-02-full-island")
	app.set_process(false)
	app.model.rotate_view(1)
	app.model.advance(.075)
	await shot("world-03-turn-quarter")
	app.model.advance(.225)
	app._process(0)
	await shot("world-04-turned")
	app.model.heading = 0
	app.model.hover = Vector2i(10,9)
	app._process(0)
	await shot("world-06-hover-occlusion")
	app.model.hover = Vector2i(-999,-999)
	app.model.heading = 1
	app.focus(2)
	app._process(0)
	await shot("world-05-native-3d")
	root.size = Vector2i(1000,650)
	await shot("world-07-small-window")
	root.size = Vector2i(1600,960)
	app.queue_free()
	await process_frame
	var battle = load("res://scenes/battle_study.tscn").instantiate()
	root.add_child(battle)
	await create_timer(.3).timeout
	await shot("battle-01-formation")
	battle.start()
	await create_timer(2.0).timeout
	await shot("battle-02-fighting")
	while battle.model.phase == "battle":
		battle.speed = 4
		await process_frame
	await shot("battle-03-result")
	battle.guard_lineup()
	battle.arena.select(battle.model.player[3])
	await shot("battle-04-held-formation")
	battle.start()
	battle.speed = 1
	await create_timer(1.1).timeout
	await shot("battle-05-guard-fighting")
	battle.speed = 4
	while battle.model.phase == "battle": await process_frame
	await shot("battle-06-victory")
	root.size = Vector2i(1000,650)
	await shot("battle-07-small-window")
	print("CAPTURE_MODULES_PASS result=%s elapsed=%.2f" % [battle.model.phase,battle.model.elapsed])
	quit()
