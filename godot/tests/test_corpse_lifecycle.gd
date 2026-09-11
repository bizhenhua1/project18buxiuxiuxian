extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app)
 await process_frame
 app.set_process(false);app.arena.set_process(false);app.choose(-1)
 while app.is_social():app.encounter_step+=1
 app.distance=app.stops()[app.encounter_step];app.prepare_encounter()
 app.phase="battle";app.arena.entrance_progress=1;app.arena.battle_mix=1
 app.arena.enemies_visible=true;app.arena.enemy_opacity=1
 app.arena._process(.016)
 var card
 for c in app.arena.cards:
  if c.side=="enemy" and c.index==0:card=c;break
 var actor=app.arena.enemy_actor
 card.scene_motion_offset=Vector2(7,9)
 var death_position:Vector2=card.scene_rest_position+card.scene_motion_offset
 card.unit.hp=0;card.unit.status="corpse"
 app.arena.on_event({"type":"death","unit":card.unit})
 for i in range(240):
  actor.advance(.016,"battle",false,1,true)
  SceneFormation.update(app.arena,.016)
 assert(actor.dead and actor.state=="death" and actor.body.visible)
 assert(actor.death_remaining()==0)
 var found:=false
 for item in app.arena.scenery.renderer.battle_actors:
  if item.id==200000+card.unit.uid:
   assert(item.position.distance_to(death_position)<.001);found=true
 assert(found,"Corpse must remain rendered")
 card.unit.hp=card.unit.maxHp;card.unit.status="alive"
 app.arena.on_event({"type":"revive","unit":card.unit})
 SceneFormation.update(app.arena,.016)
 assert(card.unit.returning_to_slot)
 for i in range(300):SceneFormation.update(app.arena,.016)
 assert(not card.unit.returning_to_slot and not actor.dead)
 actor.advance(.016,"defeat",false,1,true)
 assert(actor.removing and is_instance_valid(actor.death_fog))
 for i in range(100):actor.advance(.016,"defeat",false,1,true)
 assert(not actor.body.visible)
 actor.trigger("revive");assert(actor.body.visible and not actor.removing)
 for c in app.arena.cards:
  if c.side=="player" and not c.unit.is_empty():
   c.unit.hp=0;c.unit.status="corpse";c.unit.returning_to_slot=true
   c.set_meta("corpse_position",Vector2(14,25));c.set_meta("return_position",Vector2(14,25))
 app.arena.restore_victorious_party()
 for c in app.arena.cards:
  if c.side=="player" and not c.unit.is_empty():
   assert(c.unit.hp==c.unit.maxHp and c.unit.status=="alive" and not c.unit.returning_to_slot)
   assert(not c.has_meta("corpse_position") and not c.has_meta("return_position"))
 print("CORPSE_PASS death animation, stationary persistent corpse, return after revive, mist removal and restore")
 quit()
