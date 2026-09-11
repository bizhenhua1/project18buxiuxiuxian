extends SceneTree
func _initialize():call_deferred("run")
func signature(app)->Array:
 var meshes:Array=[];app.FIT.meshes(app.model,meshes)
 var counts:Array=[]
 for mesh in meshes:
  for surface in range(mesh.mesh.get_surface_count()):
   var heights:PackedVector2Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_TEX_UV2]
   var converted:=0
   for value in heights:
    if value.x<.5:converted+=1
   counts.append([heights.size(),converted])
 return counts
func run():
 root.size=Vector2i(1600,1000)
 var app=load("res://scenes/character_transformation_editor.tscn").instantiate();root.add_child(app)
 app.select_model(4);app.playing=false;app.progress=.5;app.mode=1;app.update_effect()
 var original:=signature(app)
 for clip in app.clips:
  if clip.id=="4_Anim_ARPGSamurai_Death":app.select_clip(clip);break
 app.playing=false
 var heights:Array=[]
 for t in [0.0,.3,.65,.9]:
  app.elapsed=t;app.retarget.apply(t)
  heights.append((app.rig.global_transform*app.rig.get_bone_global_pose(app.rig.find_bone("頭")).origin).y)
  assert(signature(app)==original)
  assert(app.progress==.5)
  await process_frame
  await RenderingServer.frame_post_draw
 app.viewport.get_texture().get_image().save_png("F:/GitHub/project18buxiuxiuxian/tempassets/work/transformation-rest-death.png")
 assert(absf(heights[0]-heights[-1])>.3)
 app.model.position.y=-2
 assert(signature(app)==original)
 print("REST_HEIGHT_PASS invariant membership at 50 percent during lowered pose and root translation; head heights=",heights)
 quit()
