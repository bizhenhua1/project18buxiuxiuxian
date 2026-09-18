extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900);StyleLibrary.active=true
 var session=root.get_node("Journey")
 session.SAVE="user://native-route-choices-test.json";session.state=JourneyState.new();session.expedition_active=true
 var zone:Dictionary=session.state.zones[0];zone.route_profile="short_social";zone.battle_choice=true
 session.state.pending=zone.id;session.state.world.input_locked=true;session.state.stones=100
 assert(session.enter_battle());await scene_changed
 var app=current_scene;app.set_process(false)
 for frame in 1000:
  app.paused=false;app._process(.05);await process_frame
  if app.phase=="encounter":break
 assert(app.phase=="encounter" and app.is_social() and app.native_route_view!=null)
 var before:int=session.state.stones
 app.supplies.pressed.emit()
 assert(session.state.stones>before and app.encounter_step==1)
 var after:int=session.state.stones
 app.resolve("supplies");assert(session.state.stones==after,"Duplicate social choice awarded twice")
 for frame in 1000:
  app.paused=false;app._process(.05);await process_frame
  if app.phase=="encounter":break
 assert(app.phase=="encounter" and not app.is_social())
 app.fight.pressed.emit()
 for frame in 120:
  app._process(.05);await process_frame
  if app.phase=="battle":break
 assert(app.phase=="battle")
 for unit in app.model.player:unit.hp=0;unit.reviveLeft=0
 for frame in 40:
  app._process(.05);await process_frame
  if app.phase=="defeat":break
 assert(app.phase=="defeat")
 var camera_at:Transform3D=app.native_route_view.camera.transform
 var step_before:int=app.encounter_step
 app.fight.pressed.emit();assert(app.phase=="reviving")
 for frame in 100:
  app._process(.05);await process_frame
  if app.phase=="battle":break
 assert(app.phase=="battle" and app.encounter_step==step_before)
 assert(app.native_route_view.camera.position.distance_to(camera_at.origin)<.01,"Retry moved the fixed battle camera")
 assert(session.state.stones==after,"Retry changed rewards")
 assert(app.model.player.any(func(unit):return unit.hp>0))
 session.state=null;DirAccess.remove_absolute(session.SAVE)
 print("ROUTE_CHOICES_PASS social choice once, next encounter, defeat, stationary retry and reward preservation")
 quit()
