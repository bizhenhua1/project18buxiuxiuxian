extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1440,900)
	change_scene_to_file("res://scenes/study_hub.tscn")
	await process_frame
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://captures/modules-review")
	var result := root.get_texture().get_image().save_png("res://captures/modules-review/00-directory.png")
	print("PASS: native directory capture" if result == OK else "FAIL: directory capture")
	quit(0 if result == OK else 1)
