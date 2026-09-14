extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 app.start_travel()
 for i in 30:app._process(.02)
 var distance:float=app.distance;var target:float=app.next_event
 var camera:Transform3D=app.camera.transform;var actor:Transform3D=app.team[0].transform
 app.start_travel();app.reset_battle()
 assert(app.phase=="travel" and app.distance==distance and app.next_event==target)
 assert(app.camera.transform==camera and app.team[0].transform==actor)
 assert(app.action_buttons["重新整备"].disabled)
 for i in 400:
  if app.phase=="event":break
  app._process(.02)
 assert(app.phase=="event")
 app.start_battle()
 for i in 200:
  app._process(.02)
  if app.phase=="battle":break
 assert(app.phase=="battle")
 # A dead ally remains at a displaced combat location until revival/reset.
 for i in app.team.size():
  app.team[i].position+=Vector3(.2,0,-.6)
  app.team[i].trigger("death")
 var positions:Array=[]
 for member in app.team:positions.append(member.position)
 camera=app.camera.transform
 var lens:Projection=app.camera.get_camera_projection()
 app.reset_battle();app.reset_battle()
 for i in app.team.size():
  assert(not app.team[i].dead and app.team[i].position==positions[i])
 app.start_battle()
 for tick in 200:
  app._process(.02)
  assert(app.camera.transform==camera,"Restart camera transform must remain fixed")
  assert(app.camera.get_camera_projection()==lens,"Restart lens must remain fixed")
  for i in app.team.size():
   assert(app.team[i].position.distance_to(positions[i])<=TravelPace.RUN/20*.02+.0001,"No revival teleport")
   positions[i]=app.team[i].position
  if app.phase=="battle":break
 assert(app.phase=="battle")
 for i in app.team.size():assert(app.team[i].position.distance_to(app.slot_position(i))<.03)
 print("WORLD3D_RESTART_FLOW_PASS repeated travel/reset guards, in-place revival, bounded return and fixed camera/lens")
 quit()
