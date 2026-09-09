extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame
 app.set_process(false)
 app.phase="choose";app.choose(-1);app.encounter_step=999;app.route_spec.end=100000
 app.fork_transit_time=3
 var data:Array=[]
 for frame in range(1200):
  app.speed=1
  app._process(1.0/30)
  await process_frame
  await RenderingServer.frame_post_draw
  var r=app.arena.scenery.renderer
  var actor:Dictionary=r.battle_actors.filter(func(a):return a.get("live_character",false))[0]
  var batch=r.forest_batch
  assert(batch.dynamic_indices.has(actor.id))
  var gpu_relative:Vector2=batch.dynamic_positions[batch.dynamic_indices[actor.id]]
  assert(gpu_relative.is_equal_approx(actor.position-r.camera_world))
  data.append([frame,app.distance,app.camera.x,app.camera.y,app.heading,r.horizon_y(),actor.position.x,actor.position.y,actor.h,app.arena.seer.player.current_animation_position,r.forest_batch.batch.instance_count])
  if frame%300==299:root.get_texture().get_image().save_png("res://../tempassets/work/long-camera-%d.png"%frame)
 FileAccess.open("res://../tempassets/work/camera-long.json",FileAccess.WRITE).store_string(JSON.stringify(data))
 print("LONG_TRACE_DONE ",data.size());quit()

