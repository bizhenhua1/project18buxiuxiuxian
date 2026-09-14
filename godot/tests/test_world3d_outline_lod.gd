extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 var group=app.outline_lod.actors[0];var actor=group.actor
 assert(not group.links.is_empty())
 app.actor_atmosphere.set_enabled(true)
 actor.global_position=app.camera.global_transform*Vector3(0,0,-90)
 app.outline_lod.sync(app.camera,Vector2(root.size),true)
 var skipped:=0
 for link in group.links:
  if link.current_width==0:
   skipped+=1
   assert(link.source.next_pass==link.outline.next_pass and link.source.next_pass!=null,"Far outline removal preserves atmosphere")
 assert(skipped>0)
 actor.hide();actor.global_position=app.camera.global_transform*Vector3(0,0,-.5);actor.show()
 app.outline_lod.sync(app.camera,Vector2(root.size),true)
 for link in group.links:
  assert(is_equal_approx(link.current_width,link.width),"Near actor restores original width")
  assert(link.source.next_pass==link.outline)
 app.actor_atmosphere.set_enabled(false)
 actor.global_position=app.camera.global_transform*Vector3(0,0,-90)
 app.outline_lod.sync(app.camera,Vector2(root.size),true)
 for link in group.links:
  if link.current_width==0:assert(link.source.next_pass==null)
 app.outline_lod.sync(app.camera,Vector2(root.size),true,false)
 for link in group.links:assert(link.source.next_pass==link.outline and link.current_width==link.width)
 print("WORLD3D_OUTLINE_LOD_PASS far skip, atmosphere tail, near restoration, pooled reentry and disable")
 quit()
