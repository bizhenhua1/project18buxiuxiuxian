class_name IslandView2D
extends Control
var model: IslandModel
var assets: IslandAssets
var projection: IslandProjection
var slabs: Array[IslandItem2D] = []
var props: Array[IslandItem2D] = []
var hero: IslandItem2D
var overlay: Node2D
var mask_views: Array[SubViewport] = []
var xray: ColorRect
func setup(state: IslandModel, library: IslandAssets) -> void:
	model = state
	assets = library
	projection = IslandProjection.new(model)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	model.map_changed.connect(rebuild)
	rebuild()
	mouse_exited.connect(func(): model.hover = Vector2i(-999,-999))
func rebuild() -> void:
	for child in get_children(): child.queue_free()
	slabs.clear()
	props.clear()
	mask_views.clear()
	for cell in model.cells:
		var tile := IslandItem2D.new()
		tile.view = self
		tile.cell = cell
		add_child(tile)
		slabs.append(tile)
		if cell.feat != null:
			var prop := IslandItem2D.new()
			prop.view = self
			prop.cell = cell
			prop.kind = "feature"
			add_child(prop)
			props.append(prop)
	hero = IslandItem2D.new()
	hero.view = self
	hero.kind = "hero"
	add_child(hero)
	overlay = Node2D.new()
	overlay.z_index = 3000
	overlay.draw.connect(draw_hover)
	add_child(overlay)
	for is_occlusion in [false,true]:
		var viewport := SubViewport.new()
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(viewport)
		var mask = preload("res://scripts/world/island_mask_2d.gd").new()
		mask.view = self
		mask.occlusion = is_occlusion
		viewport.add_child(mask)
		mask_views.append(viewport)
	xray = ColorRect.new()
	xray.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	xray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xray.z_index = 2999
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/island_xray_2d.gdshader")
	mat.set_shader_parameter("target_mask",mask_views[0].get_texture())
	mat.set_shader_parameter("occlusion_mask",mask_views[1].get_texture())
	xray.material = mat
	add_child(xray)
func _process(_dt: float) -> void:
	if not model: return
	projection.size = size
	for viewport in mask_views:
		viewport.size = Vector2i(maxi(1,int(size.x)),maxi(1,int(size.y)))
		viewport.get_child(0).queue_redraw()
	xray.material.set_shader_parameter("pixel",Vector2.ONE/size.max(Vector2.ONE))
	xray.material.set_shader_parameter("tint",Color("c5e9a5") if model.can_visit(model.hover) else Color("d59075"))
	slabs.sort_custom(func(a,b):return projection.slab(a.cell).depth < projection.slab(b.cell).depth)
	for i in range(slabs.size()):
		slabs[i].z_index = i
		slabs[i].refresh()
	var sorted: Array = props.duplicate()
	sorted.append(hero)
	sorted.sort_custom(func(a,b):return (projection.avatar_depth() if a == hero else projection.slab(a.cell).depth) < (projection.avatar_depth() if b == hero else projection.slab(b.cell).depth))
	for i in range(sorted.size()):
		sorted[i].z_index = 1000+i
		sorted[i].refresh()
	overlay.queue_redraw()
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("2a241c"))
func draw_hover() -> void:
	if not model.lookup.has(model.hover): return
	var top: PackedVector2Array = projection.slab(model.lookup[model.hover]).top.duplicate()
	top.append(top[0])
	var tint := Color("c5e9a5") if model.can_visit(model.hover) else Color("d59075")
	draw_hover_lines(top,tint)
func draw_hover_lines(points: PackedVector2Array, color: Color) -> void:
	overlay.draw_polyline(points,color,2,true)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion: model.hover = projection.pick(event.position)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: model.go_to(projection.pick(event.position,true))
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: model.zoom_goal = minf(2.4,model.zoom_goal*1.12)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: model.zoom_goal = maxf(0.42,model.zoom_goal/1.12)
