extends SceneTree
const PALETTE=preload("res://scripts/world3d/skin_palette.gd")
func _initialize():call_deferred("run")
func collect(node:Node,out:Array):
 if node is MeshInstance3D and node.skin!=null:out.append({"node":node,"mesh":node.mesh,"skin":node.skin,"compact":PALETTE.compact(node.mesh,node.skin)})
 for child in node.get_children():collect(child,out)
func snapshot()->Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 root.size=Vector2i(640,480)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-30,-25,0);scene.add_child(light)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("18212b");scene.add_child(environment)
 var count:=0;var failures:=0;var maximum:=0;var shadow_meshes:=0
 var specs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json")).enemies
 for spec in specs:
  var actor=load("res://scripts/world3d/actor.gd").new();scene.add_child(actor);actor.setup(spec.model)
  var meshes:Array=[];collect(actor.body,meshes)
  for entry in meshes:
   assert(not entry.compact.has("skipped"))
   if entry.mesh.shadow_mesh!=null:shadow_meshes+=1
  for clip in ["walk","attack","death"]:
   actor.play(clip)
   var duration:float=(actor.library.clips[clip].frames-1)/actor.library.clips[clip].fps
   actor.retarget.apply(duration*.6)
   for distance in [3.5,12.0]:
    camera.position=Vector3(0,1,distance);camera.look_at(Vector3(0,.85,0))
    for entry in meshes:entry.node.mesh=entry.mesh;entry.node.skin=entry.skin
    var before:=await snapshot()
    for entry in meshes:entry.node.mesh=entry.compact.mesh;entry.node.skin=entry.compact.skin
    var after:=await snapshot()
    var a:=before.get_data();var b:=after.get_data();var changed:=0;var peak:=0
    var occupied:=0
    for pixel in range(0,a.size(),4):
     if absi(int(a[pixel])-int(a[0]))+absi(int(a[pixel+1])-int(a[1]))+absi(int(a[pixel+2])-int(a[2]))>10:occupied+=1
    assert(occupied>100,"Both images must contain a visible animated model")
    if spec.model=="composer.glb" and clip=="walk" and distance==3.5:before.save_png("res://../tempassets/work/skin-palette-gpu-reference.png");after.save_png("res://../tempassets/work/skin-palette-gpu-compacted.png")
    for i in a.size():
     var delta:=absi(int(a[i])-int(b[i]));peak=maxi(peak,delta)
     if delta>1:changed+=1
    maximum=maxi(maximum,peak);count+=1
    if changed>0:
     failures+=1
     var prefix:String="res://../tempassets/work/skin-"+spec.model.get_basename()+"-"+clip+"-"+str(distance)
     before.save_png(prefix+"-before.png");after.save_png(prefix+"-after.png")
     print("PALETTE_GPU_DIFFERENCE ",spec.model," ",clip," distance=",distance," changed bytes=",changed," max=",peak)
  actor.queue_free();await process_frame
  print("PALETTE_GPU_MODEL_DONE ",spec.model)
 print("WORLD3D_SKIN_PALETTE_GPU comparisons=",count," failures=",failures," max_byte_delta=",maximum," source_shadow_meshes=",shadow_meshes)
 quit(1 if failures else 0)

