class_name StudyUI
extends RefCounted
static func theme() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	t.default_font = font
	t.default_font_size = 16
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("24332d") if state == "hover" else Color("17221d")
		box.border_color = Color("a38b53") if state == "focus" else Color("46503b")
		box.set_border_width_all(1)
		box.set_corner_radius_all(6)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 9
		box.content_margin_bottom = 9
		t.set_stylebox(state,"Button",box)
	t.set_color("font_color","Label",Color("d8d6bd"))
	t.set_color("font_color","Button",Color("d8d6bd"))
	return t
static func label(value: String, points := 16) -> Label:
	var result := Label.new()
	result.text = value
	result.add_theme_font_size_override("font_size",points)
	return result
static func button(value: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = value
	result.pressed.connect(callback)
	return result
static func column(parent: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,20)
	parent.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	margin.add_child(box)
	return box
