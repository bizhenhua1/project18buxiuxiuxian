extends Control
var views: Array = []
func _ready() -> void:
	theme = StudyUI.theme()
	var column := StudyUI.column(self)
	column.add_child(StudyUI.label("崖沿对照 · 同一材质、光照与镜头",28))
	column.add_child(StudyUI.label("上排：草地 / 石地近景　下排：整岛尺度　Q / E 同步旋转　仅为小样，未替换正式方案",17))
	column.add_child(StudyUI.button("返回样本目录",func():get_tree().change_scene_to_file("res://scenes/study_hub.tscn")))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var names := ["A · 恢复基线","B · 窄倒角","C · 局部缺口 + 少量草簇"]
	var notes := ["保持干净，硬轮廓仍在","只调整外露边缘，不加包边纹理","不规则变化更明显，需判断是否破坏画风"]
	for variant in range(3):
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		panel.add_child(StudyUI.label(names[variant],22))
		panel.add_child(StudyUI.label(notes[variant],14))
		var state := IslandModel.new()
		state.cells.clear()
		state.lookup.clear()
		for i in range(2):
			var cell := {"c":i,"r":-i,"h":0,"base":"assets/world/forest/base/grass_1.png" if i == 0 else "assets/world/forest/base/rock_1.png","layer":"land","feat":null}
			state.cells.append(cell)
			state.lookup[IslandModel.key(cell)] = cell
		state.pivot = Vector2(0.5,0)
		state.player = Vector2i.ZERO
		state.preview_all = true
		state.zoom = 2.05
		add_view(panel,state,variant,0.85,true)
		var home := HomeState.new()
		home.world.zoom = 0.88
		add_view(panel,home.world,variant,1.15,false)
func add_view(panel: Control, state: IslandModel, variant: int, ratio: float, hide_hero: bool) -> void:
	var view = load("res://scripts/world/rim_study_view.gd").new()
	view.variant = variant
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_stretch_ratio = ratio
	panel.add_child(view)
	view.setup(state,IslandAssets.new())
	view.hero.visible = not hide_hero
	view.world.get_child(0).environment.background_color = Color("172c2d")
	views.append(view)
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_Q,KEY_E]:
			for view in views: view.model.heading = posmod(view.model.heading+(1 if event.keycode == KEY_E else -1),8)
