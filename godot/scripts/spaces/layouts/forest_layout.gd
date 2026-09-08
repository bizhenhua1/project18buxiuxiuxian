extends RefCounted
## Adapter retaining the accepted seeded forest layout byte-for-byte.
func populate(world, region: RouteRegion) -> void:
	for sprite in world.forest_source:
		if world.plan.exits == 3 and region.branch == 2 and sprite.route_branch == 1:
			var value:Dictionary=sprite.duplicate(true)
			var pose:=ForestRoute.pose(value.route_s,1)
			var offset:float=ForestRoute.to_camera(value.position,pose.position,pose.heading).x
			value.position=ForestRoute.point_at(value.route_s,2,offset)
			value.route_branch=2
			if ForestRoute.road_distance(value.position,true)>65:world.place_existing(value,region)
		if region.contains(sprite.route_s, sprite.route_branch):
			if world.plan.exits==3 and absf(sprite.position.x)<65 and sprite.position.y>700:continue
			world.place_existing(sprite, region)
