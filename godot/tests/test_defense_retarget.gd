extends SceneTree
func _initialize():call_deferred("run")
func run():
 var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_3d_motions.json"))
 var custom=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
 var worst:=0.0
 for file in ["composer.glb","joseph-summer.glb","geisha-thirteen.glb","isabella.glb","composer-george.glb"]:
  var actor=load("res://scripts/battle/enemy_actor.gd").new();actor.model_scene=load("res://assets/characters3d/"+file);root.add_child(actor)
  var optimized=load("res://scripts/defense/defense_retarget.gd").new()
  for key in ["walk","run","attack","death","crawl"]:
   var clip=catalog.clips.get(key,{})
   if key=="crawl":
    for c in custom.clips:
     if c.id=="3_Obstacle_Climb_Loop":clip=c;break
   var names=custom.bones if key=="crawl" else catalog.bones
   actor.retarget.configure(actor.rig,names);actor.retarget.load_clip(clip)
   optimized.configure(actor.rig,names);optimized.load_clip(clip)
   for fraction in [0.0,.137,.42,.79,.999]:
    var time:float=fraction*(clip.frames-1)/clip.fps
    actor.retarget.apply(time)
    var rotations:Array=[];var positions:Array=[]
    for i in actor.rig.get_bone_count():rotations.append(actor.rig.get_bone_pose_rotation(i));positions.append(actor.rig.get_bone_pose_position(i))
    optimized.apply(time)
    for i in actor.rig.get_bone_count():
     var error:float=1-absf(rotations[i].dot(actor.rig.get_bone_pose_rotation(i)))
     worst=maxf(worst,error)
     assert(error<.00001,"Rotation parity")
     assert(positions[i].distance_to(actor.rig.get_bone_pose_position(i))<.00001,"Position parity")
  actor.free()
 print("DEFENSE_RETARGET_PARITY_PASS max quaternion error ",worst)
 quit()
