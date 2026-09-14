extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.start_battle()
 while app.phase!="battle":await process_frame
 app.set_process(false)
 app.cast_zone();assert(app.sim.areas.zones.size()==1)
 var center:Vector3=app.sim.areas.zones[0].center
 assert(center.distance_to(app.world_point(Vector3(0,0,-3)))<.001)
 # Place a test range over one real active monster, keeping normal simulation damage dispatch.
 var enemy:Dictionary=app.sim.enemies[0];enemy.activate_at=0
 app.sim.areas.zones[0].center=app.world_point(enemy.pos)
 app.sim.areas.zones[0].radius=8
 for i in 11:app.sim.step(.05)
 assert(app.sim.areas.hits>0,"Fixed simulation must apply periodic damage to real monsters")
 app.sim.areas.zones[0].center=center;app.sim.areas.zones[0].radius=2.8
 app._process(0)
 assert(app.area_view.multimesh.visible_instance_count==1)
 if "--capture" in OS.get_cmdline_user_args():
  for i in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/world3d-area-test.png")
 app.reset_battle();app._process(0)
 assert(app.sim.areas.zones.is_empty() and app.area_view.multimesh.visible_instance_count==0,"Restart clears simulation and visual zone")
 print("WORLD3D_AREA_INTEGRATION_PASS world position, fixed simulation damage, marker, restart cleanup")
 quit()
