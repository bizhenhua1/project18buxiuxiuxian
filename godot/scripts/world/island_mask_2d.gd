extends Node2D
var view: IslandView2D
var occlusion := false
func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/island_mask.gdshader")
	material = mat
func slab(cell: Dictionary) -> void:
	var shape := view.projection.slab(cell)
	draw_colored_polygon(shape.top,Color.WHITE)
	for i in range(4):
		var n := (i+1)%4
		draw_colored_polygon(PackedVector2Array([shape.top[i],shape.top[n],shape.bottom[n],shape.bottom[i]]),Color.WHITE)
func feature(cell: Dictionary) -> void:
	if cell.feat == null or not view.model.style(IslandModel.key(cell)).known: return
	var tex := view.assets.texture(cell.feat.src)
	var width: float = 112*view.model.zoom*cell.feat.w
	var height := width*tex.get_height()/tex.get_width()
	var p := view.projection.position(cell.c,cell.r,cell.h)
	draw_texture_rect(tex,Rect2(p+Vector2(-width/2,-height+23.52*view.model.zoom),Vector2(width,height)),false)
func _draw() -> void:
	if not view.model.lookup.has(view.model.hover): return
	var cell: Dictionary = view.model.lookup[view.model.hover]
	if not occlusion:
		slab(cell)
		feature(cell)
		return
	var depth: float = view.projection.slab(cell).depth
	for other in view.model.cells:
		if view.projection.slab(other).depth > depth+.001:
			slab(other)
			feature(other)
	if view.projection.avatar_depth() > depth+.001:
		var tex := view.assets.texture(IslandAssets.HERO)
		var height := 96*view.model.zoom
		var width := height*tex.get_width()/tex.get_height()
		var p := view.projection.avatar()
		draw_texture_rect(tex,Rect2(p+Vector2(-width/2,-height+8*view.model.zoom),Vector2(width,height)),false)
