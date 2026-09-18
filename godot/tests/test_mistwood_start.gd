extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path:="user://mistwood-game.json"
	var existed:=FileAccess.file_exists(path)
	var bytes:=FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
	var session=root.get_node("Journey")
	session.state=JourneyState.new();session.set_process(false)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	for i in range(12):await process_frame
	assert(StyleLibrary.active)
	assert(current_scene.scene_file_path=="res://scenes/expedition_route.tscn")
	assert(current_scene.camera_button.visible)
	assert(current_scene.world.sprites.size()>1000)
	assert(current_scene.native_route_view!=null and current_scene.native_route_view.visible)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../tempassets/work/migration-default-start.png")
	if existed:
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(bytes);file.close()
	else:DirAccess.remove_absolute(path)
	current_scene.set_process(false);session.state=null
	print("DEFAULT_START_PASS actual project main scene enters style2 playable forest with camera controls")
	quit()
