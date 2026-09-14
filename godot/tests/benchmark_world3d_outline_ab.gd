extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false);app.portrait_mode=true;app.atmosphere_mode=true
 app.start_battle()
 for i in 200:app._process(.02)
 assert(app.phase=="battle")
 var rows:Array=[]
 for mode in [false,true,true,false]:
  app.outline_lod.sync(app.camera,Vector2(root.size),true,mode)
  for i in 12:await process_frame
  var times:Array=[];var cpu:=0;var calls:Array=[];var last:=Time.get_ticks_usec()
  for i in 120:
   var start:=Time.get_ticks_usec()
   app.outline_lod.sync(app.camera,Vector2(root.size),true,mode)
   cpu+=Time.get_ticks_usec()-start
   await process_frame
   var now:=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
   calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  times.sort();calls.sort()
  var sum:=0.0
  for value in times:sum+=value
  rows.append({"lod":mode,"mean_ms":sum/times.size(),"p95_ms":times[114],"lod_cpu_ms":cpu/120000.0,"draws":calls[60],"skipped":app.outline_lod.skipped_passes})
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/world3d-outline-"+("lod" if mode else "full")+".png")
 var file:=FileAccess.open("res://../tempassets/work/world3d-outline-ab.json",FileAccess.WRITE)
 file.store_string(JSON.stringify(rows,"  "))
 print("WORLD3D_OUTLINE_FROZEN_AB ",JSON.stringify(rows))
 quit()
