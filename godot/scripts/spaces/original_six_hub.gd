extends Control
## Recovery entry only. Layout, camera, art and combat remain on the saved baseline.
const KEYS = ["forest", "crystal", "swamp", "sewer", "whale", "palace"]
const TITLES = ["幽暗森林", "水晶矿洞", "菌菇沼泽", "城市下水道", "巨鲸体内", "地下宫殿"]

func _ready() -> void:
	StyleLibrary.active = true
	if not get_tree().has_meta("original_six_3d"):
		get_tree().set_meta("original_six_3d", not "--original-six-2d" in OS.get_cmdline_user_args())
	var native:bool = get_tree().get_meta("original_six_3d")
	DisplayServer.window_set_title("原始六套 · " + ("3D" if native else "2D"))
	var background := ColorRect.new()
	background.color = Color("10191b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	margin.add_child(column)
	column.add_child(StudyUI.label("原始六套 · " + ("3D 场景" if native else "2D 传统场景"), 30))
	column.add_child(StudyUI.label("行进、岔路、事件与战斗 · 固定种子可对照两个版本", 18))
	column.add_child(AdventureSkin.button("切换到 " + ("2D 传统版" if native else "3D 版"), func():
		get_tree().set_meta("original_six_3d", not native)
		get_tree().reload_current_scene()))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	column.add_child(grid)
	for index in KEYS.size():
		var key:String = KEYS[index]
		var button := AdventureSkin.button(TITLES[index], func():open_theme(key, native))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
	var topology := OptionButton.new()
	for label in ["随机两岔 / 三岔", "两岔", "三岔"]:topology.add_item(label)
	var count:int = get_tree().get_meta("tour_exits", 0)
	topology.select(0 if count == 0 else count - 1)
	topology.item_selected.connect(func(index):
		if index == 0:get_tree().remove_meta("tour_exits")
		else:get_tree().set_meta("tour_exits", index + 1))
	column.add_child(topology)
	var row := HBoxContainer.new()
	column.add_child(row)
	row.add_child(StudyUI.label("布局种子", 18))
	var seed_box := SpinBox.new()
	seed_box.min_value = 1; seed_box.max_value = 999999
	seed_box.value = preload("res://scripts/spaces/biome_catalog.gd").seed_value
	seed_box.value_changed.connect(func(value):preload("res://scripts/spaces/biome_catalog.gd").seed_value = int(value))
	row.add_child(seed_box)

func open_theme(key:String, native:bool) -> void:
	get_tree().set_meta("native_route_view", native)
	get_tree().set_meta("tour_biome", key)
	get_tree().set_meta("tour_event_placement", "after")
	get_tree().change_scene_to_file("res://scenes/original_six_route.tscn")
