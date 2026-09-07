extends SceneTree

func _initialize() -> void:
	var renderer := CorridorRenderer.new()
	var start := renderer.sun_projection(500, 300, 450).rect as Rect2
	renderer.camera_world = Vector2(2000, 3650)
	assert(renderer.sun_projection(500, 300, 450).rect == start, "Sun has no translation parallax")
	renderer.heading = 0.5
	var turned := renderer.sun_projection(500, 300, 450).rect as Rect2
	assert(turned.get_center().x < start.get_center().x, "Right yaw moves sun left")
	var profile := load("res://profiles/forest.tres") as AtmosphereProfile
	var field := SkyField.new(profile)
	var previous_drift := INF
	var previous_radial := INF
	for index in range(3):
		var before := field.cell(index, Vector2i(0, 2), 0)
		var after := field.cell(index, Vector2i(0, 2), 20)
		assert(before.position.y == after.position.y, "Idle clouds do not advance in depth")
		assert(after.position.x > before.position.x, "All layers have idle lateral wind")
		var drift: float = (after.position.x - before.position.x) / before.position.y
		assert(drift < previous_drift, "Near cloud lateral motion is stronger than distant layers")
		previous_drift = drift
		var radial: float = 0.35 * before.position.y / (before.position.y - 1000) - 0.35
		assert(radial > 0 and radial < previous_radial, "At equal elevation angle, forward motion raises nearer clouds more strongly")
		previous_radial = radial
		assert(field.cell(index, Vector2i(-3, 4), 20) == field.cell(index, Vector2i(-3, 4), 20), "Seeded world cells are deterministic")
	var first := field.visible_clouds(Vector2.ZERO, 12)
	var shifted := field.visible_clouds(Vector2(200, 300), 12)
	var shared := 0
	for a in first:
		for b in shifted:
			if a.id == b.id:
				assert(a.position == b.position, "Camera motion never drags cloud world positions")
				shared += 1
	assert(shared > 10, "Moving views retain the same cloud field")
	var bright := profile.duplicate() as AtmosphereProfile
	bright.depth_color = Color(0.95, 0.84, 0.6)
	var bright_field := SkyField.new(bright)
	assert(bright_field.profile.depth_color.r > field.profile.depth_color.r, "Stage profiles can use a luminous horizon")
	renderer.free()
	print("PASS: celestial invariance, layered wind/parallax, no idle radial drift, stable world cells, theme profiles")
	quit()
