extends Control
var model := IslandModel.new()
var assets := IslandAssets.new()
var views: Array[Control] = []
var panels: Array[Control] = []
var status: Label
var message: Label
var reveal_button: CheckButton
func _ready() -> void:
	theme = StudyUI.theme()
	var column := StudyUI.column(self)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := StudyUI.label("浮岛 · 两种空间",28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(StudyUI.button("战斗小样",func():get_tree().change_scene_to_file("res://scenes/battle_study.tscn")))
	top.add_child(StudyUI.button("局内冒险",func():get_tree().change_scene_to_file("res://scenes/space_study.tscn")))
	top.add_child(StudyUI.button("目录",func():get_tree().change_scene_to_file("res://scenes/study_hub.tscn")))
	column.add_child(StudyUI.label("相同岛屿、相同探索进度 · 点击相邻未知地块探路，点击已探索地块行走",17))
	var bar := HFlowContainer.new()
	column.add_child(bar)
	for spec in [["并排比较",0],["单看 2D",1],["单看 3D",2]]:
		var mode: int = spec[1]
		bar.add_child(StudyUI.button(spec[0],func():focus(mode)))
	bar.add_child(StudyUI.button("↶ 旋转",func():model.rotate_view(-1)))
	bar.add_child(StudyUI.button("旋转 ↷",func():model.rotate_view(1)))
	bar.add_child(StudyUI.button("－",func():model.zoom_goal = maxf(.42,model.zoom_goal/1.2)))
	bar.add_child(StudyUI.button("＋",func():model.zoom_goal = minf(2.4,model.zoom_goal*1.2)))
	var reveal := CheckButton.new()
	reveal_button = reveal
	reveal.text = "全貌预览"
	reveal.toggled.connect(func(value):model.preview_all = value)
	bar.add_child(reveal)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",16)
	column.add_child(row)
	for i in range(2):
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		panels.append(panel)
		panel.add_child(StudyUI.label("A · 原投影 / 双阶段旋转" if i == 0 else "B · 实体地块 / 刚体旋转",19))
		var view: Control = IslandView2D.new() if i == 0 else IslandView3D.new()
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		view.custom_minimum_size = Vector2(200,200)
		panel.add_child(view)
		view.setup(model,assets)
		views.append(view)
	status = StudyUI.label("")
	column.add_child(status)
	var bottom := HFlowContainer.new()
	column.add_child(bottom)
	bottom.add_child(StudyUI.button("换一座样本岛",func():model.load_map(model.map_index+1)))
	bottom.add_child(StudyUI.button("重新探索",func():model.load_map(model.map_index)))
	bottom.add_child(StudyUI.button("保存探索",save_state))
	bottom.add_child(StudyUI.button("读取探索",load_state))
	message = StudyUI.label("Q / E 旋转 · 滚轮缩放 · 全貌预览不会解锁地块")
	bottom.add_child(message)
	print("WORLD_STUDY_READY cells=%d native_2d_and_3d=true" % model.cells.size())
func focus(mode: int) -> void:
	panels[0].visible = mode != 2
	panels[1].visible = mode != 1
func _process(dt: float) -> void:
	model.advance(dt)
	if not status: return
	var hover_text := ""
	if model.lookup.has(model.hover): hover_text = " · 指向 (%d,%d)：%s" % [model.hover.x,model.hover.y,"可行走" if model.can_visit(model.hover) else "尚未连通"]
	status.text = "样本 %d / %d · 已探索 %d / %d · 朝向 %d° · 缩放 %.0f%%%s" % [model.map_index+1,model.samples.size(),model.explored.size(),model.cells.size(),model.heading*45,model.zoom*100,hover_text]
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_LEFT,KEY_RIGHT]:
		model.rotate_view(-1 if event.keycode == KEY_LEFT else 1)
		get_viewport().set_input_as_handled()
func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode in [KEY_Q,KEY_A,KEY_LEFT]: model.rotate_view(-1)
	if event.keycode in [KEY_E,KEY_D,KEY_RIGHT]: model.rotate_view(1)
func save_state() -> void:
	var file := FileAccess.open("user://island_study.json",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(model.to_save()))
		message.text = "探索已保存到本机"
	else: message.text = "保存失败"
func load_state() -> void:
	if not FileAccess.file_exists("user://island_study.json"):
		message.text = "尚无本机存档"
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://island_study.json"))
	message.text = "探索已恢复" if data is Dictionary and model.restore(data) else "存档无效"
