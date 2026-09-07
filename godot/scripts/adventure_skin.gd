class_name AdventureSkin
extends RefCounted
static var textures := {}
static func part(key: String, flip_x := false, flip_y := false) -> Texture2D:
	var cache_key := "%s/%s/%s" % [key,flip_x,flip_y]
	if not textures.has(cache_key):
		var texture: Texture2D = load("res://assets/ui/adventure/%s.png" % key)
		if flip_x or flip_y:
			var image := texture.get_image()
			if flip_x: image.flip_x()
			if flip_y: image.flip_y()
			texture = ImageTexture.create_from_image(image)
		textures[cache_key] = texture
	return textures[cache_key]
static func corners(canvas: CanvasItem, rect: Rect2, edge := 24.0, tint := Color.WHITE) -> void:
	for i in range(4):
		var right := i%2 == 1
		var bottom := i >= 2
		var at := rect.position+Vector2(rect.size.x-edge if right else 0,rect.size.y-edge if bottom else 0)
		canvas.draw_texture_rect(part("corner",right,bottom),Rect2(at,Vector2.ONE*edge),false,tint)
static func frame(canvas: CanvasItem, rect: Rect2, fill := Color("101e1b"), edge := 24.0) -> void:
	if StyleLibrary.active:
		canvas.draw_rect(rect,Color(.035,.046,.06,.96))
		canvas.draw_rect(rect.grow(-1),Color("655c50"),false,1)
		canvas.draw_rect(rect.grow(-5),Color(.28,.33,.36,.45),false,1)
		for x in [rect.position.x+12,rect.end.x-12]:
			var y:=rect.position.y+rect.size.y*.5
			canvas.draw_polyline(PackedVector2Array([Vector2(x,y-6),Vector2(x+3,y),Vector2(x,y+6),Vector2(x-3,y),Vector2(x,y-6)]),Color("8b7b60"),1,true)
		return
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color("665438")
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	canvas.draw_style_box(box,rect)
	canvas.draw_rect(rect.grow(-4),Color(.58,.47,.29,.2),false,1)
	corners(canvas,rect,edge,Color(1,1,1,.8))
static func button(label_value: String, action: Callable) -> Button:
	var result := AdventureButton.new()
	result.text = label_value
	result.pressed.connect(action)
	return result
