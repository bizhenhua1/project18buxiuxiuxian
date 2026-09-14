extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 app.start_travel()
 for i in 400:
  app._process(.02)
  if app.phase=="event":break
 assert(app.phase=="event")
 var event_frame:Dictionary=app.frame.duplicate()
 # Force the shortest possible entry, isolating the original truncation bug.
 app.team[0].position=app.slot_position(0)
 app.start_battle();app._process(.01)
 assert(app.phase=="battle")
 assert(app.battle_camera_clock<app.BATTLE_CAMERA_SECONDS)
 assert(not is_equal_approx(app.frame.height,app.composition.frames.battle.height))
 var previous:Dictionary=app.frame.duplicate()
 for i in 80:
  app._process(.01)
  for key in ["height","lens","horizon","forward","lateral"]:
   var start:float=event_frame.get(key,0);var finish:float=app.composition.frames.battle.get(key,0)
   assert(float(app.frame.get(key,0))>=minf(start,finish)-.0001)
   assert(float(app.frame.get(key,0))<=maxf(start,finish)+.0001)
   assert(absf(float(app.frame.get(key,0))-float(previous.get(key,0)))<=absf(finish-start)*.03+.0001,"No transition boundary jump")
  previous=app.frame.duplicate()
 for key in ["height","lens","horizon","forward","lateral","yaw"]:
  assert(is_equal_approx(app.frame.get(key,0),app.composition.frames.battle.get(key,0)))
 var camera:Transform3D=app.camera.transform;var projection:Projection=app.camera.get_camera_projection()
 app.reset_battle();app.start_battle()
 for i in 80:app._process(.01)
 assert(app.camera.transform==camera and app.camera.get_camera_projection()==projection)
 print("WORLD3D_CAMERA_COMPLETION_PASS immediate actor arrival does not truncate camera; bounded interpolation, exact saved frame, restart unchanged")
 quit()
