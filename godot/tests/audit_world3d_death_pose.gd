extends SceneTree
func _initialize():call_deferred("run")
func run():
 var actor=preload("res://scripts/world3d/actor.gd").new();root.add_child(actor)
 actor.setup("isabella.glb")
 for name in ["sk_13_0","sk_13_3","sk_13_20"]:
  var bone:int=actor.rig.find_bone(name);var chain:Array=[]
  while bone>=0:
   chain.append(actor.rig.get_bone_name(bone));bone=actor.rig.get_bone_parent(bone)
  print("CLOTH_CHAIN ",chain)
 actor.play("death")
 var duration:float=(actor.library.clips.death.frames-1)/actor.library.clips.death.fps
 for fraction in [0.0,.25,.5,.75,1.0]:
  actor.retarget.apply(duration*fraction)
  var sample:Dictionary={"fraction":fraction}
  for name in ["全ての親","腰","下半身","頭","足首.L","足首.R"]:
   var bone:int=actor.rig.find_bone(name)
   if bone<0:continue
   var p:Vector3=actor.body.transform*actor.rig.get_bone_global_pose(bone).origin
   sample[name]=[p.x,p.y,p.z]
  print("DEATH_POSE ",JSON.stringify(sample))
 var unit:Dictionary={"hp":0,"changed":0.0,"entry_phase":"advance","entry":"walk","state":"death","running":false,"body_scale":1.0}
 actor.play("death");actor.animate_unit(unit,duration+.1,.05,Vector3.ZERO)
 assert(actor.death_pose_finished and actor.dead)
 var poses:Array=[]
 for i in actor.rig.get_bone_count():poses.append(actor.rig.get_bone_pose(i))
 for frame in 120:actor.animate_unit(unit,duration+.1+frame*.05,.05,Vector3.ZERO)
 for i in poses.size():assert(poses[i]==actor.rig.get_bone_pose(i),"Frozen corpse pose changed")
 actor.trigger("revive");assert(not actor.death_pose_finished)
 unit.hp=10;unit.state="idle"
 actor.animate_unit(unit,10,.05,Vector3.ZERO)
 assert(actor.clip=="idle" and not actor.death_pose_finished and not actor.dead)
 unit.hp=0;unit.changed=10
 actor.animate_unit(unit,10.1,.05,Vector3.ZERO)
 assert(actor.clip=="death" and not actor.death_pose_finished,"Second death must play from the beginning")
 assert(actor.dead)
 # Simulation-driven recovery must clear the presentation flag even when no
 # separate UI revive trigger is sent to this pooled enemy actor.
 unit.hp=10;unit.state="idle"
 actor.animate_unit(unit,10.2,.05,Vector3.ZERO)
 assert(not actor.dead and actor.clip=="idle")
 print("WORLD3D_CORPSE_POSE_CACHE_PASS persistent final pose, revival and second death")
 quit()
