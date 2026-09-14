extends SceneTree
func _initialize():call_deferred("run")
func run():
 set_meta("world3d_theme","crystal");set_meta("world3d_bounded_ground",false)
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app);current_scene=app
 while not app.stage or not app.stage.ready_stage:await process_frame
 for enabled in [true,false]:
  var previous_id:int=current_scene.get_instance_id()
  current_scene.stage.ground_contact_toggle.button_pressed=enabled
  var ready:=false
  for frame in 600:
   await process_frame
   if current_scene!=null and current_scene.get_instance_id()!=previous_id and current_scene.stage and current_scene.stage.ready_stage:
    ready=true;break
  if not ready:push_error("Contact toggle failed to rebuild the presentation scene");quit(1);return
  var stage=current_scene.stage
  assert(stage.theme_key=="crystal" and stage.portrait_mode and stage.atmosphere_mode)
  assert(stage.scenery.bounded_ground==enabled and stage.ground_contact_toggle.button_pressed==enabled)
  assert(stage.phase=="prepare")
  for material in stage.scenery.by_texture.values():
   assert((material.get_shader_parameter("precise_ground_contact")==true)==enabled)
 print("WORLD3D_CONTACT_TOGGLE_PASS enable/disable actual scene reload; theme and presentation retained")
 quit()
