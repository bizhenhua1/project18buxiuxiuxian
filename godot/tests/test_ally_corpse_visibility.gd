extends SceneTree
func _initialize():call_deferred("run")
func run():
 var actor=load("res://scripts/battle/equipped_actor.gd").new()
 actor.ally=true;actor.model_key="isabella.glb";actor.model_scene=load("res://assets/characters3d/isabella.glb")
 root.add_child(actor);actor.body.rotation.y=PI
 actor.bind_unit({"uid":11,"hp":0,"maxHp":100})
 actor.trigger("death")
 for i in range(240):actor.advance(.016,"battle",false,1,true)
 var low:=INF;var high:=-INF
 for i in range(actor.rig.get_bone_count()):
  var p:Vector3=actor.rig.global_transform*actor.rig.get_bone_global_pose(i).origin
  low=minf(low,p.y);high=maxf(high,p.y)
 print("DEAD bounds ",low," ",high," clip ",actor.clips.death.id)
 await create_timer(.1).timeout
 await RenderingServer.frame_post_draw
 actor.texture().get_image().save_png("F:/GitHub/project18buxiuxiuxian/tempassets/work/ally-corpse.png")
 assert(actor.dead and actor.body.visible and actor.state=="death")
 quit()
