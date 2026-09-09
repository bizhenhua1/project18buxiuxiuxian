extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,1000)
 var app=load("res://scenes/character_3d_lab.tscn").instantiate();root.add_child(app)
 var expected=["Idle","Walk","Run","Attack","Hit","Defeat"]
 for clip in expected:
  assert(app.player.has_animation(clip),"Missing animation "+clip)
  var animation:Animation=app.player.get_animation(clip)
  print(clip," duration=",animation.length," tracks=",animation.get_track_count())
  assert(animation.length>.5 and animation.get_track_count()>=3)
 var skeleton=app.model.find_children("*","Skeleton3D",true,false)[0]
 assert(skeleton.get_bone_count()==20)
 for clip in expected:
  app.play_clip(clip)
  app.player.play(clip,0)
  app.player.advance(0)
  app.player.seek(0,true)
  var initial=[]
  for bone in range(skeleton.get_bone_count()):initial.append(skeleton.get_bone_pose(bone))
  app.player.seek(app.player.get_animation(clip).length*(.9 if clip=="Defeat" else .4),true)
  app.player.advance(0)
  var motion:=0.0
  for bone in range(skeleton.get_bone_count()):
   var pose:Transform3D=skeleton.get_bone_pose(bone)
   motion+=pose.origin.distance_to(initial[bone].origin)
   motion+=pose.basis.get_rotation_quaternion().angle_to(initial[bone].basis.get_rotation_quaternion())
  assert(motion>.01,"Static skeletal clip: "+clip)
  app.player.pause()
  for i in range(4):await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../art/3d/lantern-investigator/game-%s.png"%clip.to_lower())
 print("CHARACTER_3D_PASS: six playable skeletal clips, twenty bones, six rendered poses")
 quit()
