extends "res://scripts/app.gd"
var preset := "connected"
var scene_note: Label

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--space="): preset = arg.trim_prefix("--space=")
		if arg.begins_with("--capture="):
			capture_mode = true
			capture_dir = arg.trim_prefix("--capture=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
		if arg == "--capture-left": auto_branch = -1
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	theme = _theme()
	art = ForestArt.new()
	load_preset(preset)
	print("SPACE_STUDY_READY preset=%s sprites=%d" % [preset,world.sprites.size()])

func load_preset(value: String) -> void:
	preset = value
	var plan := load("res://spaces/routes/%s.tres" % value) as RoutePlan
	world = SegmentWorld.new(art, plan)
	# Prewarm silhouette caches during loading, never on the first moving frame.
	for sprite in world.sprites:
		sprite.silhouette = world.assets.silhouette(sprite.texture, sprite.region.space.atmosphere.depth_color)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	views.clear()
	panels.clear()
	notes.clear()
	_build_ui()
	reset()

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := _label("仙途 · 山林之间",30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	for item in [["connected","连续路线"],["cave","洞穴"],["cloudsea","云海"]]:
		var key: String = item[0]
		top.add_child(_button(item[1],func(): load_preset(key)))
	top.add_child(_button("森林基线",func(): get_tree().change_scene_to_file("res://scenes/main.tscn")))
	top.add_child(_button("样本目录",func(): get_tree().change_scene_to_file("res://scenes/study_hub.tscn")))
	column.add_child(_label(world.plan.title,17,Color("b9c2b4")))
	var view := SegmentView.new()
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.custom_minimum_size = Vector2(0,350)
	column.add_child(view)
	view.setup(art,world,1,font)
	views.append(view)
	scene_note = _label("",15,Color("adb8aa"))
	column.add_child(scene_note)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 4
	column.add_child(progress)
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	status = _label("",19)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(status)
	left_button = _button("← 走左路",func(): choose(-1))
	right_button = _button("走右路 →",func(): choose(1))
	pause_button = _button("暂停",_toggle_pause)
	bottom.add_child(left_button)
	bottom.add_child(right_button)
	bottom.add_child(pause_button)
	bottom.add_child(_button("重来",reset))
	column.add_child(_label("← / → 选路    空格 暂停    R 重来 · 连续路线：左路进入洞穴，右路走向云海",14,Color("9ca791")))
	debug_label = _label("",13)
	debug_label.visible = show_debug
	column.add_child(debug_label)

func _process(delta: float) -> void:
	# Controller advances first; view synchronization resolves the same-frame region.
	super(delta)

func _update_ui() -> void:
	left_button.disabled = phase not in ["approach","choose"]
	right_button.disabled = left_button.disabled
	status.text = {"approach":"前方有岔路", "choose":"停步辨路", "travel":"继续前行", "arrived":"本段已到达 · 可以重来走另一条路"}[phase]
	if paused: status.text += " · 已暂停"
	pause_button.text = "继续" if paused else "暂停"
	progress.value = distance / ForestRoute.END_AT * 100
	scene_note.text = "当前：%s" % world.camera_region.space.title
	if preset == "connected" and distance < 1900: scene_note.text += " · 洞口与云谷已在各自路段，沿所选道路进入"
	debug_label.text = "路段 %s · 行程 %.0f · 航向 %.1f° · 可见 %d · 绘制 %.2f ms" % [world.camera_region.key,distance,rad_to_deg(heading),views[0].renderer.visible_count,views[0].renderer.last_draw_ms]

func _focus(_mode: int) -> void: pass
func _landmark_bearing(_mode: int, direction: int) -> float:
	return views[0].renderer.landmark_bearing(direction)
