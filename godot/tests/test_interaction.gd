extends SceneTree

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	# Actual UI signals are wired to the shared controller, keeping A/B synchronized.
	scene.left_button.pressed.emit()
	check(scene.branch == -1 and scene.phase == "travel", "left button starts left route")
	scene.pause_button.pressed.emit()
	var before: float = scene.distance
	for i in range(4):
		await process_frame
	check(scene.distance == before, "pause freezes route progress")
	scene._focus(1)
	check(scene.panels[0].visible and not scene.panels[1].visible, "focus A")
	scene._focus(2)
	check(not scene.panels[0].visible and scene.panels[1].visible, "focus B")
	scene.camera = ForestRoute.point_at(3650, -1)
	scene.heading = -ForestRoute.TURN_ANGLE
	check(absf(scene._landmark_bearing(0, -1) - 23.6473) < 0.01, "hidden A telemetry uses live camera")
	check(absf(scene._landmark_bearing(1, -1)) < 0.01, "visible B target remains forward")
	scene._focus(0)
	check(scene.panels[0].visible and scene.panels[1].visible, "restore comparison")
	scene.reset()
	check(scene.branch == 0 and scene.distance == 0 and not scene.paused, "reset restores identical starting state")
	# Exercise input propagation through Godot, not just a direct controller call.
	var key := InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(scene.branch == 1 and scene.phase == "travel", "right arrow routed to choice")
	key = InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(scene.branch == 0 and scene.phase == "approach", "R routed to reset")
	scene.queue_free()
	await process_frame
	if errors.is_empty():
		print("PASS: left button, pause, A/B focus, reset, right-arrow input, R input")
		quit(0)
	else:
		for error in errors:
			push_error(error)
		quit(1)

func check(value: bool, message: String) -> void:
	if not value:
		errors.append(message)
