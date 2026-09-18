extends SceneTree
const P=preload("res://scripts/world3d/projection.gd")
var app
var test_theme:="snow_mirror"
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 if has_meta("native_route_view"):remove_meta("native_route_view")
 set_meta("tour_biome",test_theme)
 var path="user://endless-forest-test.json"
 var existed:=FileAccess.file_exists(path)
 var previous:=FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
 app=load("res://scenes/endless_forest.tscn").instantiate();root.add_child(app);current_scene=app
 assert(get_meta("native_route_view",false),"Direct endless entry did not enable native presentation")
 print("ROUTE_BOOT_READY ",test_theme)
 app.set_process(false)
 for i in 3:await process_frame
 app._process(0)
 print("ROUTE_FIRST_FRAME")
 var native=app.native_route_view
 var enemy_identity:int=native.enemy.actor.get_instance_id() if native.enemy else 0
 assert(native and native.world==app.world)
 assert(not app.views[0].visible)
 var old_time:float=app.model.elapsed
 for i in 20:native.sync()
 print("ROUTE_READONLY_VERIFIED")
 assert(app.model.elapsed==old_time,"Presentation must never tick combat")
 var renderer:SegmentRenderer=app.views[0].renderer
 for lateral in [-60.0,0.0,80.0]:
  var at:Vector2=renderer.camera_world+Vector2(lateral,180).rotated(-renderer.heading)
  var height:=ForestEcology.height_at(at)+20
  var expected:=P.project_reference(at,height,native.size,renderer.camera_world,renderer.heading,renderer.camera_height(),renderer.focal()/minf(native.size.y*.86,native.size.x*.72),renderer.horizon_y()/native.size.y)
  assert(native.camera.unproject_position(P.point(at,height)).distance_to(expected)<.05,"Native projection diverged from saved camera")
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 print("ROUTE_CAPTURE_READY")
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-original-route-%s.png"%test_theme)
 var choices:=0;var battles:=0
 for i in 1600:
  app.paused=false
  if app.phase=="choose":app.choose(-1);choices+=1
  elif app.phase=="encounter":app.start_battle()
  elif app.phase=="battle":
   if FairytaleCatalog.has_scene(test_theme):assert(app.model.enemy[0].get("fairytale_enemy",false),"Original monster deck was replaced")
   if battles==0:
    for frame in 12:
     app._process(.05);await process_frame
    assert(renderer.camera_world.distance_to(app.camera)<.001,"Hidden reference stopped publishing the moving camera")
    assert(renderer.camera_world.distance_to(app.arena.world_anchor)<2,"Settled battle camera must stay at encounter origin")
    if native.enemy:
     assert(native.enemy.actor.get_instance_id()==enemy_identity,"Preview model was replaced at battle entry")
     var enemy_sprite:Dictionary=renderer.battle_actors.filter(func(s):return s.get("live_enemy",false))[0]
     assert(native.enemy.actor.position.distance_to(P.point(enemy_sprite.position,ForestEcology.height_at(enemy_sprite.position)+enemy_sprite.altitude))<.001)
     assert(not native.bodies.has(int(enemy_sprite.id)),"Native enemy still has a portrait duplicate")
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://../tempassets/work/world3d-original-route-%s-battle.png"%test_theme)
    native.suspend()
    for frame in 2:await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://../tempassets/work/world3d-original-route-%s-reference.png"%test_theme)
    native.resume()
    for legacy in app.arena.equipped_actors.values():
     assert(legacy.native_pose_external)
     var samples_before:int=legacy.pose_samples
     legacy.advance(.05,"battle",false,1,true)
     assert(legacy.pose_samples==samples_before,"Replaced portrait still evaluates skeleton")
    native.suspend()
    for legacy in app.arena.equipped_actors.values():assert(not legacy.native_pose_external)
    native.resume()
    var emitter:Dictionary=app.model.player[0]
    var saved_attack=emitter.atkType
    emitter.atkType="ranged"
    app.model.shoot(emitter,app.model.enemy[0],1)
    var probe:Dictionary=app.model.shots.back()
    native.sync(0)
    assert(not native.projectiles.sim.projectiles.active.is_empty(),"Original shot was not presented in 3D")
    var before_model:String=JSON.stringify([app.model.player,app.model.enemy,app.model.shots,app.model.elapsed])
    native.projectiles.sync(.05)
    assert(before_model==JSON.stringify([app.model.player,app.model.enemy,app.model.shots,app.model.elapsed]),"VFX changed authoritative combat")
    var impacts_before:int=int(native.projectiles.effects.requested_by_kind.get("impact",0))
    app.model.advance(float(probe.duration)+.01);native.sync(.05)
    assert(probe.get("resolved",false))
    assert(int(native.projectiles.effects.requested_by_kind.get("impact",0))>impacts_before,"Resolved shot has no impact")
    emitter.atkType="beam";app.model.shoot(emitter,app.model.enemy[0],1)
    app.model.advance(.03);native.sync(.03)
    assert(native.projectiles.beams.get_surface_count()==1,"Beam missing from the shared world")
    emitter.atkType=saved_attack
    print("ROUTE_NATIVE_LIFECYCLE_BEGIN")
    var people:Array=app.model.player.filter(func(u):return preload("res://scripts/world3d/party.gd").character(u))
    assert(native.models.actors.size()==people.size())
    for unit in people:
     var actor=native.models.actors[unit.uid].actor
     assert(actor.rig!=null and actor.model_key==preload("res://scripts/equipment/loadouts.gd").model_for_unit(unit))
     assert(not native.bodies.has(200000+int(unit.uid)),"Legacy portrait duplicated the native rig")
    var victim:Dictionary=people[0]
    var hp:float=victim.hp;var status=victim.status
    var native_actor=native.models.actors[victim.uid].actor
    var at:Vector3=native_actor.position
    victim.hp=0;victim.status="corpse";native.sync(.05)
    print("ROUTE_NATIVE_DEAD")
    assert(native_actor.dead and native_actor.clip=="death")
    for frame in 30:native.sync(.05)
    print("ROUTE_NATIVE_CORPSE")
    assert(native_actor.position.distance_to(at)<.001,"Corpse moved after death")
    victim.hp=hp;victim.status=status;native.sync(.05)
    print("ROUTE_NATIVE_REVIVED")
    assert(not native_actor.dead and native_actor.clip=="rise","Revival must use native get-up animation")
    var foe:Dictionary=app.model.enemy[0]
    var foe_hp:float=foe.hp;var foe_status=foe.status
    var combat_time:float=app.model.elapsed
    foe.hp=0;foe.status="corpse";foe.reviveLeft=0;native.sync(.05)
    app.model.elapsed=combat_time+4.99;native.sync(.05)
    var fog=native.enemy.smoke if native.enemy else native.corpse_smoke
    assert(fog.multimesh.visible_instance_count==0,"Corpse smoke started before five seconds")
    app.model.elapsed=combat_time+5.6;native.sync(.05)
    assert(fog.multimesh.visible_instance_count>0,"Dead enemy never entered smoke removal")
    foe.reviveLeft=1000;native.sync(.05)
    assert(fog.multimesh.visible_instance_count==0,"Revivable enemy must keep its corpse")
    foe.hp=foe_hp;foe.status=foe_status;foe.reviveLeft=0;app.model.elapsed=combat_time;native.sync(.05)
    if native.enemy:assert(native.enemy.actor.clip=="rise" and not native.enemy.actor.dead,"Enemy revived without get-up animation")
   app.finish_battle("victory");battles+=1
  app._process(.05)
  # GPU integration runs one presentation update per rendered frame. Pure
  # simulation parity is covered separately without this rendering workload.
  await process_frame
  if app.lap>=2:break
 app._process(0)
 assert(choices>0 and battles>0 and app.lap>=2)
 assert(native.world==app.world and native.rebuild_count==2,"World handoff not propagated, or rebuilding every frame")
 native.suspend();assert(app.views[0].visible)
 native.resume();assert(not app.views[0].visible)
 if existed:
  var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(previous);file.close()
 else:DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("ORIGINAL_ROUTE_3D_PASS camera parity, read-only clock, original deck, fork, victory, continuous world handoff; battles=",battles)
 quit()
