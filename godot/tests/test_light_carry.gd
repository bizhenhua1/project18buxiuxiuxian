extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1500,1000)
 var app=load("res://scenes/character_library.tscn").instantiate();root.add_child(app)
 for i in 5:await process_frame
 for model in [0,3]:
  app.select_model(model)
  for mode in [1,2]:
   app.carry_panel.mode=mode;app.carry_panel.picker.select(mode);app.carry_panel.rebuild();app.carry_panel.choose_motion()
   for i in 60:await process_frame
   var leg:int=app.rig.find_bone("足.L")
   var before:Quaternion=app.rig.get_bone_pose_rotation(leg)
   app.carry_panel.advance(1.0/60)
   assert(before.is_equal_approx(app.rig.get_bone_pose_rotation(leg)),"Holding pose must preserve walking legs")
   assert(app.carry_panel.prop.global_position.is_finite())
   app.retarget.apply(app.elapsed);app.carry_panel.side=1;app.carry_panel.advance(1.0/60)
   assert(app.carry_panel.prop.global_position.is_finite())
   app.retarget.apply(app.elapsed);app.carry_panel.side=0;app.carry_panel.advance(1.0/60)
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../tempassets/work/carry-%d-%d.png"%[model,mode])
 print("CARRY_PREVIEW_PASS")
 quit()
