extends SceneTree
func _initialize():call_deferred("run")
func run():
 var specs:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/defense_sample.json")).enemies
 var count:=0
 for spec in specs:
  var actor=preload("res://scripts/world3d/actor.gd").new();root.add_child(actor);actor.setup(spec.model)
  actor.play("death")
  var duration:float=(actor.library.clips.death.frames-1)/actor.library.clips.death.fps
  assert(duration>.5,"A landing-only fragment is not a complete death")
  var hip:int=actor.rig.find_bone("下半身");var head:int=actor.rig.find_bone("頭")
  var rest_hip:float=actor.rig.get_bone_global_rest(hip).origin.y
  var rest_head:float=actor.rig.get_bone_global_rest(head).origin.y
  actor.retarget.apply(0)
  assert(actor.rig.get_bone_global_pose(hip).origin.y/rest_hip>.75,"Death starts with a collapsed pelvis: "+spec.model)
  assert(actor.rig.get_bone_global_pose(head).origin.y/rest_head>.75,"Death starts already lying down: "+spec.model)
  actor.retarget.apply(duration)
  assert(actor.rig.get_bone_global_pose(hip).origin.y/rest_hip<.5,"Death must finish down: "+spec.model)
  assert(actor.rig.get_bone_global_pose(head).origin.y/rest_head<.55,"Death must finish down: "+spec.model)
  count+=1;actor.queue_free();await process_frame
 print("WORLD3D_DEATH_PROFILES_PASS ",count," models stand at start and finish lying down")
 quit()
