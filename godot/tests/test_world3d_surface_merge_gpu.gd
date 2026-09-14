extends SceneTree
func _initialize():call_deferred("run")
func layer(node:Node,value:int):
 if node is GeometryInstance3D:node.layers=value
 for child in node.get_children():layer(child,value)
func snapshot()->Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 root.size=Vector2i(640,480)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true
 var light:=DirectionalLight3D.new();light.layers=3;light.light_cull_mask=3;light.rotation_degrees=Vector3(-30,-25,0);scene.add_child(light)
 var count:=0;var failures:=0;var peak:=0
 for key in ["composer","composer-george","joseph-summer","isabella","gardener-kitty-dada","geisha-thirteen"]:
  var actors:Array=[]
  for variant in 2:
   var actor=load("res://scripts/world3d/actor.gd").new();actor.merge_surfaces_enabled=variant==1;scene.add_child(actor);actor.setup(key+".glb");layer(actor,1<<variant);actors.append(actor)
  for clip in ["walk","attack","death"]:
   for actor in actors:
    actor.play(clip);actor.retarget.apply((actor.library.clips[clip].frames-1)/actor.library.clips[clip].fps*.6)
   for distance in [3.5,12.0]:
    camera.position=Vector3(0,1,distance);camera.look_at(Vector3(0,.85,0))
    camera.cull_mask=1;var reference:=await snapshot()
    camera.cull_mask=2;var actual:=await snapshot()
    var a:=reference.get_data();var b:=actual.get_data();var changed:=0;var occupied:=0
    for pixel in range(0,a.size(),4):
     if absi(int(a[pixel])-int(a[0]))+absi(int(a[pixel+1])-int(a[1]))+absi(int(a[pixel+2])-int(a[2]))>10:occupied+=1
    assert(occupied>100,"Animated model must be visible in reference")
    for i in a.size():
     var error:=absi(int(a[i])-int(b[i]));peak=maxi(peak,error)
     if error>2:changed+=1
    count+=1
    if changed>0:
     failures+=1
     var path:String="res://../tempassets/work/surface-merge-"+key+"-"+clip+"-"+str(distance)
     reference.save_png(path+"-reference.png");actual.save_png(path+"-merged.png")
     print("SURFACE_MERGE_DIFFERENCE ",key," ",clip," ",distance," bytes=",changed)
  for actor in actors:actor.free()
 print("WORLD3D_SURFACE_MERGE_GPU comparisons=",count," failures=",failures," max_byte_error=",peak)
 quit(1 if failures else 0)



