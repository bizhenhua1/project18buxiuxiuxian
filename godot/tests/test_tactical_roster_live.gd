extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/tactical_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var s=shell.stage;s.set_process(false);s.begin_tactical()
 assert(s.team.size()==8 and s.sim.allies.size()==8)
 var models:Dictionary={}
 for i in 8:
  var actor=s.team[i];var r:Dictionary=s.roster[i];models[actor.model_key]=true
  assert(actor.model_key==r.model and actor.applied_loadout==r.loadout)
  assert(not actor.attacks.is_empty() and not actor.attachments.is_empty())
  var expected:int=1 if actor.LOADOUT.two_handed(r.loadout.right) or r.loadout.left=="" else 2
  assert(actor.attachments.size()==expected,"Two-handed weapons occupy both slots but instantiate only once")
 assert(models.size()==8)
 s.sim.next_spawn=INF;s.sim.config.total=999
 for i in 50:
  s.sim.spawn_enemy();var e:Dictionary=s.sim.enemies.back()
  e.pos=Vector3(lerpf(-5,5,float(i%5)/4),0,1-float(i/5)*3);e.previous_pos=e.pos;e.activate_at=0;e.born=-1;e.entry="road";e.entry_phase="advance";e.hp=1000;e.max_hp=1000
 for i in 8:
  s.sim.allies[i].energy=s.sim.energy_limit(s.sim.allies[i]);assert(s.sim.cast(i))
 var begin:=Time.get_ticks_usec()
 var timings:Array=[]
 for i in 180:
  var tick:=Time.get_ticks_usec()
  s._process(1.0/60.0)
  timings.append(Time.get_ticks_usec()-tick)
  await process_frame
 timings.sort()
 var elapsed:=Time.get_ticks_usec()-begin
 s.tactical_ui.select(5);s.tactical_ui.preview=true;s._process(0)
 assert(s.tactical_ui.range_view.affected.size()>0,"Healing preview must mark allies")
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/tactical-eight-skills.png")
 print("TACTICAL_ROSTER_LIVE_PASS eight distinct equipped models, valid attack clips, eight casts, healing preview. 180 updates with rendered frames usec=",elapsed," stage update p95 usec=",timings[171])
 quit()
