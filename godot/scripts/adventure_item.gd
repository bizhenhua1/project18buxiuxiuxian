class_name AdventureItem
extends Button
var art: Texture2D
var subtitle := ""
var card_id := ""
func _get_drag_data(_position: Vector2) -> Variant:
	if card_id.is_empty(): return null
	var preview := StudyUI.label(text,18)
	set_drag_preview(preview)
	return {"card_id":card_id}
func _ready() -> void:
	custom_minimum_size = Vector2(208,86)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]: add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]: add_theme_color_override(state,Color.TRANSPARENT)
func _draw() -> void:
	AdventureSkin.frame(self,Rect2(Vector2.ZERO,size),Color("254235") if is_hovered() else Color("142820"),15)
	if art:
		var dimensions := art.get_size()*minf(52.0/art.get_width(),60.0/art.get_height())
		draw_texture_rect(art,Rect2(Vector2(38,40)-dimensions/2,dimensions),false)
	else: draw_texture_rect(AdventureSkin.part("seal"),Rect2(19,17,38,46),false)
	var font := get_theme_default_font()
	draw_string(font,Vector2(76,35),text,HORIZONTAL_ALIGNMENT_LEFT,size.x-84,16,Color("ead7a3"))
	draw_string(font,Vector2(76,59),subtitle,HORIZONTAL_ALIGNMENT_LEFT,size.x-84,12,Color("9da88e"))
	if has_focus(): draw_rect(Rect2(Vector2.ONE*3,size-Vector2.ONE*6),Color("d5bc80"),false)
