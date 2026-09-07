extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1800,1100)
	var app = load("res://scenes/material_study.tscn").instantiate()
	root.add_child(app)
	DirAccess.make_dir_recursive_absolute("res://captures/material-study")
	for index in range(4):
		app.select_material(index)
		for frame in range(6): await process_frame
		for view in app.views:
			for tile in view.tiles.values():
				assert(tile.body.mesh is BoxMesh,"Material studies must retain A geometry")
				var box: BoxMesh = tile.body.mesh
				assert(is_equal_approx(box.size.x,sqrt(0.5)))
				assert(is_equal_approx(float(tile.cell.h)*IslandView3D.HEIGHT+tile.body.position.y-box.size.y/2,view.bedrock_y))
				assert(tile.body.material_override.shader.code.contains("uniform float fade_height = 0.85;"))
				if not view.atlas_path.is_empty():
					assert(tile.body.material_override.get_shader_parameter("atlas") is Texture2D)
					assert(tile.top.material_override.get_shader_parameter("atlas") is Texture2D)
					var top_texture: Texture2D = tile.top.material_override.get_shader_parameter("atlas")
					var side_texture: Texture2D = tile.body.material_override.get_shader_parameter("atlas")
					assert(top_texture != side_texture,"Top and cliff mipmaps must be isolated")
					assert(top_texture.get_height() < 500 and side_texture.get_height() < 500,"Do not bind the full multi-material atlas")
					assert(top_texture.get_image().has_mipmaps() and side_texture.get_image().has_mipmaps())
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://captures/material-study/%s.png" % app.BASES[index])
	app.select_material(2)
	for view in app.views: view.model.heading = 1
	for frame in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/material-study/turned.png")
	print("CAPTURE_MATERIAL_STUDY_PASS")
	quit()
