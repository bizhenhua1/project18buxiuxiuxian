extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame;app.set_process(false);app.choose(-1)
 app.phase="travel";app.paused=true;app.travel_reveal=1
 var hero:Dictionary=app.model.player.filter(func(u):return u.cardId=="daotong")[0]
 var renderer=app.arena.scenery.renderer
 for index in range(app.model.player.size()):
  app.model.player.erase(hero);app.model.player.insert(index,hero);app.arena.rebuild()
  renderer.presentation_blend=0;renderer.set_battle_camera(0)
  app.arena._process(0)
  renderer.set_battle_camera(0)
  var pose:Dictionary=ForestRoute.pose(app.distance,app.branch)
  renderer.heading=pose.heading
  renderer.camera_world=pose.position+Vector2(cos(pose.heading),-sin(pose.heading))*renderer.travel_lateral
  app.arena._process(0)
  var card=app.arena.cards.filter(func(c):return c.unit.get("uid",-1)==hero.uid)[0]
  var head:Vector2=card.position+Vector2(card.size.x*.5,(card.size.y-38)*.10)
  assert(head.y>app.arena.size.y*.40 and head.y<app.arena.size.y*.77,"Head clipped at slot %d: %s"%[index,head])
  assert(head.x>app.arena.size.x*.15 and head.x<app.arena.size.x*.85,"Side clipping")
  var slot:Dictionary=app.arena.world_slots[hero.uid]
  var dims:float=slot.height
  renderer.presentation_blend=1;renderer.set_battle_camera(1);SceneFormation.update(app.arena)
  assert(is_equal_approx(dims,app.arena.world_slots[hero.uid].height))
  print("VISIBLE_SLOT ",index," head=",head)
 print("HERO_SLOT_VISIBILITY_PASS");quit()
