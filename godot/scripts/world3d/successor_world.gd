extends RefCounted
# Existing layout adapters still use ForestRoute. Scope that context to generation only.
static func build(segment,space:SpaceType,assets:SpaceAssets)->SegmentWorld:
 var saved=[ForestRoute.origin,ForestRoute.origin_s,ForestRoute.origin_heading,ForestRoute.JUNCTION,ForestRoute.TURN_LENGTH,ForestRoute.cave_fork]
 ForestRoute.origin=Vector2.ZERO;ForestRoute.origin_s=0;ForestRoute.origin_heading=0
 ForestRoute.JUNCTION=segment.junction_s-segment.start_s;ForestRoute.TURN_LENGTH=segment.turn_length
 ForestRoute.cave_fork=segment.theme=="crystal"
 var plan:=RoutePlan.new();plan.layout_seed=segment.seed_value;plan.exits=segment.exits;plan.title="连续路段"
 for branch in ([0,-1,1,2] if segment.exits==3 else [0,-1,1]):
  var region:=RouteRegion.new();region.key=StringName("segment_%d_%d"%[segment.seed_value,branch]);region.branch=branch
  region.start=0 if branch==0 else segment.junction_s-segment.start_s
  region.end=segment.junction_s-segment.start_s if branch==0 else segment.end_s-segment.start_s+1800
  region.space=space;plan.regions.append(region)
 var world:=SegmentWorld.new(ForestArt.new(),plan,space.key!=&"forest");world.assets=assets;world.seed_value=segment.seed_value
 if space.key!=&"forest":
  for region in plan.regions:space.layout.new().populate(world,region)
 # Legacy layout clustering assumes a local north axis. Transform the finished placement once.
 for sprite in world.sprites:
  sprite.position=segment.origin+sprite.position.rotated(-segment.heading)
  sprite.route_s=float(sprite.route_s)+segment.start_s
  if sprite.has("plane_heading"):sprite.plane_heading+=segment.heading
 for region in plan.regions:region.start+=segment.start_s;region.end+=segment.start_s
 for i in world.biome_lights.size():
  var light:Vector4=world.biome_lights[i];var p:Vector2=segment.origin+Vector2(light.x,light.z).rotated(-segment.heading)
  world.biome_lights[i]=Vector4(p.x,light.y,p.y,light.w)
 ForestRoute.origin=saved[0];ForestRoute.origin_s=saved[1];ForestRoute.origin_heading=saved[2];ForestRoute.JUNCTION=saved[3];ForestRoute.TURN_LENGTH=saved[4]
 ForestRoute.cave_fork=saved[5]
 return world
