extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 set_meta("tour_biome","crystal")
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.arena.set_process(false)
 for i in range(4):await process_frame
 var renderer=app.arena.scenery.renderer
 var batch=renderer.forest_batch
 renderer.battle_actors.clear()
 for i in range(160):
  renderer.battle_actors.append({"mist":true,"actor":true,"born_at":-100,"position":renderer.camera_world+Vector2(0,100),"texture":batch.source[0].texture,"w":50.0,"h":15.0,"altitude":2.0,"flip":false,"id":9000000+i,"region":renderer.world.camera_region})
 for frame in range(8):
  batch.sync(renderer)
  var unique:Dictionary={}
  for slot in batch.dynamic_slots:
   assert(not unique.has(slot),"Dynamic instances overwrite each other")
   unique[slot]=true
  assert(unique.size()>=160)
  assert(batch.batch.visible_instance_count==batch.entries.size()+unique.size())
  for i in range(1,batch.insertion_points.size()):assert(batch.insertion_points[i]>=batch.insertion_points[i-1])
 print("DENSE_MIST_PASS 160 coincident patches have unique correctly ordered slots")
 quit()
