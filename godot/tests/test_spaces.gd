extends SceneTree
func _initialize() -> void:
	call_deferred("check_spaces")
func check_spaces() -> void:
	for key in ["connected","cave","cloudsea"]:
		var plan := load("res://spaces/routes/%s.tres" % key) as RoutePlan
		assert(plan.validate().is_empty(), str(plan.validate()))
	var plan := load("res://spaces/routes/connected.tres") as RoutePlan
	assert(plan.at(1899.99,-1).space.key == &"forest")
	assert(plan.at(1900,-1).space.key == &"cave")
	assert(plan.at(1900,1).space.key == &"cloudsea")
	var broken := plan.copy_for_editing()
	broken.regions[2].start += 2
	assert(not broken.validate().is_empty(), "Reject a gap instead of silently using global type")
	var art := ForestArt.new()
	var world := SegmentWorld.new(art,plan)
	var original_position: Vector2 = world.sprites[50].position
	var original_count := world.sprites.size()
	for s in [1779.0,1780.0,1850.0,1899.99,1900.0,1900.01,2000.0,2060.0,2200.0]:
		world.update_camera(s,-1)
		var environment := world.environment()
		assert(environment.weight >= 0 and environment.weight <= 1)
		assert(world.sprites.size() == original_count and world.sprites[50].position == original_position, "Camera never replaces region geometry")
	world.update_camera(1899.99,-1)
	var before: float = world.environment().weight
	world.update_camera(1900.01,-1)
	assert(absf(world.environment().weight-before) < 0.001, "Continuous entry lighting at region boundary")
	var cave_plan := load("res://spaces/routes/cave.tres") as RoutePlan
	var ceiling_world := SegmentWorld.new(art,cave_plan)
	var roof_count := 0
	for sprite in ceiling_world.sprites:
		if sprite.motion == "shell": roof_count += 1
	assert(roof_count > 10, "Ceiling strategy generates enclosure slices")
	var open_plan := cave_plan.copy_for_editing()
	for region in open_plan.regions: region.space.ceiling_enabled = false
	var open_world := SegmentWorld.new(art,open_plan)
	for sprite in open_world.sprites: assert(sprite.motion != "shell", "Roof is an optional structural capability")
	assert(cave_plan.regions[0].space.ceiling_enabled, "Variant cannot mutate registered source resource")
	var variants := cave_plan.copy_for_editing()
	var alternate := variants.regions[1].space.duplicate(false) as SpaceType
	alternate.atmosphere = alternate.atmosphere.duplicate(true) as AtmosphereProfile
	alternate.atmosphere.depth_color = Color(0.6,0.4,0.2)
	variants.regions[1].space = alternate
	var variant_world := SegmentWorld.new(art,variants)
	assert(variant_world.fields.size() == 2, "Same family can have independent atmosphere variants on different route segments")
	var app = load("res://scenes/space_study.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.left_button.pressed.emit()
	assert(app.branch == -1)
	app.pause_button.pressed.emit()
	var distance: float = app.distance
	await process_frame
	assert(app.distance == distance)
	app.reset()
	assert(app.distance == 0 and app.branch == 0)
	app.load_preset("cloudsea")
	await process_frame
	assert(app.world.camera_region.space.key == &"cloudsea")
	app.load_preset("cave")
	await process_frame
	assert(app.world.camera_region.space.ceiling_enabled)
	print("PASS: typed plans, boundary ownership, gap rejection, persistent geometry, entry continuity, optional ceiling, resource isolation, study controls/presets")
	quit()
