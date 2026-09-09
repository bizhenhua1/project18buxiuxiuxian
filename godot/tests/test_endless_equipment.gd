extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app);app.set_process(false)
 # Reproduce the last victory before a new unselected fork: no next battle
 # preparation runs here to accidentally release the edit lock for us.
 app.phase="choose";app.distance=ForestRoute.PAUSE_AT;app.choose(1)
 app.encounter_step=app.stops().size()-1
 app.distance=app.stops()[-1]
 app.model.phase="victory";app.phase="battle"
 app.finish_battle("victory")
 for i in range(29):app._process(.05)
 assert(app.phase=="travel" and app.branch==0)
 assert(app.model.can_edit(),"Victory left formation editing locked")
 app.open_kit()
 assert(app.kit_panel.visible and app.arena.equipment_open and app.paused)
 var cards:Array=app.arena.cards.filter(func(c):return c.side=="player" and not c.unit.is_empty())
 var first_uid:int=app.model.player[0].uid
 assert(cards[1]._can_drop_data(Vector2.ZERO,{"formation_index":0}))
 cards[1]._drop_data(Vector2.ZERO,{"formation_index":0})
 assert(app.model.player[1].uid==first_uid,"Formation drop did not reorder")
 var prop_index:=-1
 for i in range(app.model.player.size()):
  if app.model.player[i].cardType=="fabao":prop_index=i;break
 assert(prop_index>=0)
 var id:String=app.model.player[prop_index].cardId
 app.model.remove_at(prop_index);app.arena.rebuild()
 var count:int=app.model.player.size()
 var target=app.arena.cards.filter(func(c):return c.side=="player")[0]
 assert(target._can_drop_data(Vector2.ZERO,{"card_id":id}))
 target._drop_data(Vector2.ZERO,{"card_id":id})
 assert(app.model.player.size()==count+1 and app.model.player[0].cardId==id,"Inventory drop did not insert")
 app.close_kit();assert(not app.paused)
 app.model.phase="battle"
 assert(not target._can_drop_data(Vector2.ZERO,{"formation_index":0}),"Combat editing became enabled")
 print("ENDLESS_EQUIPMENT_PASS post-victory reorder, inventory drop, resume, combat lock")
 quit()
