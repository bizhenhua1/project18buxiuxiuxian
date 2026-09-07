extends Control
var view: SegmentView
var controls := {}
var distance_slider: HSlider
var route_select: OptionButton
var note: Label
var playing := false
var clock := 0.0
var rebuilding := false
func _ready() -> void:
	StyleLibrary.active=true
	ForestSettings.values=ForestSettings.sanitized(ForestSettings.values)
	DisplayServer.window_set_title("幽暗森林 · 紧凑根盘资产版")
	playing="--walk" in OS.get_cmdline_user_args()
	var split:=HBoxContainer.new()
	split.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(split)
	var panel:=VBoxContainer.new()
	panel.custom_minimum_size.x=275
	panel.add_theme_constant_override("separation",10)
	var scroll:=ScrollContainer.new()
	scroll.custom_minimum_size.x=285
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	scroll.add_child(panel)
	var title:=Label.new()
	title.text="森林场景调校"
	title.add_theme_font_size_override("font_size",24)
	panel.add_child(title)
	if get_tree().has_meta("forest_lab_return_style"):
		button(panel,"返回主岛",func():
			StyleLibrary.active=bool(get_tree().get_meta("forest_lab_return_style"))
			get_tree().remove_meta("forest_lab_return_style")
			get_tree().change_scene_to_file("res://scenes/home.tscn"))
	var presets:=OptionButton.new()
	for key in ForestSettings.PRESETS: presets.add_item(key)
	panel.add_child(presets)
	presets.item_selected.connect(func(index):
		ForestSettings.values.merge(ForestSettings.PRESETS[presets.get_item_text(index)],true)
		for key in controls: controls[key].value=ForestSettings.values[key]
		rebuild())
	for entry in [["density","树木密度",.5,2.5,.05],["size","树木大小",.65,1.4,.05],["cover","地被覆盖",.3,2,.05],["width","道路半宽",26,65,1],["variation","宽窄变化",0,18,1],["bend","小弯幅度",0,30,1],["height","地面浅起伏",0,2,.1]]:
		var row:=HBoxContainer.new()
		var label:=Label.new()
		label.text=entry[1]
		label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var spin:=SpinBox.new()
		spin.min_value=entry[2];spin.max_value=entry[3];spin.step=entry[4]
		spin.value=ForestSettings.values[entry[0]]
		row.add_child(spin)
		controls[entry[0]]=spin
		panel.add_child(row)
	var camera_presets:=OptionButton.new()
	for key in ForestSettings.CAMERA_PRESETS:camera_presets.add_item(key)
	panel.add_child(camera_presets)
	camera_presets.item_selected.connect(func(index):
		ForestSettings.values.merge(ForestSettings.CAMERA_PRESETS[camera_presets.get_item_text(index)],true)
		for key in ForestSettings.CAMERA_PRESETS["原版视角"]:controls[key].value=ForestSettings.values[key])
	for entry in [["camera_height","机位高度",30,80,1],["camera_horizon","地平线位置",.35,.65,.01],["camera_lens","镜头倍率",.75,1.25,.01]]:
		var row:=HBoxContainer.new()
		var label:=Label.new();label.text=entry[1];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var spin:=SpinBox.new();spin.min_value=entry[2];spin.max_value=entry[3];spin.step=entry[4]
		spin.value=ForestSettings.values[entry[0]]
		spin.value_changed.connect(func(value):ForestSettings.values[entry[0]]=value)
		row.add_child(spin);panel.add_child(row);controls[entry[0]]=spin
	var hint:=Label.new();hint.text="镜头即时生效，无需重建。\n保持地平线数值，调整高度与视野。";hint.add_theme_font_size_override("font_size",12);panel.add_child(hint)
	button(panel,"应用并预览",rebuild)
	button(panel,"保存为游戏森林设置",func():
		rebuild()
		ForestSettings.save()
		note.text="已保存；重新进入风格 2 局内生效。")
	route_select=OptionButton.new()
	for key in ["直路","岔路 · 左","岔路 · 右"]: route_select.add_item(key)
	panel.add_child(route_select)
	route_select.item_selected.connect(func(_index):rebuild())
	button(panel,"行走 / 暂停",func():playing=not playing)
	distance_slider=HSlider.new()
	distance_slider.min_value=0;distance_slider.max_value=3600;distance_slider.step=1
	panel.add_child(distance_slider)
	note=Label.new()
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size=Vector2(270,140)
	note.text="拖动进度查看整条路线。参数应用后重建，保存后供下次局内使用。树干与根盘避让所有岔路。"
	panel.add_child(note)
	var host:=Control.new()
	host.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	split.add_child(host)
	view=SegmentView.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(view)
	rebuild()
func button(parent: Node,title: String,action: Callable) -> void:
	var b:=Button.new();b.text=title;b.pressed.connect(action);parent.add_child(b)
func rebuild() -> void:
	if rebuilding:return
	rebuilding=true
	for key in controls: ForestSettings.values[key]=controls[key].value
	var art:=ForestArt.new()
	var zone: Dictionary={"theme":"forest"}
	if route_select.selected!=0:zone.route_kind="fork"
	var world:=SegmentWorld.new(art,LocalRouteSpec.plan(zone))
	for sprite in world.sprites: sprite.silhouette=world.assets.silhouette(sprite.texture,sprite.region.space.atmosphere.depth_color)
	for child in view.get_children():
		view.remove_child(child)
		child.queue_free()
	view.setup(art,world,1,ThemeDB.fallback_font)
	rebuilding=false
func _process(delta: float) -> void:
	if not view or not view.renderer:return
	clock+=delta
	if playing:distance_slider.value=fmod(distance_slider.value+delta*120,3600)
	var s:=distance_slider.value
	var branch:=0 if route_select.selected==0 else -1 if route_select.selected==1 else 1
	var pose:=ForestRoute.pose(s,branch)
	view.sync(pose.position,pose.heading,clock,1 if playing else 0,branch,false,false,s)
