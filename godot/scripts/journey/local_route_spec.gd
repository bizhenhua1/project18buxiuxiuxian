class_name LocalRouteSpec
extends RefCounted
## A tile owns its biome; topology and event sequence are independent of biome.
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/local_encounters.json"))
static func profile(zone: Dictionary) -> Dictionary:
	var key: String = zone.get("route_profile","short_battle")
	if zone.get("route_kind","") == "fork": key = "fork"
	var result: Dictionary = catalog[key].duplicate(true)
	result.theme = zone.get("theme","forest")
	result.exits = int(zone.get("exits",2))
	result.before_fork = result.fork and zone.get("event_placement","after")=="before"
	var first:=TravelPace.leg_distance(int(zone.get("endless_leg",1))==1)
	var walk:=TravelPace.EXIT_DISTANCE+TravelPace.mixed_distance()
	var preview:=TravelPace.WALK
	result.junction=(first+walk if result.before_fork else first)+preview
	result.fork_clearance=TravelPace.WALK*1.2+TravelPace.RUN*3.0
	if result.fork:
		for side in ["left","right"]:
			var previous:=0.0
			for i in range(result[side].size()):
				if result.before_fork and i==0:previous=first
				elif i==0 or (result.before_fork and i==1):previous=result.junction-preview+TravelPace.mixed_distance(true)
				else:previous+=walk
				result[side][i].distance=previous
			result.end=previous+walk
	else:
		for i in range(result.events.size()):result.events[i].distance=first+i*walk
		result.end=first+result.events.size()*walk
	if zone.get("combat_only",false):
		for branch_key in (["left","right"] if result.fork else ["events"]):
			for event in result[branch_key]:
				event.kind="battle";event.erase("event");event.choice=true;event.reward=2
	var offset:float=zone.get("endless_offset",0.0)
	if offset!=0:
		result.junction+=offset;result.end+=offset
		for branch_key in (["left","right"] if result.fork else ["events"]):
			for event in result[branch_key]:event.distance+=offset
	return result
static func entries(zone: Dictionary, direction: int) -> Array:
	var spec := profile(zone)
	var result: Array = (spec["left" if direction == -1 else "right"] if spec.fork else spec.events).duplicate(true)
	if spec.before_fork:result[0]=spec.right[0].duplicate(true)
	for i in range(result.size()):
		var entry:Dictionary=result[i]
		entry.choice = entry.get("choice",zone.get("battle_choice",false))
		entry.branch = 0 if not spec.fork or (spec.before_fork and i==0) else (1 if direction==0 else direction)
		entry.visual_distance = float(entry.distance)+180.0
		if spec.fork and entry.branch!=0:
			entry.distance=maxf(entry.distance,spec.junction+spec.fork_clearance)
			entry.visual_distance=float(entry.distance)+180.0
		entry.reveal_distance=0.0 # Instantiate as soon as this leg is selected, at its fixed world position.
		if spec.before_fork and i==0:entry.visual_distance=minf(entry.visual_distance,spec.junction-TravelPace.WALK)
		entry.spawn_distance=entry.visual_distance+TravelPace.MONSTER_WALK_SPEED*TravelPace.MONSTER_APPROACH_SECONDS
		if spec.before_fork and i==0:entry.spawn_distance=minf(entry.spawn_distance,spec.junction-TravelPace.WALK*.25)
		assert(not spec.fork or entry.branch!=0 or entry.visual_distance<spec.junction)
	return result
static func plan(zone: Dictionary) -> RoutePlan:
	var spec := profile(zone)
	var result := RoutePlan.new()
	result.title = zone.get("title","地块探索")
	result.straight = not spec.fork
	ForestRoute.configure(spec.fork,spec.junction,TravelPace.WALK)
	result.exits = spec.exits
	var catalog=preload("res://scripts/spaces/biome_catalog.gd")
	var space:SpaceType
	if spec.theme in catalog.TITLES:space=catalog.make_space(spec.theme)
	else:space=StyleLibrary.space(load("res://spaces/types/%s.tres" % spec.theme) as SpaceType)
	for branch in ([0] if result.straight else [0,-1,1,2] if result.exits == 3 else [0,-1,1]):
		var region := RouteRegion.new()
		region.key = StringName("%s_%d" % [spec.theme,branch])
		region.branch = branch
		region.start = float(zone.get("endless_offset",0))-400 if branch == 0 else ForestRoute.JUNCTION
		region.end = float(spec.end)+1800.0 if result.straight or branch != 0 else ForestRoute.JUNCTION
		region.space = space
		result.regions.append(region)
	return result
