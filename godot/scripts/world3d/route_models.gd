extends Node3D
## Native skeletons for the original BattleModel; no independent combat clock.
const PARTY=preload("res://scripts/world3d/party.gd")
const P=preload("res://scripts/world3d/projection.gd")
var arena:BattleArena
var camera:Camera3D
var actors:Dictionary={}
var samples:Dictionary={}
var bridge=preload("res://scripts/world3d/model_bridge.gd").new()
var atmosphere=preload("res://scripts/world3d/actor_atmosphere.gd").new()
var lights
var signature:=""

func setup(source:BattleArena,view_camera:Camera3D):
 arena=source;camera=view_camera;bridge.bind(arena.model)

func _exit_tree():bridge.release()

func rebuild(units:Array):
 for entry in actors.values():remove_child(entry.actor);entry.actor.queue_free()
 actors.clear()
 atmosphere=preload("res://scripts/world3d/actor_atmosphere.gd").new()
 if lights:remove_child(lights);lights.queue_free()
 lights=preload("res://scripts/world3d/party_lighting.gd").new();add_child(lights)
 var group:Array=[]
 for unit in units:
  var actor=preload("res://scripts/world3d/allied_actor.gd").new();add_child(actor)
  actor.setup(PARTY.LOADOUT.model_for_unit(unit));actor.refresh_equipment()
  actor.rotation.y=PI;actor.set_opacity(0)
  actors[unit.uid]={"actor":actor,"positioned":false,"last_attack":-INF,"state":"idle"}
  group.append(actor)
 lights.setup(group);atmosphere.setup(group);atmosphere.set_enabled(true)
 for entry in actors.values():
  entry.health=preload("res://scripts/world3d/health_view.gd").new();entry.health.setup(entry.actor,atmosphere)

func placement(unit:Dictionary)->Vector3:
 var sprite:Dictionary=samples.get(200000+int(unit.uid),{})
 if sprite.is_empty():return bridge.bodies.get(unit.uid,{}).get("position",Vector3.ZERO)
 return P.point(sprite.position,ForestEcology.height_at(sprite.position)+float(sprite.get("altitude",0)))

func sync(renderer:SegmentRenderer,dt:float)->Dictionary:
 samples.clear()
 for sprite in renderer.battle_actors:samples[int(sprite.id)]=sprite
 var units:Array=arena.model.player.filter(func(u):return PARTY.character(u))
 var key:String=str(units.map(func(u):return [u.uid,PARTY.LOADOUT.model_for_unit(u)]))
 if key!=signature:signature=key;rebuild(units)
 bridge.sync(placement)
 var replaced:Dictionary={}
 for unit in units:
  var uid:int=unit.uid;var id:int=200000+uid
  var entry:Dictionary=actors[uid];var actor=entry.actor
  var sprite:Dictionary=samples.get(id,{})
  if sprite.is_empty():actor.set_opacity(0);continue
  replaced[id]=true
  var body:Dictionary=bridge.bodies[uid]
  var target:Vector3=placement(unit)
  if body.state=="death":target=body.position
  var velocity:Vector3=(target-actor.position)/dt if entry.positioned and dt>0 else Vector3.ZERO
  actor.position=target;entry.positioned=true
  actor.scale=Vector3.ONE*preload("res://scripts/world3d/character_framing.gd").scale_for_slot(float(arena.world_slots[uid].height))
  actor.refresh_equipment_if_changed()
  if body.state=="death" and not actor.dead:actor.trigger("death")
  elif body.state!="death" and actor.dead:actor.trigger("battle_revive")
  if body.attack_at!=entry.last_attack and is_finite(body.attack_at) and not actor.dead:
   actor.attack_seconds=body.attack_seconds;actor.trigger("attack");entry.last_attack=body.attack_at
  actor.advance(dt,velocity)
  if velocity.length()<.05 and not actor.dead:
   actor.rotation.y=lerp_angle(actor.rotation.y,PI-arena.world_facing,1-exp(-dt*8))
  actor.set_opacity(float(sprite.get("ecology_tint",Color.WHITE).a))
  actor.portrait_presenter.advance_anchor(dt,unit.cardId=="investigator")
  actor.portrait_presenter.set_enabled(true);actor.portrait_presenter.sync()
  entry.health.sync(dt,float(unit.hp),float(unit.maxHp),preload("res://scripts/battle/health_transformation.gd").settings())
  bridge.record_presented_position(uid,target)
  # SceneFormation still reads framing metadata, but its replaced portrait
  # no longer needs a second offscreen render of this character.
  var legacy=arena.equipped_actors.get(uid)
  if legacy and legacy.viewport:
   legacy.native_pose_external=true;legacy.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 lights.sync(renderer.team_light(),renderer.environment_light_tint(),renderer.heading)
 # Original VFX consumer still owns attack visuals until its 3D adapter lands.
 bridge.take_effects()
 return replaced
