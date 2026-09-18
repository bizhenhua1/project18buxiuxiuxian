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
 print("TAIL_VISUAL_MISSING=",missing," last_visible=",s.pool_ids.has(59)," last_hp=",s.sim.enemies[59].hp)
 quit()
