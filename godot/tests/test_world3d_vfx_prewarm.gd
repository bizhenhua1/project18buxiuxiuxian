extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
 while not app.stage or not app.stage.ready_stage:await process_frame
 app.stage.set_process(false)
 var view=app.stage.projectile_view
 var states:Dictionary={};var child_count:int=view.get_child_count()
 for pool in view.pools.values():
  for fx in pool:states[fx]=[fx.rng.state,fx.age,fx.stopped,fx.visible,fx.particle_allocations]
 await view.prewarm()
 assert(view.get_child_count()==child_count,"Offscreen viewport must be removed")
 for fx in states:
  assert(states[fx]==[fx.rng.state,fx.age,fx.stopped,fx.visible,fx.particle_allocations],"Prewarm must not advance gameplay emitters")
  for layer in fx.layers:assert(layer.particles.is_empty())
 print("WORLD3D_VFX_PREWARM_PASS pools unchanged and temporary viewport removed; ms=",view.prewarm_usec/1000.0)
 quit()
