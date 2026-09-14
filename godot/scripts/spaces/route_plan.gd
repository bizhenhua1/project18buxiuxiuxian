class_name RoutePlan
extends Resource
@export var layout_seed := 1842
@export var title: String
@export var straight := false
@export var exits := 2
@export var regions: Array[RouteRegion] = []

func at(s: float, branch: int) -> RouteRegion:
	for region in regions:
		if region.contains(s, branch):
			return region
	return null

func environment_at(s: float, branch: int) -> RouteRegion:
	var exact := at(s, branch)
	if exact: return exact
	# Retain the boundary biome while a successor chunk finishes uploading.
	# Interior gaps remain errors; this does not alter geometry ownership.
	var first: RouteRegion
	var last: RouteRegion
	for region in regions:
		if region.branch != branch: continue
		if first == null or region.start < first.start: first = region
		if last == null or region.end > last.end: last = region
	if first != null and s < first.start: return first
	if last != null and s >= last.end: return last
	return null

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	var types := {}
	if regions.size() > 12: errors.append("Study renderer supports at most 12 route regions")
	for region in regions:
		if region.key in ids: errors.append("Duplicate region id: " + str(region.key))
		ids[region.key] = true
		if region.space: types[region.space.get_instance_id()] = true
		if region.branch not in [-1, 0, 1, 2]: errors.append("Unknown study route branch")
		if not region.space or not region.space.layout or not region.space.atmosphere: errors.append("Missing type strategy/profile")
		if region.end <= region.start: errors.append("Invalid interval")
		if region.blend_length < 0 or region.blend_length > region.end - region.start: errors.append("Invalid blend length")
	for branch in ([0] if straight else [-1, 0, 1, 2] if exits == 3 else [-1, 0, 1]):
		var ordered: Array[RouteRegion] = []
		for region in regions:
			if region.branch == branch: ordered.append(region)
		ordered.sort_custom(func(a, b): return a.start < b.start)
		if ordered.is_empty(): errors.append("Missing route branch")
		for i in range(1, ordered.size()):
			if not is_equal_approx(ordered[i-1].end, ordered[i].start): errors.append("Route gap or overlap")
	if types.size() > 3: errors.append("Study floor material supports at most 3 active space types")
	return errors

static func coordinate(position: Vector2) -> Vector2:
	# Current study route has a trunk and two persistent curved branches.
	# Project onto sampled route pieces; no visual type is inferred from camera time.
	var best := INF
	var result := Vector2(position.y, 0)
	for branch in [-1, 0, 1]:
		var finish := ForestRoute.JUNCTION if branch == 0 else 6000.0
		var begin := -400.0 if branch == 0 else ForestRoute.JUNCTION
		var s := begin
		while s < finish:
			var next := minf(s + 80, finish)
			var a := ForestRoute.point_at(s, branch)
			var b := ForestRoute.point_at(next, branch)
			var t := clampf((position-a).dot(b-a) / (b-a).length_squared(), 0, 1)
			var distance := position.distance_squared_to(a.lerp(b, t))
			if distance < best:
				best = distance
				result = Vector2(lerpf(s, next, t), branch)
			s = next
	return result

func copy_for_editing() -> RoutePlan:
	# External resource references remain shared by ordinary duplicate(true).
	# Copy configuration explicitly; immutable textures and strategy scripts are shared.
	var copy := RoutePlan.new()
	copy.title = title
	copy.straight = straight
	copy.exits = exits
	var types := {}
	for region in regions:
		var source_id := region.space.get_instance_id()
		if source_id not in types:
			var style := region.space.duplicate(false) as SpaceType
			style.atmosphere = region.space.atmosphere.duplicate(true) as AtmosphereProfile
			types[source_id] = style
		var new_region := region.duplicate(false) as RouteRegion
		new_region.space = types[source_id]
		copy.regions.append(new_region)
	return copy
