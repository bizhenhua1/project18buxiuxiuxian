extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var source := ForestArt.new(load("res://profiles/forest.tres"))
	var cached := ForestArt.new()
	var errors := []
	var world := ForestWorld.new(source)
	if cached.route_coordinates.size() != world.sprites.size(): errors.append("Route cache count")
	else:
		for i in range(world.sprites.size()):
			if cached.route_coordinates[i] != RoutePlan.coordinate(world.sprites[i].position): errors.append("Route coordinate mismatch")
	for key in source.textures:
		if source.textures[key].get_image().get_data() != cached.textures[key].get_image().get_data(): errors.append(key)
	for pair in [[source.patches,cached.patches],[source.low_patches,cached.low_patches],[source.clouds,cached.clouds]]:
		for i in range(pair[0].size()):
			if pair[0][i].get_image().get_data() != pair[1][i].get_image().get_data(): errors.append(str(i))
	var texture: Texture2D = source.textures["tree-side"]
	var before := texture.get_image().get_data()
	SpaceAssets.new().silhouette(texture,Color("203029"))
	if texture.get_image().get_data() != before: errors.append("Silhouette mutated original")
	if errors.is_empty(): print("PREPARED_ART_PASS all texture/mipmap bytes match original generation; masks preserve original")
	else: push_error(str(errors))
	quit(0 if errors.is_empty() else 1)
