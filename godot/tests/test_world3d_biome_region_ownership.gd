extends SceneTree
func _initialize():call_deferred("run")
func run():
 for theme in ["palace","sewer","whale","swamp","crystal"]:
  ForestRoute.reset_frame();ForestRoute.configure(false)
  var native_plan:RoutePlan=preload("res://scripts/world3d/themes.gd").plan(theme)
  var legacy_plan:RoutePlan=native_plan.duplicate(true)
  for region in legacy_plan.regions:region.space.layout=load("res://scripts/spaces/layouts/biome_layout.gd")
  var legacy:=SegmentWorld.new(ForestArt.new(),legacy_plan)
  var native:=SegmentWorld.new(ForestArt.new(),native_plan)
  var expected:Array=[];var removed:=0
  for sprite in legacy.sprites:
   var shell_s:float=float(sprite.route_s)+(1.0 if sprite.get("outflow",false) else 0.0)
   if (sprite.get("shell",false) or sprite.get("outflow",false)) and sprite.region.branch!=0 and shell_s<sprite.region.start:
    removed+=1;continue
   expected.append(sprite)
  assert(expected.size()==native.sprites.size(),"Only out-of-region structures may be removed")
  for i in expected.size():
   var a:Dictionary=expected[i].duplicate();var b:Dictionary=native.sprites[i].duplicate()
   for key in ["region","id"]:a.erase(key);b.erase(key)
   assert(a==b,"Random sequence or surviving art placement changed: %s %d"%[theme,i])
  assert(legacy.biome_lights==native.biome_lights)
  assert(native_plan.regions[0].space.layout==load("res://scripts/world3d/biome_layout.gd"))
  print("REGION_OWNERSHIP ",theme," removed=",removed," preserved=",expected.size())
 print("WORLD3D_BIOME_REGION_OWNERSHIP_PASS surviving source properties and lights unchanged")
 quit()
