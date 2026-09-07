extends RefCounted
## Adapter retaining the accepted seeded forest layout byte-for-byte.
func populate(world, region: RouteRegion) -> void:
	for sprite in world.forest_source:
		if region.contains(sprite.route_s, sprite.route_branch):
			world.place_existing(sprite, region)
