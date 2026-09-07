extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	# Explicit settings bypass the runtime cache: always rebuild from source.
	var art := ForestArt.new(load("res://profiles/forest.tres"))
	var result := PreparedForestArt.new()
	result.textures = art.textures
	result.patches = art.patches
	result.low_patches = art.low_patches
	result.clouds = art.clouds
	var world := ForestWorld.new(art)
	for sprite in world.sprites: result.route_coordinates.append(RoutePlan.coordinate(sprite.position))
	var assets := SpaceAssets.new()
	var color: Color = load("res://spaces/types/forest.tres").atmosphere.depth_color
	for texture in art.textures.values()+art.patches+art.low_patches:
		result.silhouettes.append({"texture":texture,"color":color,"result":assets.silhouette(texture,color)})
	DirAccess.make_dir_recursive_absolute("res://assets/prepared")
	var error := ResourceSaver.save(result,"res://assets/prepared/forest_art.res",ResourceSaver.FLAG_COMPRESS)
	var inputs := {}
	var paths := ["res://scripts/art_library.gd","res://scripts/forest_world.gd","res://scripts/route.gd","res://scripts/spaces/route_plan.gd","res://scripts/spaces/space_assets.gd","res://profiles/forest.tres","res://spaces/types/forest.tres","res://assets/landmarks/island-far.png"]
	for name_value in DirAccess.get_files_at("res://assets/forest"):
		if name_value.ends_with(".png"): paths.append("res://assets/forest/"+name_value)
	for path in paths: inputs[path] = FileAccess.get_sha256(path)
	var manifest := FileAccess.open("res://assets/prepared/manifest.json",FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"inputs":inputs,"output_sha256":FileAccess.get_sha256("res://assets/prepared/forest_art.res")},"\t"))
	print("BAKE_PASS" if error == OK else "BAKE_FAIL")
	quit(error)
