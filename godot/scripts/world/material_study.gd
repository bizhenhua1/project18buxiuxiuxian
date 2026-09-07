extends Control
var views: Array = []
var close_views: Array = []
var material_index := 0
const BASES := ["grass_1","leaf_1","rock_1","water_1"]
const ATLASES := ["","assets/material-studies/01-mineral.png","assets/material-studies/02-moss.png","assets/material-studies/03-ink.png"]
func _ready() -> void:
	theme = StudyUI.theme()
	var column := StudyUI.column(self)
	column.add_child(StudyUI.label("A 岛体 · 地表与立面材质对照",28))
	column.add_child(StudyUI.label("上：所选材质近景　下：同一主岛实景　Q / E 同步旋转　所有方案保留 A 的方块形状与底部渐隐",17))
	var controls := HBoxContainer.new()
	column.add_child(controls)
	for i in range(4):
		var index := i
		controls.add_child(StudyUI.button(["草地","落叶地","石地","水边"][i],func():select_material(index)))
	controls.add_child(StudyUI.button("返回目录",func():get_tree().change_scene_to_file("res://scenes/study_hub.tscn")))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var names := ["原版 A","01 · 暖土矿彩","02 · 青苔岩层","03 · 简笔矿色"]
	var notes := ["原有地表与侧面","低饱和暖色，细碎矿物层次","湿润苔地，青灰裂隙","大色块、清晰线描，细节更少"]
	for variant in range(4):
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 1.0
		row.add_child(panel)
		panel.add_child(StudyUI.label(names[variant],22))
		panel.add_child(StudyUI.label(notes[variant],14))
		var state := IslandModel.new()
		state.cells.clear()
		state.lookup.clear()
		var cell := {"c":0,"r":0,"h":0,"base":"assets/world/forest/base/grass_1.png","layer":"land","feat":null}
		state.cells.append(cell)
		state.lookup[Vector2i.ZERO] = cell
		state.pivot = Vector2.ZERO
		state.player = Vector2i.ZERO
		state.preview_all = true
		state.zoom = 2.3
		close_views.append(add_view(panel,state,variant,0.9,true))
		var home := HomeState.new()
		home.world.zoom = 0.68
		add_view(panel,home.world,variant,1.1,false)
func add_view(panel: Control, state: IslandModel, variant: int, ratio: float, hide_hero: bool) -> IslandView3D:
	var view = load("res://scripts/world/material_study_view.gd").new()
	view.atlas_path = ATLASES[variant]
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.size_flags_stretch_ratio = ratio
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(view)
	view.setup(state,IslandAssets.new())
	view.hero.visible = not hide_hero
	view.world.get_child(0).environment.background_color = Color("172c2d")
	views.append(view)
	return view
func select_material(index: int) -> void:
	material_index = index
	for view in close_views:
		view.model.cells[0].base = "assets/world/forest/base/%s.png" % BASES[index]
		view.rebuild()
		view.hero.visible = false
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_Q,KEY_E]:
			for view in views: view.model.heading = posmod(view.model.heading+(1 if event.keycode == KEY_E else -1),8)
