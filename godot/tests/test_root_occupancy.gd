extends SceneTree
func _initialize():call_deferred("run")
func run():
 StyleLibrary.active=true
 ForestSettings.values=ForestSettings.PRESETS["幽暗密林"].duplicate()
 var art=ForestArt.new()
 ForestRoute.configure(true)
 var world=ForestWorld.new(art,false)
 var kept:Array=[]
 for sprite in world.sprites:kept.append(sprite.id)
 var names=PackedStringArray()
 for id in kept:names.append(str(id))
 assert(",".join(names).sha256_text()=="0c327d96b5a6fe37b0307f9542d780211ee38088adb3d7b88a0a477e90d71f11")
 for sprite in world.sprites:
  if sprite.kind==0:assert(sprite.root_cover.size()==5)
 print("ROOT_OCCUPANCY_PASS identical=",kept.size())
 quit()
