extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state:=JourneyState.new()
	var count:=0
	for index in range(32):
		state.world.load_map(index)
		state.setup_zones()
		for cell in state.world.cells:
			if cell.layer!="water": continue
			count+=1
			assert(cell.bed_h<cell.water_level)
			var p:=IslandModel.key(cell)
			for edge in range(4):
				var next: Vector2i=p+IslandModel.NBS[edge]
				if not state.world.lookup.has(next):
					assert(cell.waterfall_edges.has(edge),"Every exposed edge has water")
					continue
				assert(not cell.waterfall_edges.has(edge),"No fall inside water or into a higher bank")
				var other: Dictionary=state.world.lookup[next]
				if other.layer=="water":
					assert(is_equal_approx(float(cell.h),float(other.h)))
					assert(cell.water_banks[edge]==0.0)
				else:
					assert(float(cell.h)<float(other.h))
					assert(cell.water_banks[edge]==1.0)
		var before:=JSON.stringify(state.world.cells)
		IslandWater.solve(state.world.cells)
		assert(before==JSON.stringify(state.world.cells),"Water solve is idempotent")
	root.size=Vector2i(1100,820)
	state.world.load_map(0)
	state.setup_zones()
	state.world.preview_all=true
	state.world.zoom=1.65
	var view:=IslandView3D.new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.setup(state.world,IslandAssets.new())
	DirAccess.make_dir_recursive_absolute("res://captures/island-water")
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/island-water/outlet.png")
	for heading in range(8):
		view.model.heading=heading
		for frame in range(4): await process_frame
		for tile in view.tiles.values():
			if tile.waterfall != null:
				assert(tile.waterfall.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==tile.cell.waterfall_edges.size()*4)
				assert(tile.waterfall.visible)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/island-water/angle-%d.png" % heading)
	view.model.heading=0
	view.model.preview_all=false
	for cell in view.model.cells: view.model.remember(IslandModel.key(cell))
	view.model.sight.clear()
	for frame in range(4): await process_frame
	for tile in view.tiles.values():
		if tile.waterfall != null:
			var style:=view.model.style(IslandModel.key(tile.cell))
			assert(style.bright<0.8)
			assert(is_equal_approx(tile.waterfall.material_override.get_shader_parameter("brightness"),style.bright))
			assert(is_equal_approx(tile.waterfall.material_override.get_shader_parameter("saturation"),style.sat))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/island-water/out-of-sight.png")
	view.model.preview_all=true
	var pond: Array=[]
	for x in range(5):
		for y in range(5):
			var wet:=x>0 and x<4 and y>0 and y<4
			pond.append({"c":x,"r":y,"h":0,"layer":"water" if wet else "land","base":"assets/world/forest/base/water_1.png" if wet else "assets/world/forest/base/grass_1.png","feat":null})
	IslandWater.solve(pond)
	for cell in pond:
		if cell.layer=="water":
			assert(cell.waterfall_edge==-1 and cell.water_kind=="pond")
			assert(is_equal_approx(cell.h,-0.35))
	view.model.cells=pond
	view.model.lookup.clear()
	view.model.pivot=Vector2.ZERO
	for cell in pond:
		view.model.lookup[IslandModel.key(cell)]=cell
		view.model.pivot+=IslandModel.wxz(cell.c,cell.r)/25.0
	view.model.player=Vector2i.ZERO
	view.rebuild()
	for frame in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/island-water/pond.png")
	print("ISLAND_WATER_PASS: %d water cells across 32 maps, level continuity, bed/shore heights, shoreline adjacency, idempotence, GPU rendering" % count)
	quit()
