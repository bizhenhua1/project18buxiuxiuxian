extends SceneTree
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LIB="res://assets/fx/epic181/library/"
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 var catalog=JSON.parse_string(FileAccess.get_file_as_string(LIB+"index.json"));var entry:Dictionary={}
 for item in catalog:
  if item.name=="StormMissile":entry=item;break
 var comparisons:=0;var worst:=0.0;var changed_pixels:=0;var measured_pixels:=0
 var world_offset:=Vector3(128,7,-256) if "--world-offset" in OS.get_cmdline_user_args() else Vector3.ZERO
 for id in [entry.id,entry.muzzle_id,entry.impact_id]:
  var prior_changed:=changed_pixels
  var spec:Dictionary={}
  for item in catalog:
   if item.id==id:spec=JSON.parse_string(FileAccess.get_file_as_string(LIB+item.file));break
  if "--random-color" in OS.get_cmdline_user_args():
   for layer in spec.layers:
    layer.color=[[[.2,.8,.4,.9]],[[.9,.3,.6,.5]]]
    layer.gradient=[[[1,.3,.2,1],[.1,1,.6,.1]],[[.6,.7,1,.4],[1,.2,.5,.8],[.3,.7,.8,.6]]]
  if "--random-noise" in OS.get_cmdline_user_args():
   for layer in spec.layers:layer.noise=[[0,1,.4],[.5,0]]
  var views:Array=[];var actors:Array=[]
  var batch
  var viewport:=SubViewport.new();viewport.size=Vector2i(256,256);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);views.append(viewport)
  var camera:=Camera3D.new();viewport.add_child(camera);camera.position=world_offset+Vector3(0,1,3);camera.look_at(world_offset+Vector3(0,.5,0));camera.current=true
  for mode in 2:
   var actor:=FX.new();actor.gpu_curves=mode==1 and "--cpu-control" not in OS.get_cmdline_user_args();actor.gpu_motion=actor.gpu_curves and "--gpu-particle-motion" in OS.get_cmdline_user_args();viewport.add_child(actor);actor.setup(spec,camera,LIB);actor.scale=Vector3(.6,.7,.8)
   actors.append(actor)
   if mode==1 and "--batch-particles" in OS.get_cmdline_user_args():
    batch=preload("res://scripts/spaces/epic181_render_batch.gd").new();viewport.add_child(batch);batch.register_kind("test",actor);actor.render_batch=batch;actor.render_kind="test"
  for arg in OS.get_cmdline_user_args():
   if arg.begins_with("--layer="):
    var selected:=int(arg.get_slice("=",1))
    for actor in actors:
     for child in actor.get_children():
      if child is GeometryInstance3D:child.visible=child.get_index()==selected
  for frame in 60:
   var dt:float=[1.0/120,.05,.011,1.0/30][frame%4] if "--varied-step" in OS.get_cmdline_user_args() else 1.0/60
   if "--moving-camera" in OS.get_cmdline_user_args():
    camera.position=world_offset+Vector3(sin(frame*.02)*.4,1+sin(frame*.01)*.2,3);camera.look_at(world_offset+Vector3(0,.5,0))
   if batch!=null:batch.begin_frame(camera)
   for actor in actors:
    actor.position=world_offset+Vector3(sin(frame*.05)*.2,0,0);actor.rotation.y=frame*.01;actor.advance(dt)
   if batch!=null:batch.finish_frame()
   await process_frame
   if frame%10!=9:continue
   if "--cpu-control" in OS.get_cmdline_user_args():
    for layer_index in actors[0].layers.size():
     var lhs=actors[0].layers[layer_index];var rhs=actors[1].layers[layer_index]
     assert(lhs.particles.size()==rhs.particles.size(),"Particle counts differ")
     for i in lhs.particles.size():
      for field in ["age","life","random","position","velocity","rotation","size","tile","base_color","gpu_color","motion_data","motion_slot"]:
       assert(lhs.particles[i].get(field)==rhs.particles[i].get(field),"Particle state differs: "+field)
      assert(lhs.mm.get_instance_transform(i)==rhs.mm.get_instance_transform(i))
      assert(lhs.mm.get_instance_color(i)==rhs.mm.get_instance_color(i))
      assert(lhs.mm.get_instance_custom_data(i)==rhs.mm.get_instance_custom_data(i))
   var captures:Array=[]
   for mode in 2:
    actors[0].visible=mode==0;actors[1].visible=mode==1
    if batch!=null:batch.visible=mode==1
    for settle in 3:await process_frame
    await RenderingServer.frame_post_draw
    captures.append(viewport.get_texture().get_image())
   var a:Image=captures[0];var b:Image=captures[1]
   if frame==29:
    a.save_png("res://../tempassets/work/epic-curves-"+str(id)+"-cpu.png")
    b.save_png("res://../tempassets/work/epic-curves-"+str(id)+"-gpu.png")
   for y in 256:
    for x in 256:
     var ca:=a.get_pixel(x,y);var cb:=b.get_pixel(x,y)
     var error:=maxf(maxf(absf(ca.r-cb.r),absf(ca.g-cb.g)),absf(ca.b-cb.b))
     worst=maxf(worst,error);measured_pixels+=1
     if error>2.0/255:changed_pixels+=1
   comparisons+=1
  for view in views:view.queue_free()
  await process_frame
  print("CURVE_ASSET ",id," changed=",changed_pixels-prior_changed)
 print("EPIC_GPU_CURVES_COMPARE frames=",comparisons," max_channel_error=",worst," changed_pixels=",changed_pixels," / ",measured_pixels)
 if float(changed_pixels)/measured_pixels>=.0005:
  push_error("GPU lifetime curves changed rendered effect");quit(1);return
 quit()
