extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var s=shell.stage;s.set_process(false);s.begin_tactical()
 var id:int=s.team_slots[0];var a:Dictionary=s.sim.allies[id];a.next=INF
 s._process(0)
 var yaw_before:float=s.aim_yaw(a)
 var old:Vector3=a.pos;a.pos.x+=8;a.previous_pos=a.pos
 var yaw_after:float=s.aim_yaw(a)
 assert(absf(angle_difference(yaw_before,yaw_after))>.02,"Idle facing must be recomputed from the new position")
 s.sim.spawn_enemy();var e:Dictionary=s.sim.enemies.back();e.pos=a.pos+Vector3(-6,0,-5);e.previous_pos=e.pos;e.activate_at=0;e.entry_phase="advance"
 a.range=20;a.aim_id=e.id
 var direction:Vector3=s.world_point(e.pos)-s.world_point(a.pos)
 assert(absf(angle_difference(s.aim_yaw(a),atan2(direction.x,direction.z)))<.001,"Attack aim must use target world position")
 s.sync_ally_facing(0)
 assert(absf(angle_difference(s.team[0].rotation.y,s.aim_yaw(a)))<.001)
 e.resolved=true
 assert(absf(angle_difference(s.aim_yaw(a),yaw_after))<.001,"A lost target must restore distant idle facing")
 a.pos=old;a.previous_pos=old
 print("TACTICAL_FACING_PASS idle convergence after movement, target facing and target loss")
 quit()
