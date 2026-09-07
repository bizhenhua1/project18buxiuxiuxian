extends SceneTree
var errors: Array[String] = []
func check(ok: bool, label_value: String) -> void:
	if not ok: errors.append(label_value)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,960)
	var model := IslandModel.new()
	var fixtures: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_reference.json"))
	for fixture in fixtures:
		model.load_map(int(fixture.mapIndex))
		model.explored.clear()
		for id in fixture.explored:
			var parts: PackedStringArray = id.split(",")
			model.remember(Vector2i(int(parts[0]),int(parts[1])))
		model.player = Vector2i(fixture.player[0],fixture.player[1])
		model.update_sight()
		check(model.vision_radius() == fixture.radius,"Original JS vision radius")
		var sight: Array[String] = []
		for p in model.sight: sight.append("%d,%d" % [p.x,p.y])
		sight.sort()
		check(sight == Array(fixture.sight,TYPE_STRING,"",null),"Original JS LOS map %d" % fixture.mapIndex)
		for item in fixture.levels: check(model.level(Vector2i(item.key[0],item.key[1])) == item.level,"Original JS fog level")
	model.load_map(0)
	check(model.explored.size() == 1,"Sight does not reveal unexplored terrain")
	var destination := Vector2i(-999,-999)
	for offset in IslandModel.NBS:
		if model.can_visit(model.player+offset):
			destination = model.player+offset
			break
	check(model.go_to(destination),"Adjacent frontier can be entered")
	model.advance(.18)
	check(model.explored.size() == 1 and model.walking,"Walking reveals only on arrival")
	model.rotate_view(1)
	check(model.spin_direction == 0,"Cannot rotate mid step")
	model.advance(.18)
	check(model.player == destination and model.explored.size() == 2,"Arrival reveals exactly one tile")
	model.preview_all = true
	check(model.explored.size() == 2,"Art preview cannot unlock exploration")
	var saved := model.to_save()
	var restored := IslandModel.new()
	check(restored.restore(saved),"Restore valid save")
	check(restored.explored == model.explored and restored.player == model.player,"Save preserves exploration/player")
	var invalid := saved.duplicate(true)
	invalid.map_index = 1
	invalid.player = [999,999]
	check(not restored.restore(invalid) and restored.map_index == 0 and restored.player == model.player,"Invalid save leaves live state intact")
	model.rotate_view(1)
	model.advance(.075)
	check(model.angles().x > 0 and is_zero_approx(model.angles().y),"Original two-stage easing remains in A")
	model.advance(.225)
	check(model.heading == 1 and is_equal_approx(model.angles().x,model.angles().y),"Rotation settles both transforms")
	var app = load("res://scenes/world_study.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	var planar: IslandView2D = app.views[0]
	var solid: IslandView3D = app.views[1]
	for map_index in range(app.model.samples.size()):
		app.model.load_map(map_index)
		solid._process(0)
		for tile in solid.tiles.values():
			var box: BoxMesh = tile.body.mesh
			var top_y: float = tile.root.position.y
			check(is_equal_approx(top_y+tile.body.position.y+box.size.y/2,top_y),"Cliff preserves walkable top")
			check(is_equal_approx(top_y+tile.body.position.y-box.size.y/2,solid.bedrock_y),"All columns meet shared bedrock without vertical gaps")
			check(box.size.y >= IslandView3D.BASE_DEPTH-0.0001,"Minimum floating island thickness")
			var uv_origin: Vector2 = tile.body.material_override.get_shader_parameter("grid_origin")
			var expected_origin := Vector2(-float(tile.cell.r),float(tile.cell.c))*sqrt(.5)
			check(uv_origin.is_equal_approx(expected_origin),"Rock texture anchored in unrotated grid coordinates")

	app.model.load_map(0)
	var geometry_checks := 0
	for heading in range(8):
		app.model.heading = heading
		planar._process(0)
		solid._process(0)
		for cell in app.model.cells:
			var expected := planar.projection.position(cell.c,cell.r,cell.h)
			var actual := solid.camera.unproject_position(solid.world_position(cell.c,cell.r,cell.h))
			check(expected.distance_to(actual) < 0.2,"2D/3D orthographic position parity at heading %d" % heading)
			geometry_checks += 1
		check(solid.tiles.values()[0].body.mesh is BoxMesh,"B uses actual volumetric cubes")
	app.model.heading = 0
	solid._process(0)
	planar._process(0)
	var matched_pick := false
	for cell in app.model.cells:
		var k := IslandModel.key(cell)
		var point := planar.projection.position(cell.c,cell.r,cell.h)
		if planar.projection.pick(point,true) == k and solid.pick(point,true) == k and app.model.can_visit(k) and k != app.model.player:
			var event := InputEventMouseButton.new()
			event.pressed = true
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = solid.global_position+point
			event.global_position = event.position
			var motion := InputEventMouseMotion.new()
			motion.position = event.position
			motion.global_position = event.position
			root.push_input(motion,true)
			root.push_input(event,true)
			event.pressed = false
			root.push_input(event,true)
			matched_pick = app.model.walking
			break
	check(matched_pick,"Native 3D ray picking can start real shared movement")
	app.focus(2)
	check(not app.panels[0].visible and app.panels[1].visible,"View switching preserves shared model")
	if errors.is_empty(): print("PASS: %d original-JS world fixtures, LOS/fog, movement/reveal, save, dual easing, %d projection positions, real 3D meshes and ray picking" % [fixtures.size(),geometry_checks])
	else:
		for error in errors.slice(0,20): push_error(error)
		print("FAIL count=%d" % errors.size())
	quit(0 if errors.is_empty() else 1)
