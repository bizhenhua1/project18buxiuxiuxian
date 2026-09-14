extends SceneTree
const OLD=preload("res://tests/fixtures/defense_retarget_reference.gd")
const NEW=preload("res://scripts/defense/defense_retarget.gd")
func _initialize():call_deferred("run")
func find_rig(node:Node)->Skeleton3D:
 if node is Skeleton3D:return node
 for child in node.get_children():
  var found:=find_rig(child)
  if found:return found
 return null
func run():
 var library:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/enemy_3d_motions.json"))
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
 assert(library.bones==catalog.bones,"Fixture requires the actual actor source skeleton")
 for clip in catalog.clips:
  if clip.id in ["7_Jump_Landing_Seq","5_ARPG_Warrior_Anim_rig_Landing2","7_Getup_Seq","3_Obstacle_Climb_Loop"]:library.clips[clip.id]=clip
 var enemies:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json")).enemies
 var checks:=0;var original_usec:=0;var pruned_usec:=0
 for enemy in enemies:
  var model:PackedScene=load("res://assets/characters3d/"+enemy.model)
  var a:=model.instantiate();var b:=model.instantiate();root.add_child(a);root.add_child(b)
  var rig_a:=find_rig(a);var rig_b:=find_rig(b)
  var old=OLD.new();var current=NEW.new();old.configure(rig_a,library.bones);current.configure(rig_b,library.bones)
  for key in library.clips:
   var clip:Dictionary=library.clips[key];old.load_clip(clip);current.load_clip(clip)
   var duration:float=(clip.frames-1.0)/clip.fps
   for sample in 13:
    var time:float=duration*sample/12.0
    old.apply(time);current.apply(time)
    for bone in rig_a.get_bone_count():
     assert(rig_a.get_bone_global_pose(bone).is_equal_approx(rig_b.get_bone_global_pose(bone)),"Bone changed: "+enemy.model+"/"+key+"/"+rig_a.get_bone_name(bone))
     checks+=1
  for cycle in 4:
   # Alternate timing order to reduce warmup bias; exact same rig/clip/sample times.
   for target in ([old,current] if cycle%2==0 else [current,old]):
    var began:=Time.get_ticks_usec()
    for sample in 500:target.apply(sample*.001)
    var took:=Time.get_ticks_usec()-began
    if target==old:original_usec+=took
    else:pruned_usec+=took
  print("WORLD3D_BONE_COUNTS ",enemy.model," total=",rig_b.get_bone_count()," evaluated=",current.evaluation_bones.size())
  a.free();b.free()
 print("WORLD3D_BONE_PRUNING_PASS global_pose_checks=",checks," original_us=",original_usec," pruned_us=",pruned_usec)
 quit()
