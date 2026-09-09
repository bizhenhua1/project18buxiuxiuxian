extends SceneTree
func _initialize() -> void:call_deferred("run")
func find_skeleton(node:Node) -> Skeleton3D:
 if node is Skeleton3D:return node
 for c in node.get_children():
  var s:=find_skeleton(c)
  if s:return s
 return null
func run() -> void:
 var actor=load("res://scripts/battle/seer_actor.gd").new();root.add_child(actor)
 var skeleton:=find_skeleton(actor.body)
 var report:={}
 for clip in ["EM_Walk","EM_Run"]:
  var frames:=[];actor.player.play(clip,0)
  var duration:float=actor.player.get_animation(clip).length
  for i in range(121):
   actor.player.seek(duration*i/120.0,true);actor.player.advance(0)
   var sample:={"t":duration*i/120.0}
   for name in ["足首D.L","足首D.R","頭","全ての親"]:
    var b:=skeleton.find_bone(name)
    if b<0:continue
    var p:=skeleton.get_bone_global_pose(b).origin
    sample[name]=[p.x,p.y,p.z]
   frames.append(sample)
  report[clip]=frames
 var f:=FileAccess.open("res://../art/3d/seer/gait-raw.json",FileAccess.WRITE);f.store_string(JSON.stringify(report))
 print("GAIT_SAMPLED");quit()
