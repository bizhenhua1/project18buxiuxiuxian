extends SceneTree
func _initialize() -> void:call_deferred("run")
func buttons(node:Node,text:String) -> Array:
	var found:Array=[]
	if node is Button and node.text==text:found.append(node)
	for child in node.get_children():found.append_array(buttons(child,text))
	return found
func run() -> void:
	var session=root.get_node("Journey")
	session.SAVE="user://camera-entry-test.json"
	session.state=JourneyState.new()
	var original=session.state
	change_scene_to_file("res://scenes/home.tscn")
	for i in range(5):await process_frame
	buttons(current_scene,"森林场景调校")[0].pressed.emit()
	for i in range(5):await process_frame
	assert(StyleLibrary.active)
	buttons(current_scene,"返回主岛")[0].pressed.emit()
	for i in range(5):await process_frame
	assert(not StyleLibrary.active and session.state==original)
	StyleLibrary.active=true
	session.state.pending=session.state.zones[0].id
	change_scene_to_file("res://scenes/expedition_route.tscn")
	for i in range(5):await process_frame
	buttons(current_scene,"镜头调校")[0].pressed.emit()
	for i in range(3):await process_frame
	var dialog:Window
	for child in current_scene.get_children():
		if child is Window:dialog=child
	assert(dialog!=null)
	buttons(dialog,"关闭 · 保留本次预览")[0].pressed.emit()
	print("CAMERA_GAME_ENTRY_PASS home/lab/return preserves state and style; actual expedition camera window opens")
	quit()
