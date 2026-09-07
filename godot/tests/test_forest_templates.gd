extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	StyleLibrary.active=true
	root.size=Vector2i(1500,950)
	for preset in ForestSettings.PRESETS:
		ForestSettings.values=ForestSettings.PRESETS[preset].duplicate()
		for fork in [false,true]:
			var zone:Dictionary={"theme":"forest"}
			if fork:zone.route_kind="fork"
			var world:=SegmentWorld.new(ForestArt.new(),LocalRouteSpec.plan(zone))
			var trees:=0
			for sprite in world.sprites:
				if sprite.kind!=0:continue
				trees+=1
				assert(sprite.get("root_cover",[]).size()==5,"Every tree owns root cover")
				for cover in sprite.root_cover:assert(cover.has("silhouette"))
				var distance:=ForestRoute.road_distance(sprite.position) if fork else absf(sprite.position.x)
				var required:=maxf(26,ForestEcology.half_width(sprite.route_s))+float(sprite.trunk_radius)+8
				assert(distance>=required-.01,"Tree intersects route")
			print("FOREST_TEMPLATE ",preset," fork=",fork," trees=",trees)
			assert(trees>200)
	ForestSettings.values=ForestSettings.PRESETS["幽暗密林"].duplicate()
	var app=load("res://scenes/forest_lab.tscn").instantiate()
	root.add_child(app)
	await process_frame
	DirAccess.make_dir_recursive_absolute("res://captures/forest-templates")
	for direction in [0,1,2]:
		app.route_select.selected=direction
		app.rebuild()
		for s in [300,1200,2400,3300]:
			app.distance_slider.value=s
			for i in range(3):await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://captures/forest-templates/route-%d-%d.png"%[direction,s])
	print("FOREST_TEMPLATES_PASS 3 presets, trunk envelope clearance on both branches, 12 review captures")
	quit()
