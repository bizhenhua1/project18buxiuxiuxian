extends SceneTree

# Headless structural contract for the original cave artwork; no captures.
func _initialize() -> void:
 ForestRoute.reset_frame()
 ForestRoute.configure(true,TravelPace.leg_distance(true)+TravelPace.WALK,TravelPace.WALK)
 var config:Dictionary=preload("res://scripts/spaces/biome_catalog.gd").CONFIG["crystal"]
 var seed_value:=1842
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--seed="):seed_value=int(arg.trim_prefix("--seed="))
 for exits in [2,3]:
  var world:Dictionary={"seed_value":seed_value+104729,"plan":{"straight":false,"exits":exits},"sprites":[],"biome_lights":[]}
  var branches:Array=[0,-1,1,2] if exits==3 else [0,-1,1]
  for branch in branches:
   var region:=RouteRegion.new()
   region.branch=branch
   region.start=-400.0 if branch==0 else ForestRoute.JUNCTION
   region.end=ForestRoute.JUNCTION if branch==0 else ForestRoute.JUNCTION+1200.0
   region.space=preload("res://scripts/spaces/biome_catalog.gd").make_space("crystal")
   preload("res://scripts/spaces/layouts/biome_layout.gd").new().populate(world,region)
  var shell_by_branch:Dictionary={}
  for branch in branches:shell_by_branch[branch]=[]
  for sprite in world.sprites:
   if not sprite.get("shell",false):continue
   assert(sprite.texture.resource_path=="res://assets/biomes/crystal/shell.png")
   assert(sprite.w<=float(config.width)*1.07)
   assert(sprite.w>=float(config.width)*.95,"A selected exit must keep the complete cave arch")
   var branch:int=int(sprite.route_branch)
   shell_by_branch[branch].append(float(sprite.route_s))
  for branch in branches:
   var samples:Array=shell_by_branch[branch]
   samples.sort()
   assert(not samples.is_empty())
   for index in range(1,samples.size()):
    assert(samples[index]-samples[index-1]<120.0)
  var shared:Array=shell_by_branch[0]
  assert(float(shared.back())>ForestRoute.JUNCTION+300.0)
  assert(world.sprites.any(func(sprite):return sprite.get("junction_bridge",false)),"Shared roof needs an explicit retirement set")
  for sprite in world.sprites:
   assert(not (int(sprite.route_branch)==0 and not sprite.get("shell",false) and absf(float(sprite.route_s)-(ForestRoute.JUNCTION+500.0))<.01),"The fork divider must not block the chosen road")
  for branch in branches:
   if branch==0:continue
   var exit_samples:Array=shell_by_branch[branch]
   assert(float(exit_samples[0])-float(shared.back())<80.0)
   assert(world.sprites.any(func(sprite):return sprite.get("junction_entry",false) and int(sprite.route_branch)==branch),"Every exit needs its own handoff arches")
   for camera_s in range(int(ForestRoute.JUNCTION),int(ForestRoute.JUNCTION+560.0),20):
    var camera:Dictionary=ForestRoute.pose(float(camera_s),branch)
    var selected_ahead:=false
    for sprite in world.sprites:
     if int(sprite.route_branch)==branch and not sprite.get("shell",false) and float(sprite.h)>20.0:
      var prop_relative:Vector2=ForestRoute.to_camera(sprite.position,camera.position,camera.heading)
      assert(not (prop_relative.y>30.0 and prop_relative.y<220.0 and absf(prop_relative.x)<float(sprite.w)*.5+60.0),"Cave prop blocks chosen road: exits=%d branch=%d camera=%d prop=%s lateral=%.1f"%[exits,branch,camera_s,sprite.texture.resource_path,prop_relative.x])
     if not sprite.get("shell",false) or int(sprite.route_branch)!=branch:continue
     var relative:Vector2=ForestRoute.to_camera(sprite.position,camera.position,camera.heading)
     if relative.y>=70.0 and relative.y<=250.0 and absf(relative.x)<float(sprite.w)*.2:
      selected_ahead=true;break
    assert(selected_ahead,"Selected cave road has no correctly aligned arch ahead: exits=%d branch=%d s=%d"%[exits,branch,camera_s])
  # A static spacing check misses an arch that ends up beside the camera after
  # the bend. Sample camera-relative space along the real route as well.
  for branch in branches:
   var begin:int=0 if branch==0 else int(ForestRoute.JUNCTION)
   var finish:int=int(ForestRoute.JUNCTION)-100 if branch==0 else int(ForestRoute.JUNCTION)+900
   for camera_s in range(begin,finish,20):
    var camera:Dictionary=ForestRoute.pose(float(camera_s),branch)
    var framed:=false
    for sprite in world.sprites:
     if not sprite.get("shell",false):continue
     var owner:int=int(sprite.route_branch)
     if owner!=branch and not (branch!=0 and owner==0):continue
     var relative:Vector2=ForestRoute.to_camera(sprite.position,camera.position,camera.heading)
     if relative.y>=120.0 and relative.y<=420.0 and absf(relative.x)<float(sprite.w)*.3:
      framed=true;break
    assert(framed,"No cave arch ahead: exits=%d branch=%d s=%d"%[exits,branch,camera_s])
  print("crystal shell continuity: %d exits, %d shared arches"%[exits,shared.size()])
 quit()
