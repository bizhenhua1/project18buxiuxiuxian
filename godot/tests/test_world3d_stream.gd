extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 app.phase="fork";app.choose_branch(2)
 assert(app.phase=="fork" and app.branch==0,"Unavailable third exit must not enter missing terrain")
 var max_chunks:=0;var generation_ms:Array=[]
 for branch in [-1,1]:
  app.branch=branch
  for n in 8:
   var end_s:=0.0
   for region in app.world.plan.regions:
    if region.branch==branch:end_s=maxf(end_s,region.end)
   app.distance=end_s-1400
   var before:int=app.stream_extensions;var begin:=Time.get_ticks_usec()
   app.extend_route_if_needed();generation_ms.append((Time.get_ticks_usec()-begin)/1000.0)
   assert(app.stream_extensions==before+1)
   assert(app.world.plan.at(end_s+1700,branch)!=null,"New interval must cover the future camera")
   assert(app.world.sprites.any(func(s):return int(s.get("route_branch",0))==branch and float(s.get("route_s",0))>end_s+1000),"Extending logic must also produce real scenery ahead")
   while not app.scenery.upload_jobs.is_empty():app.scenery.process_uploads()
   max_chunks=maxi(max_chunks,app.scenery.chunks.size())
   await process_frame
 assert(app.world.plan.regions.size()==5,"Shader region count must remain bounded")
 assert(max_chunks<2500,"Old cutout chunks must be retired")
 print("WORLD3D_STREAM_PASS extensions=",app.stream_extensions," peak_chunks=",max_chunks," generation_ms=",generation_ms)
 quit()

