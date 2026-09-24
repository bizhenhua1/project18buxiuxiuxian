extends SceneTree
func _initialize() -> void:
 ForestRoute.reset_frame();ForestRoute.configure(false)
 var plan:RoutePlan=preload("res://scripts/world3d/themes.gd").plan("crystal",3,1842)
 var world:=SegmentWorld.new(ForestArt.new(),plan)
 print("STAGE_JUNCTION ",ForestRoute.JUNCTION," sprites=",world.sprites.size())
 for sprite in world.sprites:
  var s:float=float(sprite.route_s)
  if s<ForestRoute.JUNCTION-80 or s>ForestRoute.JUNCTION+460:continue
  if sprite.get("shell",false):
   print("ARCH s=",snappedf(s,.1)," branch=",sprite.route_branch," bridge=",sprite.get("junction_bridge",false)," entry=",sprite.get("junction_entry",false)," width=",snappedf(sprite.w,.1))
  elif float(sprite.h)>40:
   print("LARGE s=",snappedf(s,.1)," branch=",sprite.route_branch," art=",sprite.texture.resource_path.get_file()," height=",snappedf(sprite.h,.1)," point=",sprite.position)
 quit()
