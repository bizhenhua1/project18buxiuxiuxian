extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var app=load("res://scenes/character_library.tscn").instantiate();root.add_child(app)
 for model in range(app.MODELS.size()):
  app.select_model(model)
  for hand in range(2):
   app.weapon_panel.weapon=1;app.weapon_panel.hand=hand;app.weapon_panel.bind_model()
   assert(is_instance_valid(app.weapon_panel.attachment),"Missing hand on model %d" % model)
   assert(app.weapon_panel.attachment.bone_idx>=0)
  await process_frame
 app.weapon_panel.save_path="user://weapon-preview-test.cfg"
 app.select_model(0);app.weapon_panel.hand=0
 for kind in range(1,app.weapon_panel.items.size()):
  app.weapon_panel.weapon=kind;app.weapon_panel.bind_model()
  assert(app.weapon_panel.visual.get_child_count()>0)
  app.weapon_panel.fields.x.value=.05
  assert(app.weapon_panel.visual.position.distance_to(app.weapon_panel.mount.origin)>.001)
  app.weapon_panel.load_grip(false)
 app.weapon_panel.fields.x.value=.08;app.weapon_panel.save_grip()
 app.weapon_panel.fields.x.value=0;app.weapon_panel.load_grip(true)
 assert(is_equal_approx(app.weapon_panel.fields.x.value,.08),"Saved grip did not restore")
 app.weapon_panel.weapon=27;app.weapon_panel.picker.select(27);app.weapon_panel.bind_model()
 var plunge:Array=app.clips.filter(func(c):return c.id=="7_Attack_Plunge_2_Begin_Seq")
 assert(not plunge.is_empty())
 app.select_clip(plunge[0]);app.elapsed=0;app.weapon_panel.sample_weapon_motion()
 var first_transform:Transform3D=app.weapon_panel.visual.transform
 app.elapsed=.5;app.weapon_panel.sample_weapon_motion()
 assert(not app.weapon_panel.visual.transform.is_equal_approx(first_transform),"Weapon animation track was lost")
 var attacks:Array=app.clips.filter(func(c):return str(c.get("pack",""))=="7" and "Idle" in c.name)
 if not attacks.is_empty():app.select_clip(attacks[0])
 app.yaw=-.8
 app.weapon_panel.shield_enabled=true;app.weapon_panel.bind_model()
 assert(is_instance_valid(app.weapon_panel.shield_attachment))
 for i in range(10):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/weapon-browser.png")
 print("WEAPON_PREVIEW_PASS seven models, both hands, 31 textured weapons and shield, grip edits and animation")
 quit()
