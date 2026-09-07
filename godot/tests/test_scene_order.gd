extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 StyleLibrary.active=true
 var session=root.get_node("Journey");session.SAVE="user://order-test.json";session.state=JourneyState.new()
 session.state.pending=session.state.zones[0].id
 var app=load("res://scenes/expedition_route.tscn").instantiate();root.add_child(app);app.set_process(false)
 app.prepare_encounter();var arena=app.arena;arena.set_process(false);arena.scene_mode=true;arena.battle_mix=1;arena.enemies_visible=true
 for reverse in [false,true]:
  var row=arena.cards.filter(func(c):return c.side=="player" and not c.unit.is_empty())
  if reverse:
   for card in row:card.index=row.size()-1-card.index
  arena._process(0)
  row.sort_custom(func(a,b):return a.index<b.index)
  var last:float=-INF
  var last_depth:float=INF
  for card in row:
   var center:float=card.position.x+card.size.x*.5
   assert(center>last,"Card order and scene order differ");last=center
   if card.unit.get("portrait_kind","")=="person" or card.unit.cardType=="char":
    var actor=arena.scenery.renderer.battle_actors.filter(func(a):return a.id==200000+card.unit.uid)[0]
    var relative:=ForestRoute.to_camera(actor.position,arena.scenery.renderer.camera_world,arena.scenery.renderer.heading)
    assert(relative.y<last_depth,"Left character is not farther")
    last_depth=relative.y
    assert(card.position.y+card.size.y-38>arena.size.y,"Character feet visible")
    var renderer=arena.scenery.renderer
    var baseline:float=renderer.horizon_y()+renderer.camera_height()*renderer.focal()/226.0
    assert(card.position.y>=baseline-arena.size.y*.05,"Head above enemy baseline allowance")
    assert(abs(center/arena.size.x-.5)>=.139,"Character blocks center axis")
    assert(actor.flip==(center>arena.size.x*.5),"Facing does not follow lane")
 print("SCENE_ORDER_PASS mixed card order and reversed order; inward character facing")
 quit()
