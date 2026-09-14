extends Control

var art: ForestArt
var world: ForestWorld
var views: Array[CorridorView] = []
var panels: Array[VBoxContainer] = []
var branch := 0
var distance := 0.0
var heading := 0.0
var camera := Vector2.ZERO
var elapsed := 0.0
var phase := "approach"
var phase_time := 0.0
var travel_time := 0.0
var moving_envelope := 0.0
var paused := false
var labels := true
var bob := true
var playback_speed := 1.0
var study_focus := 0
var status: Label
var notes: Array[Label] = []
var left_button: Button
var right_button: Button
var pause_button: Button
var progress: ProgressBar
var font: SystemFont
var debug_label: Label
var show_debug := false
var capture_mode := false
var capture_dir := ""
var capture_stage := 0
var auto_branch := 1
var frame_times: Array[float] = []

func _ready() -> void:
	ForestRoute.configure(false)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font.allow_system_fallback = true
	theme = _theme()
	art = ForestArt.new()
	world = ForestWorld.new(art)
	_build_ui()
	_focus(2)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_mode = true
			capture_dir = arg.trim_prefix("--capture=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
		if arg == "--capture-left":
			auto_branch = -1
		if arg.begins_with("--focus="):
			_focus(clampi(int(arg.trim_prefix("--focus=")), 0, 2))
	print("FORK_STUDY_READY sprites=%d engine=%s" % [world.sprites.size(), Engine.get_version_info().string])

func _theme() -> Theme:
	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 17
	t.set_color("font_color", "Label", Color("e8e3d2"))
	for kind in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("243b30") if kind in ["hover", "pressed"] else Color("19251f")
		box.border_color = Color("b5a06b") if kind in ["hover", "focus"] else Color("48513c")
		box.set_border_width_all(1)
		box.set_corner_radius_all(6)
		box.content_margin_left = 19
		box.content_margin_right = 19
		box.content_margin_top = 10
		box.content_margin_bottom = 10
		t.set_stylebox(kind, "Button", box)
	t.set_color("font_color", "Button", Color("e7d8af"))
	t.set_color("font_disabled_color", "Button", Color("68746a"))
	return t

func _label(text: String, size_value: int, color := Color("e8e3d2")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.text = text
	button.pressed.connect(action)
	return button

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	titles.add_child(_label("雾林调查局   /   林间歧路", 14, Color("b4aa81")))
	titles.add_child(_label("岔路之后", 32))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_END
	modes.add_theme_constant_override("separation", 8)
	top.add_child(modes)
	modes.add_child(_button("并排对照", func(): _focus(0)))
	modes.add_child(_button("单看 A", func(): _focus(1)))
	modes.add_child(_button("单看 B", func(): _focus(2)))
	column.add_child(_label("同一片森林，两种远景关系。选一条路，感受它是否真正带你走向新的方向。", 16, Color("abb7aa")))
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	column.add_child(row)
	for i in range(2):
		var panel := VBoxContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_constant_override("separation", 8)
		row.add_child(panel)
		panels.append(panel)
		panel.add_child(_label("A  ·  以远山辨方向" if i == 0 else "B  ·  朝所选目的地前行", 21, Color("decea2")))
		panel.add_child(_label("转向之后，地标仍留在它的世界方位。" if i == 0 else "左路向西峰，右路向东峰。", 14, Color("9aab9c")))
		var view := CorridorView.new()
		view.size_flags_vertical = Control.SIZE_EXPAND_FILL
		view.custom_minimum_size = Vector2(0, 300)
		panel.add_child(view)
		view.setup(art, world, i, font)
		views.append(view)
		var note := _label("", 14, Color("b5bdad"))
		panel.add_child(note)
		notes.append(note)
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 3
	progress.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("24332a")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("b69d61")
	progress.add_theme_stylebox_override("background", bg)
	progress.add_theme_stylebox_override("fill", fill)
	column.add_child(progress)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	column.add_child(bottom)
	var message := VBoxContainer.new()
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(message)
	status = _label("", 20, Color("eadbb3"))
	message.add_child(status)
	message.add_child(_label("两边同步选路   ·   ← / → 选择   ·   空格暂停   ·   R 重来", 14, Color("95a392")))
	left_button = _button("←  走左路", func(): choose(-1))
	right_button = _button("走右路  →", func(): choose(1))
	bottom.add_child(left_button)
	bottom.add_child(right_button)
	pause_button = _button("暂停", _toggle_pause)
	bottom.add_child(pause_button)
	bottom.add_child(_button("重新比较", reset))
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 18)
	column.add_child(options)
	var landmark_check := CheckButton.new()
	landmark_check.text = "地标提示"
	landmark_check.button_pressed = true
	landmark_check.toggled.connect(func(value: bool): labels = value)
	options.add_child(landmark_check)
	var bob_check := CheckButton.new()
	bob_check.text = "行走起伏"
	bob_check.button_pressed = true
	bob_check.toggled.connect(func(value: bool): bob = value)
	options.add_child(bob_check)
	options.add_child(_label("回放速度", 14, Color("95a392")))
	var speed := OptionButton.new()
	for text in ["正常", "慢放 ½", "快速 2×"]:
		speed.add_item(text)
	speed.item_selected.connect(func(index: int): playback_speed = [1.0, 0.5, 2.0][index])
	options.add_child(speed)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_child(spacer)
	options.add_child(_label("先看转向，再看它是否留下了方向。", 14, Color("a89f7c")))
	debug_label = _label("", 12, Color("91a68f"))
	debug_label.visible = false
	column.add_child(debug_label)

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05) * playback_speed
	if not paused:
		elapsed += dt
		phase_time += dt
		if phase == "approach":
			var u := clampf(phase_time / ForestRoute.APPROACH_SECONDS, 0, 1)
			distance = ForestRoute.PAUSE_AT * smoothstep(0.0, 1.0, u)
			moving_envelope = sin(u * PI)
			if u >= 1.0:
				phase = "choose"
				phase_time = 0
		elif phase == "travel":
			travel_time += dt
			moving_envelope = move_toward(moving_envelope, 1.0, dt * 2.0)
			distance += 260.0 * moving_envelope * dt
			if distance >= ForestRoute.END_AT:
				distance = ForestRoute.END_AT
				phase = "arrived"
				phase_time = 0
		else:
			moving_envelope = move_toward(moving_envelope, 0.0, dt * 2.5)
		var pose := ForestRoute.pose(distance, branch)
		camera = pose.position
		# Look toward a point along the route; exponential response is frame-rate independent.
		var ahead := ForestRoute.point_at(distance + 75.0, branch)
		var direction := ahead - camera
		var target_heading := atan2(direction.x, direction.y)
		heading = lerp_angle(heading, target_heading, 1.0 - exp(-dt * 4.5))
	for view in views:
		view.sync(camera, heading, elapsed, moving_envelope, branch, labels, bob, distance)
	_update_ui()
	if frame_times.size() < 6000:
		frame_times.append(delta * 1000)
	if capture_mode:
		_capture_step()

func _update_ui() -> void:
	left_button.disabled = phase not in ["approach", "choose"]
	right_button.disabled = left_button.disabled
	var direction := "左" if branch < 0 else "右"
	match phase:
		"approach": status.text = "前方分岔 · 已可选择"
		"choose": status.text = "停步辨路 · 你想往哪里走？"
		"travel": status.text = ("转入%s路" % direction) if distance < ForestRoute.JUNCTION + ForestRoute.TURN_LENGTH else "沿%s路继续前行" % direction
		"arrived": status.text = "新方向已展开 · 可以重来比较另一条路"
	if paused:
		status.text += " · 已暂停"
	pause_button.text = "继续" if paused else "暂停"
	progress.value = distance / ForestRoute.END_AT * 100
	for i in range(2):
		var r := views[i].renderer
		if branch == 0:
			notes[i].text = "西峰与东峰已在远处。两边共享相同道路与植被。"
		else:
			var bearing := _landmark_bearing(i, branch)
			var side := "左" if bearing < -2 else "右" if bearing > 2 else "前"
			notes[i].text = ("所选一侧的远峰仍在%s方，作为方位参照。" % side) if i == 0 else ("此行目标在%s方，路线正向它延伸。" % side)
	debug_label.text = "航向 %.1f°  ·  行程 %.0f  ·  绘制 %.2f / %.2f ms  ·  可见 %d / %d  ·  F3 隐藏" % [rad_to_deg(heading), distance, views[0].renderer.last_draw_ms, views[1].renderer.last_draw_ms, views[0].renderer.visible_count, views[1].renderer.visible_count]

func choose(value: int) -> void:
	if phase not in ["approach", "choose"]:
		return
	branch = value
	phase = "travel"
	phase_time = 0
	travel_time = 0

func _landmark_bearing(mode: int, direction: int) -> float:
	# Hidden views do not redraw. Reports/notes must use shared live state, not their last render snapshot.
	var position_value := views[mode].renderer.landmark_position(direction)
	var relative := ForestRoute.to_camera(position_value, camera, heading)
	return rad_to_deg(atan2(relative.x, relative.y))

func reset() -> void:
	branch = 0
	distance = 0
	heading = 0
	camera = Vector2.ZERO
	elapsed = 0
	phase_time = 0
	travel_time = 0
	moving_envelope = 0
	phase = "approach"
	paused = false

func _focus(mode: int) -> void:
	study_focus = mode
	panels[0].visible = mode != 2
	panels[1].visible = mode != 1

func _toggle_pause() -> void:
	paused = not paused

func _input(event: InputEvent) -> void:
	# Route choice takes priority over implicit UI focus navigation at a fork.
	if event is InputEventKey and event.pressed and not event.echo and phase in ["approach","choose"]:
		if event.keycode in [KEY_LEFT,KEY_RIGHT]:
			choose(-1 if event.keycode == KEY_LEFT else 1)
			get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE: get_tree().change_scene_to_file("res://scenes/study_hub.tscn")
		KEY_LEFT: choose(-1)
		KEY_RIGHT: choose(1)
		KEY_R: reset()
		KEY_SPACE: _toggle_pause()
		KEY_1: _focus(1)
		KEY_2: _focus(2)
		KEY_3: _focus(0)
		KEY_F3:
			show_debug = not show_debug
			debug_label.visible = show_debug

func _capture_step() -> void:
	if capture_stage == 0 and phase == "choose":
		capture_stage = 1
		_capture("01-choosing")
	elif capture_stage == 1 and phase_time > 0.5:
		choose(auto_branch)
		capture_stage = 2
	elif capture_stage == 2 and distance > 1000:
		capture_stage = 3
		_capture("02-turning")
	elif capture_stage == 3 and distance > 1800:
		capture_stage = 4
		_capture("03-new-direction")
	elif capture_stage == 4 and phase == "arrived":
		capture_stage = 5
		_capture("04-persistent-direction")
		_save_report()
		await get_tree().create_timer(0.3).timeout
		get_tree().quit()

func _capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(capture_dir.path_join(name_value + ".png"))
	print("CAPTURE %s error=%d heading=%.2f distance=%.1f" % [name_value, err, rad_to_deg(heading), distance])

func _save_report() -> void:
	frame_times.sort()
	var report := {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "seed": world.seed_value, "branch": branch, "focus": study_focus, "heading_deg": rad_to_deg(heading), "distance": distance, "landmark_a_deg": _landmark_bearing(0, branch), "landmark_b_deg": _landmark_bearing(1, branch), "frames": frame_times.size(), "frame_p50_ms": frame_times[int(frame_times.size() * 0.5)], "frame_p95_ms": frame_times[int(frame_times.size() * 0.95)], "frame_p99_ms": frame_times[int(frame_times.size() * 0.99)]}
	var file := FileAccess.open(capture_dir.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))

