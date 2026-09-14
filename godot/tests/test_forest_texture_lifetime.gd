extends SceneTree
func _initialize():call_deferred("run")
func run():
 var first:=ForestEcology.root_texture("fern")
 var same:=ForestEcology.root_texture("fern")
 assert(first==same)
 ForestEcology.root_texture("clover")
 var count:=ForestEcology.textures.size()
 var temporary:=Node.new();root.add_child(temporary);temporary.queue_free();await process_frame
 assert(ForestEcology.textures.size()==count and ForestEcology.root_texture("fern")==first,"Leaving a world must preserve shared art")
 var connections:=0
 for connection in root.tree_exiting.get_connections():
  if connection.callable==ForestEcology.release_textures:connections+=1
 assert(connections==1,"One shutdown hook for the shared cache")
 first=null;same=null
 root.tree_exiting.connect(func():
  assert(ForestEcology.textures.is_empty(),"Root exit must clear shared GPU references")
  print("FOREST_TEXTURE_LIFETIME_PASS shared during play; one shutdown hook; empty at root exit"))
 quit()
