extends SceneTree
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":push_error("Requires GPU uploads");quit(1);return
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 var sources:Array=app.world.sprites
 if "--verify-pending-bounds" in OS.get_cmdline_user_args():
  var checked:=0
  for sprite in sources:
   var groups:Dictionary={};app.scenery.add_sprite_to_groups(sprite,groups)
   var pending:Rect2=app.scenery.pending_sprite_rect(sprite)
   for group in groups.values():
    var box:AABB=group.bounds
    var actual:=Rect2(Vector2(box.position.x,-box.end.z)*20,Vector2(box.size.x,box.size.z)*20)
    assert(pending.encloses(actual),"Pending coverage omitted a generated asset edge")
    checked+=1
  print("PENDING_BOUNDS_VERIFIED actual groups=",checked)
 var results:Array=[]
 for mode in ([] if "--cleanup-only" in OS.get_cmdline_user_args() else [false,true,true,false]):
  var scenery=preload("res://scripts/world3d/scenery.gd").new();root.add_child(scenery);scenery.hide()
  scenery.stream_spatial_blocks=mode;scenery.trunk_placement=null
  scenery.queue_sprites(sources)
  var total:=0;var first_cpu:=-1;var first_steps:=0;var steps:=0;var peak:=0
  var started:=Time.get_ticks_usec();var first_wall:=-1
  while not scenery.upload_jobs.is_empty() and steps<10000:
   var began:=Time.get_ticks_usec();scenery.process_uploads(1500)
   var elapsed:=Time.get_ticks_usec()-began;total+=elapsed;peak=maxi(peak,elapsed);steps+=1
   if first_cpu<0 and not scenery.chunks.is_empty():first_cpu=total;first_steps=steps;first_wall=Time.get_ticks_usec()-started
   await process_frame
  assert(scenery.upload_jobs.is_empty())
  var result:Dictionary={"streamed":mode,"source_count":sources.size(),"first_cpu_ms":first_cpu/1000.0,"first_wall_ms":first_wall/1000.0,"first_steps":first_steps,"cpu_ms":total/1000.0,"peak_step_ms":peak/1000.0,"steps":steps,"batches":scenery.chunks.size(),"instances":scenery.imported_count}
  if not results.is_empty():assert(result.batches==results[0].batches and result.instances==results[0].instances)
  results.append(result);print("STREAMING_SAMPLE ",JSON.stringify(result))
  scenery.queue_free();await process_frame;await process_frame
 if not results.is_empty():FileAccess.open("res://../tempassets/work/world3d-streaming-benchmark.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
 print("WORLD3D_STREAMING_BENCHMARK_DONE warm assets; submission CPU only, not gameplay FPS")
 sources=[];app.queue_free();app=null
 for frame in 4:await process_frame
 quit()
