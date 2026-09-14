extends SceneTree
const LIB="res://assets/fx/epic181/library/"
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 var catalog=JSON.parse_string(FileAccess.get_file_as_string(LIB+"index.json"));var spec:Dictionary={}
 for item in catalog:
  if item.name=="StormExplosion":spec=JSON.parse_string(FileAccess.get_file_as_string(LIB+item.file));break
 var viewport:=SubViewport.new();viewport.size=Vector2i(320,240);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var camera:=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(0,1,3);camera.look_at(Vector3(0,.5,0));camera.current=true
 var batch=preload("res://scripts/spaces/epic181_render_batch.gd").new();viewport.add_child(batch)
 var variants:Array=[[],[]]
 for mode in 2:
  for i in 4:
   var fx=preload("res://scripts/spaces/epic181_effect.gd").new();fx.gpu_curves=true;viewport.add_child(fx)
   fx.position=Vector3((i%2-.5)*.3,0,-i*.45);fx.setup(spec,camera,LIB);fx.scale=Vector3.ONE*.7
   if mode==1:
    if i==0:batch.register_kind("test",fx)
    fx.render_batch=batch;fx.render_kind="test"
   variants[mode].append(fx)
 var changed:=0;var worst:=0.0
 for frame in 40:
  batch.begin_frame(camera)
  for actors in variants:
   for fx in actors:fx.advance(1.0/60)
  batch.finish_frame();await process_frame
  if frame%10!=9:continue
  var captures:Array=[]
  for mode in 2:
   for index in 2:
    for fx in variants[index]:fx.visible=index==mode
   batch.visible=mode==1
   for settle in 3:await process_frame
   await RenderingServer.frame_post_draw
   captures.append(viewport.get_texture().get_image())
  for y in 240:
   for x in 320:
    var a:Color=captures[0].get_pixel(x,y);var b:Color=captures[1].get_pixel(x,y)
    var error:=maxf(maxf(absf(a.r-b.r),absf(a.g-b.g)),absf(a.b-b.b))
    worst=maxf(worst,error)
    if error>2.0/255:changed+=1
  if frame==19:
   captures[0].save_png("res://../tempassets/work/epic-overlap-original.png")
   captures[1].save_png("res://../tempassets/work/epic-overlap-batch.png")
 print("EPIC_BATCH_OVERLAP frames=4 emitters=4 changed=",changed," / ",4*320*240," max=",worst," dropped=",batch.dropped)
 viewport.queue_free();await process_frame
 if changed>int(4*320*240*.0005):push_error("Batching changed overlapping transparency");quit(1);return
 quit()
