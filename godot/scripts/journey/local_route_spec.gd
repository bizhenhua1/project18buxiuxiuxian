class_name LocalRouteSpec
extends RefCounted
## A tile owns its biome; topology and event sequence are independent of biome.
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/local_encounters.json"))
static func profile(zone: Dictionary) -> Dictionary:
	var key: String = zone.get("route_profile","short_battle")
	if zone.get("route_kind","") == "fork": key = "fork"
	var result: Dictionary = catalog[key].duplicate(true)
	result.theme = zone.get("theme","forest")
	return result
static func entries(zone: Dictionary, direction: int) -> Array:
	var spec := profile(zone)
	var result: Array = spec["left" if direction == -1 else "right"] if spec.fork else spec.events
	for entry in result: entry.choice = entry.get("choice",zone.get("battle_choice",false))
	return result
static func plan(zone: Dictionary) -> RoutePlan:
	var spec := profile(zone)
	var result := RoutePlan.new()
	result.title = zone.get("title","地块探索")
	result.straight = not spec.fork
	var space := load("res://spaces/types/%s.tres" % spec.theme) as SpaceType
	space = StyleLibrary.space(space)
	for branch in ([0] if result.straight else [0,-1,1]):
		var region := RouteRegion.new()
		region.key = StringName("%s_%d" % [spec.theme,branch])
		region.branch = branch
		region.start = -400 if branch == 0 else ForestRoute.JUNCTION
		region.end = 6000 if result.straight or branch != 0 else ForestRoute.JUNCTION
		region.space = space
		result.regions.append(region)
	return result
