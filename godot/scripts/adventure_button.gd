class_name AdventureButton
extends Button
func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = custom_minimum_size.max(Vector2(100,40))
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for key in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:
		add_theme_color_override(key,Color.TRANSPARENT)
func _draw() -> void:
	if StyleLibrary.active:
		var rect:=Rect2(Vector2.ONE,size-Vector2.ONE*2)
		var fill:=Color("111820") if disabled else Color("30363b") if is_hovered() else Color("1b242c")
		if button_pressed:fill=Color("10151b")
		draw_rect(rect,fill)
		draw_rect(rect,Color("a18c69") if is_hovered() or has_focus() else Color("514f4a"),false,1)
		draw_line(Vector2(9,size.y-5),Vector2(size.x-9,size.y-5),Color("554942"),1)
		draw_string(get_theme_default_font(),Vector2(7,size.y/2+5),text,HORIZONTAL_ALIGNMENT_CENTER,size.x-14,14,Color("66727a") if disabled else Color("d4cbbb"))
		return
	var tint := Color("202c25") if disabled else Color("315548") if is_hovered() else Color("203d32")
	var box := StyleBoxFlat.new()
	box.bg_color = tint
	box.border_color = Color("8d7548") if not disabled else Color("4e5143")
	box.set_corner_radius_all(6)
	box.set_border_width_all(1)
	draw_style_box(box,Rect2(Vector2.ZERO,size))
	var edge := minf(27,size.x*.18)
	var opacity := .3 if disabled else .72
	draw_texture_rect(AdventureSkin.part("endcap"),Rect2(Vector2.ZERO,Vector2(edge,size.y)),false,Color(1,1,1,opacity))
	draw_texture_rect(AdventureSkin.part("endcap",true),Rect2(Vector2(size.x-edge,0),Vector2(edge,size.y)),false,Color(1,1,1,opacity))
	if has_focus(): draw_rect(Rect2(Vector2.ONE*3,size-Vector2.ONE*6),Color("ddc58b"),false,1)
	var font_size := 15 if size.x > 130 else 14
	draw_string(get_theme_default_font(),Vector2(edge,size.y/2+font_size*.36),text,HORIZONTAL_ALIGNMENT_CENTER,size.x-edge*2,font_size,Color("8a9585") if disabled else Color("f0dfb5"))
