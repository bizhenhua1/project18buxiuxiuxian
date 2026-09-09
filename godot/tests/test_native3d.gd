extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/native3d_forest.tscn").instantiate();root.add_child(app)
 await process_frame;app.set_process(false)
 for i in range(30):app._process(.025);await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/native3d-travel.png")
 for count in [4,7,10]:
  assert(app.composition.player_slots(count,false).size()==count)
  assert(app.composition.enemy_slots(count).size()==count)
 assert(app.composition.player_slots(8,false,3).size()==8)
 assert(app.camera is Camera3D)
 assert(app.party[0].get_world_3d()==app.camera.get_world_3d())
 app.begin_event(false)
 for i in app.paths:
  var p:Dictionary=app.paths[i]
  assert((p.end-p.start).dot(app.battle_forward)>.5,"Entry must advance in depth")
 for i in range(260):
  var previous:Vector3=app.camera.position
  app._process(.025);await process_frame
  assert(app.camera.position.distance_to(previous)<.065,"Entry camera exceeded braking speed")
  assert(not app.camera.is_position_behind(app.party[0].position+Vector3.UP),"Camera passed protagonist")
  if app.phase=="battle":break
 assert(app.phase=="battle")
 assert(app.party.size()==7)
 assert(is_equal_approx(app.camera.fov,57.0))
 assert(absf(app.camera.rotation_degrees.x+17)<.05)
 assert(is_equal_approx(app.party[2].scale.x,.5))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/native3d-battle.png")
 app.finish("defeat")
 var camera:Transform3D=app.camera.transform
 var point:Vector3=app.party[0].position
 app.revive()
 for i in range(30):app._process(.025);await process_frame
 assert(app.party[0].position.distance_to(point)<.001)
 assert(app.camera.position.distance_to(camera.origin)<.001)
 var prop_positions:=[app.party[2].position,app.party[3].position]
 app.leave()
 for i in range(30):
  app._process(.025)
  for j in range(2):assert(app.party[j+2].position.distance_to(prop_positions[j])<.0001,"Prop must fade in place")
 assert(app.party[2].modulate.a<.001 and app.party[3].modulate.a<.001)
 assert(app.party[1].opacity<.001 and not app.party[1].visible)
 assert(app.party[0].visible)
 for i in app.paths:assert((app.paths[i].end-app.paths[i].start).dot(app.battle_forward)>0,"Departure must move forward")
 for i in range(260):
  app._process(.025)
  if app.phase=="travel":break
 assert(app.phase=="travel")
 app.phase="fork3";app.choose(-1)
 assert(app.route.get_point_position(app.route.point_count-1).x<0)
 print("NATIVE3D_PASS shared world, forward fan entry/exit, stationary revival, curved branch")
 quit()
