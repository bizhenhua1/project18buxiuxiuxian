extends SceneTree
func _initialize() -> void:call_deferred("run")
func snapshot(app) -> Dictionary:
 var result:Dictionary={}
 for actor in app.arena.scenery.renderer.battle_actors:
  result[actor.id]={"position":actor.position,"h":actor.h}
 return result
func run() -> void:
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame;app.set_process(false);app.choose(-1)
 while app.is_social():app.encounter_step+=1
 app.distance=app.stops()[app.encounter_step];app.fork_transit_time=app.FORK_TRANSIT_SECONDS
 app.prepare_encounter();app.phase="encounter";app.arena._process(0)
 var before:=snapshot(app)
 app.start_battle();app.arena._process(0)
 var start:=snapshot(app)
 for id in before:
  if start.has(id):
   assert(before[id].position.distance_to(start[id].position)<.01,"Entry changed world position")
   assert(is_equal_approx(before[id].h,start[id].h),"Entry changed size")
 for i in range(26):app._process(.05);await process_frame
 assert(app.phase=="battle")
 app.model.paused=true;app.paused=true;app.arena._process(0)
 var fixed:=snapshot(app)
 var renderer=app.arena.scenery.renderer
 var old_camera:Vector2=renderer.camera_world
 var old_heading:float=renderer.heading
 renderer.camera_world+=Vector2(7,12);renderer.heading+=.12
 renderer.presentation_blend=.2;renderer.set_battle_camera(.2)
 SceneFormation.update(app.arena)
 var moved:=snapshot(app)
 for id in fixed:
  assert(moved.has(id))
  assert(fixed[id].position.distance_to(moved[id].position)<.001,"Camera rewrote world position")
  assert(is_equal_approx(fixed[id].h,moved[id].h),"Camera rewrote world size")
 renderer.camera_world=old_camera;renderer.heading=old_heading
 renderer.presentation_blend=1;renderer.set_battle_camera(1)
 app.arena._process(0);app.arena.scenery.sync_projection()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/fixed-world-battle.png")
 app.phase="clearing";app.clearing_time=1.4;app.arena.battle_mix=0
 app.arena._process(0)
 var leaving:=snapshot(app)
 app.distance+=app.EXIT_ADVANCE;app.phase="travel";app.travel_reveal=0
 app.arena._process(0)
 var travel:=snapshot(app)
 for id in leaving:
  if travel.has(id) and app.model.player.any(func(unit):return 200000+unit.uid==id):
   assert(leaving[id].position.distance_to(travel[id].position)<.001,"Exit handoff changed world position")
   assert(is_equal_approx(leaving[id].h,travel[id].h),"Exit scaled unit")
 print("WORLD_FORMATION_PASS entry continuity, independent camera, fixed dimensions, exit continuity")
 quit()

