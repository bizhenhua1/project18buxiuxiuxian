extends SceneTree
func _initialize() -> void: call_deferred("run")
func shot() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func run() -> void:
	root.size=Vector2i(900,700)
	root.gui_disable_input=true
	var model:=IslandModel.new()
	for cell in model.cells: cell.feat=null
	var view:=IslandView3D.new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.setup(model,IslandAssets.new())
	view.set_process(false)
	view.hero.visible=false
	DirAccess.make_dir_recursive_absolute("res://captures/fog-depth")
	var known: Dictionary=view.tiles[model.player]
	known.top.material_override=view.surface("",Color(1,0,1))
	for heading in range(8):
		model.heading=heading
		model.zoom=1.5
		view._process(0.0)
		for tile in view.tiles.values(): tile.wisp.visible=false
		var fog_image: Image=await shot()
		fog_image.save_png("res://captures/fog-depth/%d.png" % heading)
		for tile in view.tiles.values():
			tile.fog.visible=false
			tile.top.visible=true
			tile.body.visible=true
		var reference: Image=await shot()
		var total:=0
		var missing:=0
		for y in range(700):
			for x in range(900):
				var color:=reference.get_pixel(x,y)
				if color.r>0.6 and color.b>0.6 and color.g<0.2:
					total+=1
					var actual:=fog_image.get_pixel(x,y)
					if actual.r<0.6 or actual.b<0.6 or actual.g>0.2: missing+=1
		assert(total>100)
		assert(float(missing)/total<0.025,"Fog incorrectly covers known top: heading %d, missing %d/%d" % [heading,missing,total])
	print("FOG_DEPTH_PASS: known top visibility matches native geometry at eight headings")
	quit()

