extends SceneTree
func _initialize():call_deferred("run")
func run():
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var s=shell.stage;s.set_process(false);s.begin_tactical();s.sim.next_spawn=INF
 for i in 60:
  s.sim.spawn_enemy();var e:Dictionary=s.sim.enemies.back();e.activate_at=0;e.born=-1;e.entry="road";e.entry_phase="advance";e.pos=Vector3(0,0,-3);e.previous_pos=e.pos
  if i<59:s.sim.hurt(e,100000)
 s._process(0)
 var missing:Array=[]
 for e in s.sim.enemies:
  if not s.pool_ids.has(e.id):missing.append(e.id)
 assert(missing.is_empty(),"All lifetime spawns, including corpses, need a model")
 assert(s.pool_ids[59].actor.visible and s.sim.enemies[59].hp==1200)
 for e in s.sim.enemies:assert(s.pool_ids[e.id].kind==e.type)
 s.sim.hurt(s.sim.enemies[59],100000);s.sim.step(.05)
 assert(s.sim.status=="victory" and s.sim.killed==60 and s.sim.active_count()==0)
 s.begin_tactical();assert(s.sim.spawned==0 and s.pool_ids.is_empty())
 for slot in s.enemy_pool:assert(slot.id==-1 and not slot.actor.visible)
 print("TACTICAL_TAIL_PASS 60 lifetime actors including corpses, visible final boss, final death victory and clean restart")
 quit()
