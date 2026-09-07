extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	for i in range(12):await process_frame
	assert(StyleLibrary.active)
	assert(current_scene.scene_file_path=="res://scenes/expedition_route.tscn")
	assert(current_scene.camera_button.visible)
	assert(current_scene.world.sprites.size()>1000)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/mistwood-default-start.png")
	print("DEFAULT_START_PASS actual project main scene enters style2 playable forest with camera controls")
	quit()
