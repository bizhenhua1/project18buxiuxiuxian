extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	StyleLibrary.active=true
	root.size=Vector2i(1440,900)
	var art:=ForestArt.new()
	var plan:=LocalRouteSpec.plan({"theme":"forest"})
	var world:=SegmentWorld.new(art,plan)
	var repeat:=SegmentWorld.new(art,plan)
	assert(world.sprites.size()==repeat.sprites.size())
	var road_cover:=0
	var decals:=0
	for i in range(world.sprites.size()):
		var s:=world.sprites[i]
		assert(s.position==repeat.sprites[i].position)
		if absf(s.position.x-ForestEcology.center(s.route_s))<ForestEcology.half_width(s.route_s) and s.kind==1: road_cover+=1
		if s.kind==3: decals+=1
		s.silhouette=world.assets.silhouette(s.texture,s.region.space.atmosphere.depth_color)
	assert(road_cover>100 and decals>100)
	var view:=SegmentView.new()
	root.add_child(view)
	view.size=Vector2(1440,900)
	view.setup(art,world,1,ThemeDB.fallback_font)
	DirAccess.make_dir_recursive_absolute("res://captures/forest-ecology")
	var worst_ms:=0.0
	var total_ms:=0.0
	var projection_total:=0.0
	for step in range(121):
		var s:=float(step)*4.0
		view.sync(Vector2(0,s),0,s/150,1,0,false,false,s)
		await process_frame
		await RenderingServer.frame_post_draw
		worst_ms=maxf(worst_ms,view.renderer.last_draw_ms)
		total_ms+=view.renderer.last_draw_ms
		projection_total+=view.renderer.projection_ms
		if step in [0,40,80,120]: root.get_texture().get_image().save_png("res://captures/forest-ecology/walk-%03d.png"%step)
	# Compact art uses one contact plane; no independently warped root geometry.
	for tree in world.sprites:
		if tree.kind!=0:continue
		assert(tree.ground_anchor.y>.98)
		for cover in tree.root_cover:
			assert(is_equal_approx(cover.foot_y,tree.ground_anchor.y))
	print("FOREST_ECOLOGY_PASS grounded roots/cover, stable placement, road cover=",road_cover," decals=",decals," max draw ms=",worst_ms," mean draw ms=",total_ms/121," projection=",projection_total/121," visible=",view.renderer.visible_count)
	quit()
