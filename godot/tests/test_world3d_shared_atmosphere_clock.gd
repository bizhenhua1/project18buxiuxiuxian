extends SceneTree
func _initialize():call_deferred("run")
func snapshot()->Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 root.size=Vector2i(640,400)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 var service=app.actor_atmosphere;service.set_enabled(true)
 var max_error:=0.0;var samples:=0
 for time_value in [0.0,.016,1.37,120.2,3600.5,43200.1]:
  app.bridge.elapsed=time_value
  service.shared_clock_enabled=false
  for entry in service.entries:entry.material.set_shader_parameter("shared_atmosphere_clock_enabled",false)
  service.sync(app.bridge,true)
  var reference:=await snapshot()
  service.shared_clock_enabled=true
  for entry in service.entries:service.bind_clock(entry.material)
  service.sync(app.bridge,true)
  var actual:=await snapshot();var changed:=0
  for y in root.size.y:
   for x in root.size.x:
    var a:=actual.get_pixel(x,y);var b:=reference.get_pixel(x,y)
    var error:float=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
    max_error=maxf(max_error,error)
    if error>2.0/255:changed+=1
  assert(changed==0,"Shared clock changed actual actor lighting")
  samples+=root.size.x*root.size.y
 print("WORLD3D_SHARED_CLOCK_PASS pixels=",samples," max_channel_error=",max_error)
 quit()
