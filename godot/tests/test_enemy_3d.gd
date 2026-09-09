extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame;app.set_process(false);app.choose(-1)
 while app.is_social():app.encounter_step+=1
 app.distance=app.stops()[app.encounter_step];app.fork_transit_time=app.FORK_TRANSIT_SECONDS
 app.prepare_encounter();assert(app.scene_actor.live_enemy)
 app.phase="encounter";app.start_battle()
 app._process(.3);await process_frame
 assert(app.arena.enemy_actor.state=="backstep")
 var pose_time=app.arena.enemy_actor.elapsed
 app.arena.enemy_actor.advance(.5,"entering",true,1,true,app.arena.entrance_progress)
 assert(app.arena.enemy_actor.elapsed==pose_time)
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../art/3d/seer/enemy3d-backstep.png")
 for i in range(23):app._process(.05);await process_frame
 assert(app.phase=="battle")
 app.paused=true;app.model.paused=true
 var companion=app.arena.companion_actor
 assert(companion.uid>=0 and companion.ally)
 assert(app.arena.scenery.renderer.battle_actors.any(func(a):return a.get("live_companion",false)))
 var teammate=app.model.player.filter(func(u):return u.uid==companion.uid)[0]
 for kind in ["shot","damage","death","revive"]:
  app.arena.on_event({"type":kind,"unit":teammate,"from":teammate,"to":app.model.enemy[0],"source":app.model.enemy[0],"amount":1})
  companion.advance(.1,"battle",false,1,true)
  assert(companion.state=={"shot":"attack","damage":"hit","death":"death","revive":"idle"}[kind])
 var actor=app.arena.enemy_actor
 var foe=app.model.enemy[0];var hero=app.model.player[0]
 for item in [["idle",.3],["damage",.15],["shot",.5],["death",3.5]]:
  if item[0]=="death":foe.hp=0
  if item[0]!="idle":
   app.arena.on_event({"type":item[0],"unit":foe,"from":foe,"to":hero,"source":hero,"amount":1})
  var state=actor.state
  for i in range(12):actor.advance(item[1]/12,"battle",false,1,true);await process_frame
  if item[0]=="damage":assert(state=="hit")
  if item[0]=="shot":assert(state=="attack")
  if item[0]=="death":
   assert(actor.dead and actor.state=="death")
   actor.trigger("shot");assert(actor.state=="death")
   var final_pose=actor.rig.get_bone_pose_rotation(actor.rig.find_bone("上半身"))
   actor.advance(1,"battle",false,1,true)
   assert(final_pose.is_equal_approx(actor.rig.get_bone_pose_rotation(actor.rig.find_bone("上半身"))))
  app.arena._process(0);app.arena.scenery.sync_projection()
  await process_frame;await RenderingServer.frame_post_draw
  if item[0]=="idle":actor.texture().get_image().save_png("res://../art/3d/seer/enemy3d-model.png")
  root.get_texture().get_image().save_png("res://../art/3d/seer/enemy3d-%s.png"%item[0])
 assert(not app.arena.scenery.renderer.battle_actors.any(func(a):return a.get("live_enemy",false)))
 var time=actor.elapsed;actor.advance(.5,"battle",true,1,true);assert(time==actor.elapsed)
 actor.trigger("revive");foe.hp=foe.maxHp;assert(not actor.dead and actor.state=="idle")
 app.arena._process(0)
 assert(app.arena.scenery.renderer.battle_actors.any(func(a):return a.get("live_enemy",false)))
 for unit in app.model.player:unit.hp=0
 app.arena._process(0)
 assert(not app.arena.scenery.renderer.battle_actors.any(func(a):return a.get("live_character",false) or a.get("live_companion",false)))
 # Restat/reset can restore HP without emitting a revive event.
 app.arena.seer.trigger("death");app.arena.companion_actor.trigger("death")
 for unit in app.model.player:unit.hp=unit.maxHp
 app.arena._process(.05)
 assert(not app.arena.seer.defeated and not app.arena.companion_actor.dead)
 assert(app.arena.scenery.renderer.battle_actors.any(func(a):return a.get("live_character",false)))
 var selected=load("res://scripts/battle/selected_hero_actor.gd").new()
 selected.model_scene=load("res://assets/characters3d/isabella.glb");selected.ally=true
 root.add_child(selected)
 selected.sync(.1,"travel",1,false,1,true,10000)
 assert(selected.state=="walk" and selected.elapsed<=.1)
 selected.trigger("death");selected.trigger("revive")
 selected.sync(.1,"battle",0,false,1,true)
 assert(not selected.defeated and selected.state=="idle")
 selected.queue_free()
 print("ENEMY_3D_PASS");quit()
