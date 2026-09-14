extends SceneTree
func _initialize():
 set_meta("world3d_ordinary_vfx_budget",true)
 call_deferred("run")
func run():
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
 while not app.stage or not app.stage.ready_stage:await process_frame
 app.stage.set_process(false)
 var view=app.stage.projectile_view
 for i in 80:assert(view.emit_effect("impact",Vector3(i*.01,0,0),true)!=null)
 assert(view.reservations.reduced>0)
 var reserved:=0
 for fx in view.pools.impact:
  if not fx.visible:continue
  for layer in fx.layers:
   reserved+=int(layer.instance_particle_limit)
   for i in 40:fx.spawn(layer,fx.global_position)
   assert(layer.particles.size()<=int(layer.instance_particle_limit))
 assert(reserved==view.reservations.reserved)
 for i in 120:view.advance(.05)
 assert(view.reservations.reserved==0,"Completed tails release all reservations")
 assert(view.emit_effect("impact",Vector3.ZERO,true)!=null)
 assert(view.reservations.reserved==32,"Reused pool item gets full budget again")
 view.clear()
 assert(view.reservations.reserved==0)
 print("WORLD3D_VFX_GLOBAL_BUDGET_PASS actual spawn caps, natural tail release, reuse and clear")
 quit()
