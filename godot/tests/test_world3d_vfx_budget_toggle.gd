extends SceneTree
func _initialize():call_deferred("run")
func run():
 set_meta("world3d_theme","forest");set_meta("world3d_ordinary_vfx_budget",false)
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app);current_scene=app
 while not app.stage or not app.stage.ready_stage:await process_frame
 for enabled in [true,false]:
  var previous_id:int=current_scene.get_instance_id()
  current_scene.stage.vfx_budget_picker.item_selected.emit(1 if enabled else 0)
  var ready:=false
  for frame in 900:
   await process_frame
   if current_scene!=null and current_scene.get_instance_id()!=previous_id and current_scene.stage and current_scene.stage.ready_stage:ready=true;break
  if not ready:push_error("VFX budget selection failed to rebuild scene");quit(1);return
  var stage=current_scene.stage
  assert(stage.theme_key=="forest" and stage.portrait_mode and stage.atmosphere_mode)
  assert(stage.phase=="prepare" and stage.projectile_view.ordinary_budget==enabled)
  assert(stage.vfx_budget_picker.selected==(1 if enabled else 0))
  var lights=stage.projectile_view.lighting
  assert(lights.shared_flights==enabled,"Budget selector must switch lighting policy too")
  if enabled:
   var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world3d_vfx_budgets.json")).lighting
   assert(lights.burst_limit==int(config.burst_limit))
   assert(is_equal_approx(lights.burst_merge_distance,float(config.burst_merge_distance)))
   assert(is_equal_approx(lights.burst_merge_window,float(config.burst_merge_window)))
  lights.settings.missile_burst_enabled=true
  for i in 100:lights.impact(Vector3.ZERO)
  assert(lights.bursts.size()==(1 if enabled else 100))
  stage.projectile_view.clear()
  assert(lights.bursts.is_empty() and lights.flight_groups.is_empty(),"Restart must release lighting records")
  var missile=stage.projectile_view.pools.missile[0]
  assert(missile.layers[0].data.has("runtime_particle_limit")==enabled,"Visual spec must match selected tier")
 print("WORLD3D_VFX_BUDGET_TOGGLE_PASS both directions, actual pools, forest and framing retained")
 quit()
