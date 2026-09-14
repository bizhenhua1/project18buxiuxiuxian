extends SceneTree
func _initialize():call_deferred("run")
func shot()->Image:
 for frame in 4:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func difference(a:Image,b:Image)->Dictionary:
 var changed:=0;var maximum:=0.0;var total:=0.0
 for y in a.get_height():
  for x in a.get_width():
   var p:=a.get_pixel(x,y);var q:=b.get_pixel(x,y)
   var error:=maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))
   if error>1.0/255:changed+=1
   maximum=maxf(maximum,error);total+=error
 return {"pixels_above_1_byte":changed,"max_channel_error":maximum,"mean_channel_error":total/(a.get_width()*a.get_height())}
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);stage._process(0)
 var scenery=stage.scenery
 assert(scenery.contact_lod_enabled and scenery.bounded_ground)
 scenery.contact_lod_enabled=false;scenery.last_cull_pose=Vector4(INF,INF,INF,INF);scenery.update_view(stage.bridge)
 var fine:Image=await shot();var control:Image=await shot()
 scenery.contact_lod_enabled=true;scenery.last_cull_pose=Vector4(INF,INF,INF,INF);scenery.update_view(stage.bridge)
 var coarse:Image=await shot();var switched:=0
 for chunk in scenery.chunks:
  if chunk.get_meta("contact_is_far",false):switched+=1
 assert(switched>0)
 fine.save_png("res://../tempassets/work/contact-lod-fine.png");coarse.save_png("res://../tempassets/work/contact-lod-far.png")
 var result:Dictionary={"control":difference(fine,control),"lod":difference(control,coarse),"switched_batches":switched}
 FileAccess.open("res://../tempassets/work/contact-lod-image-difference.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("CONTACT_LOD_IMAGE_COMPARISON ",JSON.stringify(result))
 if "--matrix" in OS.get_cmdline_user_args():
  var original:Vector2=stage.bridge.camera_world;var original_heading:float=stage.bridge.heading
  var matrix:Array=[]
  for pose in [Vector3(0,200,0),Vector3(0,400,0),Vector3(0,600,0),Vector3(0,400,-.5),Vector3(0,400,.5),Vector3(0,200,0)]:
   stage.bridge.camera_world=original+Vector2(pose.x,pose.y);stage.bridge.heading=original_heading+pose.z
   preload("res://scripts/world3d/projection.gd").configure(stage.camera,stage.bridge.view_size,stage.bridge.camera_world,stage.bridge.heading,stage.frame.height,stage.frame.lens,stage.frame.horizon)
   var previous_states:Dictionary={}
   for chunk in scenery.chunks:
    if chunk.has_meta("contact_is_far"):previous_states[chunk]=chunk.get_meta("contact_is_far")
   scenery.contact_lod_enabled=false;scenery.last_cull_pose=Vector4(INF,INF,INF,INF);scenery.update_view(stage.bridge)
   var full:Image=await shot()
   for chunk in previous_states:
    chunk.set_meta("contact_is_far",previous_states[chunk])
    chunk.multimesh.mesh=chunk.get_meta("contact_far" if previous_states[chunk] else "contact_fine")
   scenery.contact_lod_enabled=true;scenery.last_cull_pose=Vector4(INF,INF,INF,INF);scenery.update_view(stage.bridge)
   var reduced:Image=await shot()
   var compared:=difference(full,reduced);compared.pose=[pose.x,pose.y,pose.z];matrix.append(compared)
   if float(compared.max_channel_error)>.02:
    full.save_png("res://../tempassets/work/contact-lod-matrix-%d-fine.png"%matrix.size())
    reduced.save_png("res://../tempassets/work/contact-lod-matrix-%d-coarse.png"%matrix.size())
  FileAccess.open("res://../tempassets/work/contact-lod-matrix.json",FileAccess.WRITE).store_string(JSON.stringify(matrix,"  "))
  print("CONTACT_LOD_MATRIX ",JSON.stringify(matrix))
 quit()
