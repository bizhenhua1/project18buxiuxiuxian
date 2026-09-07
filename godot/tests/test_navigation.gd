extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func find_button(node: Node, label_value: String) -> Button:
	if node is Button and node.text == label_value: return node
	for child in node.get_children():
		var found := find_button(child,label_value)
		if found: return found
	return null
func click_label(label_value: String) -> void:
	var button := find_button(current_scene,label_value)
	if not button:
		errors.append("Missing navigation button: "+label_value)
		return
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion,true)
	var press := InputEventMouseButton.new()
	press.position = point
	press.global_position = point
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	root.push_input(press,true)
	press.pressed = false
	root.push_input(press,true)
func run() -> void:
	root.size = Vector2i(1600,960)
	change_scene_to_file("res://scenes/study_hub.tscn")
	await process_frame
	await process_frame
	for item in [["列阵试锋","battle_study","目录"],["浮岛 · 两种空间","world_study","目录"],["山林之间","space_study","样本目录"]]:
		click_label(item[0])
		await process_frame
		await process_frame
		if current_scene.scene_file_path != "res://scenes/%s.tscn" % item[1]: errors.append("Navigation did not open "+item[1])
		click_label(item[2])
		await process_frame
		await process_frame
		if current_scene.scene_file_path != "res://scenes/study_hub.tscn": errors.append("Navigation did not return to hub")
	if errors.is_empty(): print("PASS: real button input navigates hub, battle, world and spaces in both directions")
	else:
		for error in errors: push_error(error)
	quit(0 if errors.is_empty() else 1)
