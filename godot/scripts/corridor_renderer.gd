class_name CorridorRenderer
extends Node2D

var art: ForestArt
var world: ForestWorld
var study_mode := 0
var view_size := Vector2(760, 620)
var camera_world := Vector2.ZERO
var heading := 0.0
var elapsed := 0.0
var movement := 0.0
var selected := 0
var show_landmarks := true
var bob_enabled := true
var last_draw_ms := 0.0
var visible_count := 0
var font: Font
var landmark_markers: Array[Dictionary] = []

var minimum_focal := 0.0
var horizon_ratio := .48
func focal() -> float:
	# Keep a comfortable field of view in both the comparison and full-width views.
	return maxf(minimum_focal,minf(view_size.y * 0.86, view_size.x * 0.72))

func horizon_y() -> float:
	return view_size.y * horizon_ratio + (sin(elapsed * 8.2) * 3.0 * movement if bob_enabled else 0.0)

func landmark_position(branch: int) -> Vector2:
	if study_mode == 0:
		return Vector2(branch * 2600.0, 18000.0)
	return ForestRoute.point_at(18000.0, branch)

func landmark_bearing(branch: int) -> float:
	var p := ForestRoute.to_camera(landmark_position(branch), camera_world, heading)
	return rad_to_deg(atan2(p.x, p.y))

func _draw() -> void:
	if not art or not world:
		return
	var t0 := Time.get_ticks_usec()
	var f := focal()
	var hy := horizon_y()
	var cx := view_size.x * 0.5 + (sin(elapsed * 4.1) * 2.4 * movement if bob_enabled else 0.0)
	landmark_markers.clear()
	_draw_distance(cx, hy, f)
	var atmosphere := world.atmosphere
	var profile := atmosphere.profile
	draw_texture_rect(atmosphere.horizon_texture, Rect2(0, hy - view_size.y * profile.horizon_up, view_size.x, view_size.y * (profile.horizon_up + profile.horizon_down)), false)
	var draw_list: Array[Dictionary]
	if world.projection_camera == camera_world and world.projection_heading == heading and world.projection_size == view_size and world.projection_center == Vector2(cx, hy):
		draw_list = world.projection_cache
	else:
		draw_list = _project_forest(cx, hy, f)
		world.projection_cache = draw_list
		world.projection_size = view_size
		world.projection_camera = camera_world
		world.projection_heading = heading
		world.projection_center = Vector2(cx, hy)
	visible_count = draw_list.size()
	for item in draw_list:
		var s: Dictionary = item.sprite
		var tint: Color = item.tint
		var rect: Rect2 = item.rect
		if s.flip:
			draw_set_transform(Vector2(rect.position.x + rect.size.x, rect.position.y), 0.0, Vector2(-1, 1))
			draw_texture_rect(s.texture, Rect2(Vector2.ZERO, rect.size), false, tint)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect(s.texture, rect, false, tint)
	draw_rect(Rect2(Vector2.ZERO, view_size), Color(0.35, 0.24, 0.08, 0.035))
	# The actual landmark is occluded by trees; the optional reading aid is UI, never half-hidden text.
	for marker in landmark_markers:
		var width := font.get_string_size(marker.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var x := clampf(marker.x, width * 0.5 + 15, view_size.x - width * 0.5 - 15)
		var y: float = marker.y
		draw_style_box(_label_style(), Rect2(x - width * 0.5 - 12, y - 21, width + 24, 32))
		draw_string(font, Vector2(x - width * 0.5, y), marker.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ecd8a5"))
		draw_line(Vector2(x, y + 14), Vector2(marker.x, y + 28), Color(0.83, 0.74, 0.51, 0.6), 1.0, true)
	last_draw_ms = (Time.get_ticks_usec() - t0) / 1000.0

func _project_forest(cx: float, hy: float, f: float) -> Array[Dictionary]:
	var draw_list: Array[Dictionary] = []
	var co := cos(heading)
	var si := sin(heading)
	for sprite in world.sprites:
		var delta: Vector2 = sprite.position - camera_world
		var z: float = delta.x * si + delta.y * co
		if z <= 10.0 or z >= 1700.0:
			continue
		var x: float = delta.x * co - delta.y * si
		var scale := f / z
		var w: float = sprite.w * scale
		var h: float = sprite.h * scale
		var sx := cx + x * scale
		var sy := hy + 58.0 * scale
		if sx + w * 0.5 < -20 or sx - w * 0.5 > view_size.x + 20 or sy - h > view_size.y:
			continue
		var dark := smoothstep(220.0, 1750.0, z) * 0.94
		var alpha := 1.0 - smoothstep(1400.0, 1700.0, z)
		var tint := Color(1.0 - dark, 1.0 - dark * 0.96, 1.0 - dark, alpha)
		draw_list.append({"sprite": sprite, "depth": z, "rect": Rect2(sx - w * 0.5, sy - h, w, h), "tint": tint})
	draw_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.depth > b.depth if not is_equal_approx(a.depth, b.depth) else a.sprite.id < b.sprite.id)
	return draw_list

func _draw_distance(cx: float, hy: float, f: float) -> void:
	# Sun is a direction at infinity: yaw affects it, camera translation does not.
	var sun := sun_projection(cx, hy, f)
	if sun.visible and not StyleLibrary.active:
		draw_texture_rect(art.textures["sun"], sun.rect, false, Color(1, 0.94, 0.74, 0.88))
	if not StyleLibrary.active: _draw_ridge(cx, hy, f)
	# Clouds and destination peaks share one depth-sorted list, including near clouds.
	var cloud_list: Array[Dictionary] = []
	for state in world.atmosphere.visible_clouds(camera_world, elapsed):
		var relative := ForestRoute.to_camera(state.position, camera_world, heading)
		if relative.y <= 100:
			continue
		var cloud: Texture2D = art.clouds[state.texture_index % art.clouds.size()]
		var scale := f / relative.y
		var w: float = state.width * scale
		var h := w * cloud.get_height() / float(cloud.get_width())
		var sx := cx + relative.x * scale
		var sy: float = hy - state.altitude * scale
		if sx + w * 0.5 < 0 or sx - w * 0.5 > view_size.x or sy + h * 0.5 < 0:
			continue
		cloud_list.append({"texture": cloud, "depth": relative.y, "rect": Rect2(sx - w * 0.5, sy - h * 0.5, w, h), "tint": Color(0.83, 0.87, 0.79, state.opacity)})
	for branch in [-1, 1]:
		var relative := ForestRoute.to_camera(landmark_position(branch), camera_world, heading)
		if relative.y <= 100:
			continue
		var tex: Texture2D = art.textures["island"]
		var scale := f / relative.y
		var w := (700.0 if StyleLibrary.active else 4800.0) * scale
		var h := w * tex.get_height() / float(tex.get_width())
		var x := cx + relative.x * scale
		var foot := hy - (0.0 if StyleLibrary.active else 2800.0) * scale
		cloud_list.append({"texture": tex, "depth": relative.y, "rect": Rect2(x - w * 0.5, foot - h, w, h), "tint": Color(0.77, 0.85, 0.80, 0.76)})
		if show_landmarks and x > 52 and x < view_size.x - 52:
			var title := ("西峰" if branch < 0 else "东峰")
			if study_mode == 0:
				title += " · 方位"
			elif selected == branch:
				title += " · 此行所向"
			else:
				title += " · 可前往"
			var y := maxf(80, foot - h - 15)
			landmark_markers.append({"title": title, "x": x, "y": y})

	cloud_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.depth > b.depth)
	for item in cloud_list:
		draw_texture_rect(item.texture, item.rect, false, item.tint)

func _draw_ridge(cx: float, hy: float, f: float) -> void:
	# Mountains have finite world depth and use the same perspective as destinations.
	# Draw AFTER the sun, with an opaque silhouette so it actually occludes sunlight.
	var ridge: Texture2D = art.textures["ridge-haze"]
	var ridge_width := 420000.0
	var ridge_height := ridge_width * ridge.get_height() / float(ridge.get_width()) * 0.65
	# Subdivide the broad world-space ridge: a single screen-aligned sprite would
	# still slide its individual peaks at the wrong rate during yaw.
	for i in range(96):
		var u0 := i / 96.0
		var u1 := (i + 1) / 96.0
		var left := ForestRoute.to_camera(Vector2((u0 - 0.5) * ridge_width, 90000), camera_world, heading)
		var right := ForestRoute.to_camera(Vector2((u1 - 0.5) * ridge_width, 90000), camera_world, heading)
		if minf(left.y, right.y) <= 100:
			continue
		var lx := cx + left.x * f / left.y
		var rx := cx + right.x * f / right.y
		if rx < 0 or lx > view_size.x:
			continue
		var vertices := PackedVector2Array([
			Vector2(lx, hy - ridge_height * 0.78 * f / left.y),
			Vector2(rx, hy - ridge_height * 0.78 * f / right.y),
			Vector2(rx, hy + ridge_height * 0.22 * f / right.y),
			Vector2(lx, hy + ridge_height * 0.22 * f / left.y)])
		draw_polygon(vertices, PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]), ridge)

# Projected celestial altitude also depends on yaw (not a fixed screen Y).
func sun_projection(cx: float, hy: float, f: float) -> Dictionary:
	var angle := 0.22 - heading
	var depth := cos(angle)
	if depth <= 0.05:
		return {"visible": false, "rect": Rect2()}
	var center := Vector2(cx + tan(angle) * f, hy - tan(0.43) * f / depth)
	var diameter := f * 0.16 / depth
	return {"visible": true, "rect": Rect2(center - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter)}

func _label_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.075, 0.11, 0.095, 0.78)
	box.set_corner_radius_all(4)
	return box
