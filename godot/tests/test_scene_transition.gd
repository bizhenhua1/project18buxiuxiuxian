extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 StyleLibrary.active=true;root.size=Vector2i(1600,960)
 var session=root.get_node("Journey");session.SAVE="user://transition-test.json";session.state=JourneyState.new()
 session.state.pending=session.state.zones[0].id
 var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app)
 app.set_process(false);app.arena.set_process(false);app.arena.scene_mode=true
 app.prepare_encounter();app.phase="encounter"
 app.distance=app.stops()[0];app.camera=ForestRoute.pose(app.distance,app.branch).position
 for view in app.views:view.sync(app.camera,app.heading,app.elapsed,0,app.branch,false,false,app.distance)
 app.arena._process(0)
 app.start_battle();app.arena._process(0)
 assert(app.scene_actor.hidden and not app.road_actor.visible)
 var renderer=app.arena.scenery.renderer
 var uid=app.model.enemy[0].uid
 var source=app.arena.scene_enemy_sources[uid]
 var enemy=renderer.battle_actors.filter(func(a):return a.id==200000+uid)[0]
 assert(enemy.position.distance_to(source.position)<.001 and abs(enemy.h-source.h)<.001)
 var previous:Dictionary={}
 for i in range(62):
  app._process(1.0/60);app.arena._process(1.0/60)
  if app.phase=="entering":
   assert(renderer.battle_actors.all(func(a):return a.get("edge_strength",0.0)==0.0),"Outline appeared before deployment")
  for card in app.arena.cards:
   if not card.visible:continue
   assert(card.scene_body_in_world,"Renderer switched during transition")
   if previous.has(card.unit.uid) and card.position.distance_to(previous[card.unit.uid])>=85:
    print("JUMP ",i," ",card.side," ",card.index," ",card.position.distance_to(previous[card.unit.uid])," ",app.phase);quit(1);return
   previous[card.unit.uid]=card.position
  await process_frame
 assert(app.phase=="battle")
 app.model.elapsed=.2;app.arena._process(0)
 var edges=renderer.battle_actors.filter(func(a):return a.get("edge_strength",0.0)>0)
 assert(edges.size()==app.model.enemy.size() and edges[0].edge_strength<1,"Outline fade missing")
 for i in range(3):await process_frame
 assert(renderer.forest_batch.edge_pass.multimesh.visible_instance_count==edges.size())
 app.finish_battle("victory")
 var widths:Dictionary={}
 for frame in range(84):
  app._process(1.0/60);app.arena._process(1.0/60)
  if app.phase!="clearing":break
  for card in app.arena.cards:
   if card.side!="player" or not card.visible or card.modulate.a<.02:continue
   if widths.has(card.unit.uid):assert(card.size.x>=widths[card.unit.uid]*.995,"Exit shrinks the unit")
   widths[card.unit.uid]=card.size.x
 assert(not widths.is_empty())
 print("TRANSITION_PASS original enemy position/size retained; one body renderer; 62 continuous frames; combat starts after deployment")
 quit()
