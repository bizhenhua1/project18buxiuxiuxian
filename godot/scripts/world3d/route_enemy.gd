extends Node3D
## One physical model continues from the road preview into the original enemy slot.
const P=preload("res://scripts/world3d/projection.gd")
var actor
var arena:BattleArena
var camera:Camera3D
var atmosphere=preload("res://scripts/world3d/actor_atmosphere.gd").new()
var health
var key:OmniLight3D
var uid:=-1
var positioned:=false
var attack_stamp:=-INF
var smoke

func setup(source:BattleArena,view:Camera3D):
 arena=source;camera=view
 actor=preload("res://scripts/world3d/actor.gd").new();add_child(actor)
 actor.setup("gentleman.glb");actor.set_opacity(0)
 preload("res://scripts/world3d/party_lighting.gd").set_layer(actor,1<<18)
 key=OmniLight3D.new();key.light_cull_mask=1<<18;key.shadow_enabled=false;add_child(key)
 atmosphere.setup([actor]);atmosphere.set_enabled(true)
 health=preload("res://scripts/world3d/health_view.gd").new();health.setup(actor,atmosphere)
 smoke=preload("res://scripts/world3d/defeat_clear.gd").new();add_child(smoke);smoke.setup(1)

func sync(renderer:SegmentRenderer,bridge,dt:float)->Dictionary:
 var sprite:Dictionary={};var battle:=false
 for candidate in renderer.battle_actors:
  if candidate.get("live_enemy",false):sprite=candidate;battle=true;break
 if sprite.is_empty():
  for candidate in renderer.world.sprites:
   if candidate.get("live_discovery",false) and not candidate.get("hidden",false):sprite=candidate;break
 smoke.clear()
 if sprite.is_empty():actor.set_opacity(0);key.hide();return {}
 var source_uid:int=int(arena.model.enemy[0].uid) if not arena.model.enemy.is_empty() else -1
 if uid!=source_uid:
  uid=source_uid;attack_stamp=-INF;actor.trigger("revive")
 var target:Vector3=P.point(sprite.position,ForestEcology.height_at(sprite.position)+float(sprite.get("altitude",0)))
 var body:Dictionary=bridge.bodies.get(uid,{}) if battle else {}
 if body.get("state","")=="death":target=body.position
 var velocity:Vector3=(target-actor.position)/dt if positioned and dt>0 else Vector3.ZERO
 actor.position=target;positioned=true
 var height:float=float(arena.world_slots[uid].height) if battle and arena.world_slots.has(uid) else float(sprite.h)
 actor.scale=Vector3.ONE*preload("res://scripts/world3d/character_framing.gd").scale_for_slot(height)
 if body.get("state","")=="death" and not actor.dead:actor.trigger("death")
 elif body.get("state","")!="death" and actor.dead:
  actor.trigger("revive");actor.play("rise")
  actor.action=float(actor.library.clips.rise.frames-1)/actor.library.clips.rise.fps
 if body.get("attack_at",-INF)!=attack_stamp and is_finite(body.get("attack_at",-INF)) and not actor.dead and not (actor.clip=="rise" and actor.action>0):
  attack_stamp=body.attack_at;actor.trigger("attack")
 actor.advance(dt,velocity)
 if velocity.length()<.05 and not actor.dead:actor.rotation.y=lerp_angle(actor.rotation.y,-renderer.heading,1-exp(-dt*8))
 var opacity:float=float(sprite.get("ecology_tint",Color.WHITE).a)
 if not battle:opacity*=smoothstep(0,.65,renderer.elapsed-float(sprite.get("born_at",-100)))
 actor.set_opacity(opacity)
 if battle and not body.is_empty():
  bridge.record_presented_position(uid,target)
  health.sync(dt,body.hp,body.max_hp,preload("res://scripts/battle/health_transformation.gd").settings())
  if actor.dead and body.revive_seconds<=0:
   var duration:float=float(actor.library.clips.death.frames-1)/actor.library.clips.death.fps
   smoke.entries=[{"node":actor,"actor":true,"origin":target,"delay":body.death_at+maxf(5,duration),"alpha":opacity,"height":.4*actor.scale.y}]
   smoke.age=arena.model.elapsed;smoke.advance(0,camera)
 else:health.sync(dt,1,1,preload("res://scripts/battle/health_transformation.gd").settings(),true)
 actor.portrait_presenter.advance_anchor(dt,false)
 actor.portrait_presenter.configure_enemy(camera,renderer.focal())
 actor.portrait_presenter.set_enabled(true);actor.portrait_presenter.sync()
 key.visible=actor.visible;key.global_position=actor.global_position+Vector3(-1,1.8,2)*actor.scale.x
 key.light_energy=1.5;key.omni_range=6*actor.scale.x;key.light_color=Color("bedae0")*renderer.enemy_light_tint()
 for legacy in [arena.enemy_actor,arena.owner_app.get("discovery_actor")]:
   if legacy and legacy.viewport:
    legacy.native_pose_external=true;legacy.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 return {int(sprite.id):true}
