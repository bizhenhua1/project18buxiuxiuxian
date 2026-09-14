class_name SegmentWorld
extends ForestWorld
var plan: RoutePlan
var assets := SpaceAssets.new()
var forest_source: Array[Dictionary] = []
var fields := {}
var camera_s := 0.0
var camera_branch := 0
var camera_region: RouteRegion
var biome_lights:Array[Vector4]=[]

func _init(art: ForestArt, route_plan: RoutePlan, empty:=false) -> void:
	super(art,route_plan.straight,empty or route_plan.regions.all(func(r):return r.space.key in ["crystal","swamp","sewer","whale","palace"] or FairytaleCatalog.has_scene(str(r.space.key))),route_plan.layout_seed)
	plan = route_plan
	assert(plan.validate().is_empty(), str(plan.validate()))
	if empty:
		camera_region=plan.regions[0]
		for region in plan.regions:
			fields[region.space.get_instance_id()]=SkyField.new(region.space.atmosphere)
		return
	forest_source = sprites
	for i in range(forest_source.size()):
		var sprite := forest_source[i]
		if sprite.has("route_s") and sprite.has("route_branch"): continue
		var coordinate := Vector2(sprite.position.y,0) if plan.straight else art.route_coordinates[i] if art.route_coordinates.size() == forest_source.size() else RoutePlan.coordinate(sprite.position)
		sprite.route_s = sprite.get("route_s",coordinate.x)
		sprite.route_branch = sprite.get("route_branch",int(coordinate.y))
	sprites = []
	for region in plan.regions:
		if region.space.get_instance_id() not in fields: fields[region.space.get_instance_id()] = SkyField.new(region.space.atmosphere)
		var strategy = region.space.layout.new()
		strategy.populate(self, region)
	camera_region = plan.at(0, 0)

func update_camera(s: float, branch: int) -> void:
	camera_s = s
	camera_branch = 0 if plan.at(s, 0) != null else branch
	camera_region = plan.environment_at(s, camera_branch)

func place_existing(sprite: Dictionary, region: RouteRegion) -> void:
	var value := sprite.duplicate()
	value.region = region
	value.altitude = 0.0
	value.motion = "static"
	value.id = sprites.size()
	for cover in value.get("root_cover",[]):
		cover.silhouette=assets.silhouette(cover.texture,region.space.atmosphere.depth_color)
	sprites.append(value)

func place(region: RouteRegion, s: float, offset: float, path: String, w: float, h: float, altitude := 0.0, flip := false, motion := "static") -> void:
	if s >= region.end: return
	var position := ForestRoute.point_at(s, region.branch, offset)
	if ("pillar-" in path or "wall-" in path) and (absf(position.x) if plan.straight else ForestRoute.road_distance(position)) < (130.0 if plan.straight else 250.0 if s > 600 and s < 1900 else 130.0):
		return
	sprites.append({"position": position, "texture": assets.texture("res://assets/" + path), "w": w, "h": h, "flip": flip, "kind": 0, "id": sprites.size(), "region": region, "route_s": s, "route_branch": region.branch, "altitude": altitude, "motion": motion})

func environment() -> Dictionary:
	# Lighting adapts near a physical boundary; geometry remains owned by its interval.
	var target := plan.at(camera_s + 120, camera_branch)
	if not target: target = camera_region
	var current := target.space
	var previous_region := plan.at(target.start - 0.01, camera_branch)
	if not previous_region: return {"a": current, "b": current, "weight": 1.0}
	var weight := smoothstep(target.start - 120, target.start + maxf(target.blend_length, 1), camera_s)
	return {"a": previous_region.space, "b": current, "weight": weight}
