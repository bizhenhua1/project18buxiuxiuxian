extends SceneTree
const THEMES=preload("res://scripts/world3d/themes.gd")
const SEGMENT=preload("res://scripts/world3d/route_segment.gd")
const BUILDER=preload("res://scripts/world3d/successor_world.gd")
func _initialize():call_deferred("run")
func run():
 ForestRoute.reset_frame();ForestRoute.configure(false)
 var assets:=SpaceAssets.new()
 for key in THEMES.KEYS:
  var plan:RoutePlan=THEMES.plan(key)
  assert(plan.validate().is_empty())
  if key=="connected":
   assert(plan.regions.any(func(r):return r.space.key==&"crystal"))
   assert(plan.regions.any(func(r):return r.space.key==&"swamp"))
   continue
  assert(plan.regions.all(func(r):return str(r.space.key)==key))
  var straight=SEGMENT.new(2200,Vector2.ZERO,0,4300,420,5900,3,713,key)
  var turned=SEGMENT.new(2200,Vector2(370,1900),.7,4300,420,5900,3,713,key)
  var space:SpaceType=plan.regions[0].space
  var reference:SegmentWorld=BUILDER.build(straight,space,assets)
  var transformed:SegmentWorld=BUILDER.build(turned,space,assets)
  assert(not transformed.sprites.is_empty(),"Missing successor scenery: "+key)
  assert(reference.sprites.size()==transformed.sprites.size())
  assert(ForestRoute.origin==Vector2.ZERO and ForestRoute.origin_s==0 and ForestRoute.origin_heading==0)
  assert(ForestRoute.JUNCTION==700 and ForestRoute.TURN_LENGTH==420)
  for i in range(0,reference.sprites.size(),17):
   var expected:Vector2=turned.origin+reference.sprites[i].position.rotated(-turned.heading)
   assert(expected.distance_to(transformed.sprites[i].position)<.01)
   assert(reference.sprites[i].route_s==transformed.sprites[i].route_s)
  assert(reference.biome_lights.size()==transformed.biome_lights.size())
  for i in reference.biome_lights.size():
   var before:Vector4=reference.biome_lights[i];var after:Vector4=transformed.biome_lights[i]
   var expected:Vector2=turned.origin+Vector2(before.x,before.z).rotated(-turned.heading)
   assert(expected.distance_to(Vector2(after.x,after.z))<.01)
   assert(before.y==after.y and before.w==after.w,"Turning a light must retain its height and radius")
  print("WORLD3D_THEME_PASS ",key," sprites=",transformed.sprites.size()," lights=",transformed.biome_lights.size())
 print("WORLD3D_THEMES_PASS themes=",THEMES.KEYS.size()-1," rotated successor scenery and lights, scoped route context")
 quit()
