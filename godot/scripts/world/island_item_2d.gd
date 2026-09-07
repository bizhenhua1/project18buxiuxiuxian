class_name IslandItem2D
extends Node2D
var view: Control
var cell: Dictionary
var kind := "slab"
func _ready() -> void:
	var tint := ShaderMaterial.new()
	tint.shader = preload("res://shaders/island_tint.gdshader")
	material = tint
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func refresh() -> void:
	var style: Dictionary = view.model.style(IslandModel.key(cell)) if kind != "hero" else {"bright":1.0,"sat":1.0}
	material.set_shader_parameter("brightness",style.bright)
	material.set_shader_parameter("saturation",style.sat)
	queue_redraw()
func _draw() -> void:
	var projection: IslandProjection = view.projection
	var assets: IslandAssets = view.assets
	var zoom: float = view.model.zoom
	if kind == "hero":
		var p := projection.avatar()
		var tex := assets.texture(IslandAssets.HERO)
		var height := 96*zoom
		var width := height*tex.get_width()/tex.get_height()
		draw_set_transform(p+Vector2(0,3*zoom),0,Vector2(1,0.4))
		draw_circle(Vector2.ZERO,14*zoom,Color(0.04,0.06,0.04,0.3))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(tex,Rect2(p+Vector2(-width/2,-height+8*zoom),Vector2(width,height)),false)
		return
	var style := view.model.style(IslandModel.key(cell)) as Dictionary
	if kind == "feature":
		if not style.known or cell.feat == null: return
		var tex := assets.texture(cell.feat.src)
		var width: float = 112*zoom*cell.feat.w
		var height := width*tex.get_height()/tex.get_width()
		var p := projection.position(cell.c,cell.r,cell.h)
		draw_texture_rect(tex,Rect2(p+Vector2(-width/2,-height+23.52*zoom),Vector2(width,height)),false)
		return
	var shape := projection.slab(cell)
	var path: String = cell.base if style.known else IslandAssets.SHROUD
	var tones := IslandAssets.side_colors(path)
	var faces := [0,1,2,3]
	faces.sort_custom(func(a,b):return shape.corners_depth[a]+shape.corners_depth[(a+1)%4] < shape.corners_depth[b]+shape.corners_depth[(b+1)%4])
	for i in faces:
		var n: int = (i+1)%4
		draw_colored_polygon(PackedVector2Array([shape.top[i],shape.top[n],shape.bottom[n],shape.bottom[i]]),tones[i%2])
	draw_colored_polygon(shape.top,Color("c5c8ce") if not style.known else tones[0])
	draw_polygon(shape.top,PackedColorArray([Color.WHITE]),assets.diamond_uv(path),assets.texture(path))
	var outline: PackedVector2Array = shape.top.duplicate()
	outline.append(outline[0])
	draw_polyline(outline,Color(0.1,0.1,0.08,0.4),1.25,true)
