extends Control
var state: JourneyState
var view: IslandView3D
var status: Label
var heading: Label
var description: Label
var portrait: TextureRect
var encounter_panel: VBoxContainer
var encounter_modal: Control
var cancel_encounter: Button
var action: Button
var forward: Button
var next_button: Button
var log_label: Label
var labels: Array[Label] = []
var saving := false
var save_message := ""
var save_message_until := 0
func _ready() -> void:
	Journey.resume()
	state = Journey.state
	state.world.zoom=2.4;state.world.zoom_goal=2.4
	theme = StudyUI.theme()
	var column := StudyUI.column(self)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := StudyUI.label("雾林调查局 · 外围辖区" if StyleLibrary.active else "云外出征 · 冒险岛",32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(StudyUI.button("保存行记",func():
		save_message = "行记已保存" if Journey.save() else "保存未成功，请稍后重试"
		save_message_until = Time.get_ticks_msec()+2500))
	top.add_child(StudyUI.button("返回目录",func():
		Journey.save()
		get_tree().change_scene_to_file("res://scenes/study_hub.tscn")))
	top.add_child(StudyUI.button("携行囊返航",func():Journey.return_home()))
	status = StudyUI.label("",17)
	column.add_child(status)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	column.add_child(body)
	view = IslandView3D.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(500,300)
	body.add_child(view)
	view.setup(state.world,IslandAssets.new())
	var ambience := IslandAmbience.new()
	view.world.add_child(ambience)
	ambience.setup(view)
	var environment := view.world.get_child(0) as WorldEnvironment
	environment.environment.background_color = Color("142829")
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size.x = 280
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation",14)
	side_scroll.add_child(side)
	side.add_child(StudyUI.label("岛上线索 · 进入局内探访",21))
	for zone in state.zones:
		var label_value := StudyUI.label("",16)
		labels.append(label_value)
		side.add_child(label_value)
	encounter_panel = VBoxContainer.new()
	encounter_panel.add_theme_constant_override("separation",10)
	encounter_modal=Control.new()
	# The modal belongs to the window canvas, not the map's expanding layout.
	var modal_layer:=CanvasLayer.new()
	modal_layer.layer=20
	add_child(modal_layer)
	modal_layer.add_child(encounter_modal)
	encounter_modal.theme=theme
	encounter_modal.position=Vector2.ZERO
	encounter_modal.size=get_viewport_rect().size
	get_viewport().size_changed.connect(func(): encounter_modal.size=get_viewport_rect().size)
	var shade:=ColorRect.new()
	shade.color=Color(0.02,0.06,0.05,0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encounter_modal.add_child(shade)
	var center:=CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	encounter_modal.add_child(center)
	var panel:=PanelContainer.new()
	panel.custom_minimum_size=Vector2(440,0)
	var backing:=StyleBoxFlat.new()
	backing.bg_color=Color("142723")
	backing.border_color=Color("85764b")
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.shadow_color=Color(0,0,0,0.45)
	backing.shadow_size=16
	panel.add_theme_stylebox_override("panel",backing)
	center.add_child(panel)
	var margins:=MarginContainer.new()
	for edge in ["left","right","top","bottom"]: margins.add_theme_constant_override("margin_"+edge,22)
	panel.add_child(margins)
	margins.add_child(encounter_panel)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(240,140)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	encounter_panel.add_child(portrait)
	heading = StudyUI.label("",24)
	encounter_panel.add_child(heading)
	description = StudyUI.label("",16)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	encounter_panel.add_child(description)
	action = StudyUI.button("进入局内冒险",func():get_tree().change_scene_to_file("res://scenes/expedition_route.tscn"))
	encounter_panel.add_child(action)
	cancel_encounter=StudyUI.button("暂不进入",func():
		state.retreat()
		Journey.save())
	encounter_panel.add_child(cancel_encounter)
	log_label = StudyUI.label("",14)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(log_label)
	var bottom := HFlowContainer.new()
	column.add_child(bottom)
	forward = StudyUI.button("向未知处前行",func():state.advance_frontier())
	bottom.add_child(forward)
	bottom.add_child(StudyUI.label("揭雾范围",16))
	var reveal_setting:=SpinBox.new()
	reveal_setting.min_value=0
	reveal_setting.max_value=12
	reveal_setting.value=state.world.reveal_range
	reveal_setting.tooltip_text="0：脚下；1：十字；2：九宫；3：十三格菱形；4：五乘五，以此扩展"
	reveal_setting.value_changed.connect(func(value):
		state.world.set_reveal_range(int(value))
		Journey.save())
	bottom.add_child(reveal_setting)
	bottom.add_child(StudyUI.button("↶ 转向",func():state.world.rotate_view(-1)))
	bottom.add_child(StudyUI.button("转向 ↷",func():state.world.rotate_view(1)))
	bottom.add_child(StudyUI.button("拉近",func():state.world.zoom_goal = minf(2.4,state.world.zoom_goal*1.15)))
	bottom.add_child(StudyUI.button("拉远",func():state.world.zoom_goal = maxf(.42,state.world.zoom_goal/1.15)))
	next_button = StudyUI.button("本岛探访完成 · 返回主岛",func():Journey.return_home())
	bottom.add_child(next_button)
	column.add_child(StudyUI.label("探索方块 → 进入局内路线 → 遭遇事件；行囊只有返航后才存入主岛。",14))
	state.updated.connect(save_on_update)
	refresh()
	print("JOURNEY_READY explored=%d cleared=%d" % [state.world.explored.size(),state.cleared.size()])
func save_on_update() -> void:
	# Arrival signals are emitted before IslandModel finishes its step bookkeeping.
	saving = true
func _process(dt: float) -> void:
	state.world.advance(dt)
	if saving:
		saving = false
		Journey.save()
	refresh()
func refresh() -> void:
	status.text = "冒险岛 %d · 已探 %d / %d · 行囊秘银 %d · 完成探访 %d / 3 · 本次线索 +%d" % [state.world.map_index+1,state.world.explored.size(),state.world.cells.size(),state.stones,state.cleared.size(),state.reward_bonus]
	if Time.get_ticks_msec() < save_message_until: status.text += " · "+save_message
	for i in range(labels.size()):
		var zone := state.zones[i]
		var p := Vector2i(zone.cell[0],zone.cell[1])
		var known := state.world.explored.has(p)
		labels[i].text = ("✓ " if state.cleared.has(zone.id) else "◇ ")+ (str(zone.title) if known else "尚未探明")
	var zone := state.active_zone()
	encounter_modal.visible = not zone.is_empty() and not state.world.rebounding
	action.disabled=state.world.walking
	cancel_encounter.disabled=state.world.walking
	if not zone.is_empty():
		heading.text = zone.title
		description.text = ("深林有岔道，可选择探索方向。" if zone.route_kind == "fork" else "一段短途探索，沿途遇见异变体或旅人。")+"\n地块探索奖励 %d 秘银，战斗所得另计。" % zone.reward
		var path: String = ["bone-hound","forest-mourner","bell-guardian"][int(zone.tier)]
		portrait.texture = load(StyleLibrary.card_path(path))
	forward.disabled = state.world.walking or not zone.is_empty() or state.cleared.size() == 3
	next_button.visible = state.cleared.size() == 3
	log_label.text = "\n".join(state.journal.slice(maxi(0,state.journal.size()-5))) if not state.journal.is_empty() else "云下无声，林间有息。\n循着闪雾，一步一步揭开此岛。"
	if StyleLibrary.active:
		for label in [status,description,log_label]: label.text = StyleLibrary.words(label.text)
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q: state.world.rotate_view(-1)
		if event.keycode == KEY_E: state.world.rotate_view(1)
