class_name IslandProjection
extends RefCounted
var model: IslandModel
var size := Vector2(760,620)
func _init(state: IslandModel) -> void: model = state
func project(xz: Vector2, height: float) -> Vector2:
	return Vector2(size.x*0.5,size.y*0.36+22*model.zoom)+Vector2(xz.x*112,xz.y*56-height*22)*model.zoom
func position(c: float,r: float,height: float) -> Vector2:
	return project((IslandModel.wxz(c,r)-model.pivot).rotated(model.angles().x),height)
func slab(cell: Dictionary) -> Dictionary:
	var angles := model.angles()
	var center := (IslandModel.wxz(cell.c,cell.r)-model.pivot).rotated(angles.x)
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var depths := PackedFloat32Array()
	for offset in [Vector2(0.5,0),Vector2(0,0.5),Vector2(-0.5,0),Vector2(0,-0.5)]:
		var p: Vector2 = center+offset.rotated(angles.y)
		top.append(project(p,cell.h))
		bottom.append(project(p,cell.h-0.88))
		depths.append(p.y)
	return {"top":top,"bottom":bottom,"depth":center.y+cell.h*0.02,"corners_depth":depths}
func avatar() -> Vector2:
	var pose := model.avatar()
	var p := position(pose.x,pose.z,pose.y)
	if model.walking: p.y -= sin(IslandModel.ease_walk(clampf(model.walk_t,0,1))*PI)*4*model.zoom
	return p
func avatar_depth() -> float:
	var pose := model.avatar()
	return (IslandModel.wxz(pose.x,pose.z)-model.pivot).rotated(model.angles().x).y+pose.y*0.02
func pick(point: Vector2, visit_only := false) -> Vector2i:
	var best := -INF
	var result := Vector2i(-999,-999)
	for cell in model.cells:
		var position_value := IslandModel.key(cell)
		if visit_only and not model.can_visit(position_value): continue
		var geometry := slab(cell)
		if Geometry2D.is_point_in_polygon(point,geometry.top) and geometry.depth >= best:
			best = geometry.depth
			result = position_value
	return result
