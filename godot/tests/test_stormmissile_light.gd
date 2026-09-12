extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1600,960)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../tempassets/work/stormmissile"))
 var app=load("res://scenes/vfx_preview.tscn").instantiate()
 app.light_profile_path="res://../tempassets/work/stormmissile/test-profiles.json"
 root.add_child(app)
 app.set_process(false)
 for i in 8:await process_frame
 var candidates:Array=app.projectile_entries().filter(func(e):return e.name.begins_with("StormMissile"))
 assert(not candidates.is_empty())
 app.select_entry(candidates[0]);app.shot_speed=3
 app.load_light_profile({})
 for i in 600:
  app._process(1.0/60)
  if app.action_phase=="flight" and app.flight_fraction>=.5:break
 assert(app.missile_light_bound,"Moving light not attached")
 var first:Vector3=app.missile_light_position
 app._process(1.0/60)
 assert(first.distance_to(app.missile_light_position)>.001,"Light did not follow missile")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../tempassets/work/stormmissile"))
 await capture("light-on")
 app.missile_light_enabled=false;app.update_missile_light(0)
 assert(not app.missile_light_bound)
 await capture("light-off")
 app.missile_light_enabled=true
 for i in 600:
  app._process(1.0/60)
  if app.impact_sent:break
 assert(app.impact_sent and app.missile_light_bound,"Impact light missing")
 var hit_point:Vector3=app.missile_light_position
 for i in 3:app._process(1.0/60)
 var light:Dictionary=app.game_preview.app.arena.scenery.renderer.combat_lights[0]
 assert(light.energy>app.missile_light_energy,"Explosion did not brighten")
 assert(light.radius>app.missile_light_radius,"Explosion did not expand")
 assert(hit_point.distance_to(app.missile_light_position)<.001,"Impact light moved")
 await capture("explosion-light")
 for i in 15:app._process(1.0/60)
 assert(app.missile_light_bound,"Explosion light ended with projectile")
 assert(app.game_preview.app.arena.scenery.renderer.combat_lights[0].energy<light.energy,"Explosion did not fade")
 for i in 600:
  app._process(1.0/60)
  if app.impact_sent and app.missile_light_tail==0:break
 assert(app.impact_sent and not app.missile_light_bound,"Light survives impact")
 app.stop_action();assert(not app.missile_light_bound)
 app.missile_burst_energy=1.4;app.missile_burst_color=Color("ffab72");app.save_light_profile()
 var stored=JSON.parse_string(FileAccess.get_file_as_string(app.light_profile_path))
 assert(stored[str(candidates[0].file)].missile_burst_energy==1.4)
 var other=app.projectile_entries().filter(func(e):return e.file!=candidates[0].file)[0]
 app.select_entry(other,false);assert(not app.missile_light_enabled,"Profile leaked to another projectile")
 app.select_entry(candidates[0],false)
 assert(app.missile_burst_energy==1.4 and app.missile_burst_color==Color("ffab72"),"Saved profile not restored")
 print("STORMMISSILE_LIGHT_PASS follow toggle burst expansion fixed-position fade cleanup")
 quit()
func capture(label:String)->void:
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/stormmissile/"+label+".png")
