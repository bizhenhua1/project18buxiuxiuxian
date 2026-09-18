extends SubViewportContainer
## Presentation only: the original route owns simulation, events, saves and UI.
## Party members use native skeletons; original image units remain depth-tested planes.
const P=preload("res://scripts/world3d/projection.gd")
const Scenery=preload("res://scripts/world3d/scenery.gd")
var viewport:SubViewport
var scene:Node3D
var camera:Camera3D
var scenery
var source:SegmentView
var world:SegmentWorld
var bodies:Dictionary={}
var rebuild_count:=0
var environment:Environment
var background
var models
var enemy
var cutout_atmosphere=preload("res://scripts/world3d/prop_atmosphere.gd").new()
var cutouts_dirty:=false
var corpse_smoke
var projectiles

func setup(view:SegmentView,arena:BattleArena):
 source=view;mouse_filter=Control.MOUSE_FILTER_IGNORE;stretch=true
 viewport=SubViewport.new();viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 viewport.msaa_3d=Viewport.MSAA_2X;add_child(viewport)
 scene=Node3D.new();viewport.add_child(scene)
 camera=Camera3D.new();scene.add_child(camera);camera.current=true
 background=preload("res://scripts/world3d/forest_background.gd").new();camera.add_child(background)
 var sky:=WorldEnvironment.new();environment=Environment.new()
 environment.background_mode=Environment.BG_COLOR;sky.environment=environment;scene.add_child(sky)
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color=Color("a9bac6");environment.ambient_light_energy=.28
 models=preload("res://scripts/world3d/route_models.gd").new();scene.add_child(models);models.setup(arena,camera)
 if not FairytaleCatalog.has_scene(arena.owner_app.route_zone.get("theme","")):
  enemy=preload("res://scripts/world3d/route_enemy.gd").new();scene.add_child(enemy);enemy.setup(arena,camera)
 corpse_smoke=preload("res://scripts/world3d/defeat_clear.gd").new();scene.add_child(corpse_smoke);corpse_smoke.setup(32)
 projectiles=preload("res://scripts/world3d/route_projectiles.gd").new();scene.add_child(projectiles);projectiles.setup(arena,camera,models)
 hide()

func sync(dt:float=0):
 if source.size.x<2 or source.size.y<2:return
 size=source.size
 var renderer:SegmentRenderer=source.renderer
 renderer.environment=(renderer.world as SegmentWorld).environment()
 if world!=renderer.world:replace_world(renderer.world)
 var lens:=renderer.focal()/minf(size.y*.86,size.x*.72)
 P.configure(camera,size,renderer.camera_world,renderer.heading,renderer.camera_height(),lens,renderer.horizon_y()/size.y)
 environment.background_color=world.camera_region.space.atmosphere.depth_color
 background.sync(renderer)
 scenery.process_uploads(1500)
 var floor_material:ShaderMaterial=scenery.floor_material
 floor_material.set_shader_parameter("route_origin",ForestRoute.origin)
 floor_material.set_shader_parameter("route_origin_s",ForestRoute.origin_s)
 floor_material.set_shader_parameter("route_origin_heading",ForestRoute.origin_heading)
 var seen:Dictionary={}
 var replaced:Dictionary=models.sync(renderer,dt)
 if enemy:replaced.merge(enemy.sync(renderer,models.bridge,dt))
 for sprite in world.sprites:
  if sprite.get("actor",false) and not replaced.has(int(sprite.id)):sync_body(sprite,seen)
 for sprite in renderer.battle_actors:
  if not replaced.has(int(sprite.id)):sync_body(sprite,seen)
 for id in bodies.keys():
  if not seen.has(id):bodies[id].queue_free();bodies.erase(id);cutouts_dirty=true
 corpse_smoke.clear()
 for body in models.bridge.bodies.values():
  var id:int=200000+int(body.uid)
  if body.side!="enemy" or body.state!="death" or body.revive_seconds>0 or not bodies.has(id):continue
  var node:Sprite3D=bodies[id]
  corpse_smoke.entries.append({"node":node,"actor":false,"origin":body.position,"delay":body.death_at+5,"alpha":node.modulate.a,"height":node.pixel_size*node.texture.get_height()})
 corpse_smoke.age=models.arena.model.elapsed;corpse_smoke.advance(0,camera)
 if cutouts_dirty:
  cutout_atmosphere=preload("res://scripts/world3d/prop_atmosphere.gd").new()
  var items:Array=[];var profiles:Array=[]
  for node in bodies.values():
   if node.has_meta("source_texture"):node.texture=node.get_meta("source_texture")
   items.append({"node":node,"slot":profiles.size()});profiles.append({"clearance":0})
  cutout_atmosphere.setup(items,profiles);cutouts_dirty=false
 projectiles.sync(dt)
 # Publish virtual projectile/burst lights before all world materials consume
 # them; the original arena clears last frame's flashes on its next tick.
 scenery.update_view(renderer)
 models.atmosphere.sync(renderer,true)
 if enemy:enemy.atmosphere.sync(renderer,true)
 cutout_atmosphere.sync(renderer,true)
 source.hide();show()

func replace_world(next:SegmentWorld):
 # World identity changes only at a route handoff, never on a camera tick.
 if scenery:scene.remove_child(scenery);scenery.queue_free()
 world=next;scenery=Scenery.new();scene.add_child(scenery)
 scenery.fixed_shells=true
 var route=preload("res://scripts/world3d/route_segment.gd").new(ForestRoute.origin_s,ForestRoute.origin,ForestRoute.origin_heading,ForestRoute.JUNCTION,ForestRoute.TURN_LENGTH,ForestRoute.END_AT,world.plan.exits)
 scenery.populate(world,route);rebuild_count+=1

func sync_body(sprite:Dictionary,seen:Dictionary):
 if sprite.get("hidden",false) or sprite.get("texture")==null:return
 var id:int=int(sprite.id);seen[id]=true
 var node:Sprite3D=bodies.get(id)
 if not node:
  node=Sprite3D.new();node.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y
  node.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  scene.add_child(node);bodies[id]=node
  cutouts_dirty=true
 node.visible=not sprite.get("hidden",false)
 if not node.visible:return
 var texture:Texture2D=sprite.texture
 if not node.has_meta("source_texture") or node.get_meta("source_texture")!=texture:
  node.texture=texture;node.set_meta("source_texture",texture);cutouts_dirty=true
 node.pixel_size=float(sprite.h)/20.0/texture.get_height()
 var anchor:Vector2=sprite.get("ground_anchor",Vector2(.5,1))
 node.offset=Vector2((.5-anchor.x)*texture.get_width(),(anchor.y-.5)*texture.get_height())
 node.flip_h=sprite.get("flip",false)
 node.position=P.point(sprite.position,ForestEcology.height_at(sprite.position)+float(sprite.get("altitude",0)))
 node.set_meta("presentation_clearance",float(sprite.get("altitude",0)))
 node.modulate=sprite.get("ecology_tint",Color.WHITE)
 node.modulate.a*=smoothstep(0,.65,source.renderer.elapsed-float(sprite.get("born_at",-100)))

func suspend():
 hide();source.show();viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
 for legacy in models.arena.equipped_actors.values():
  if legacy.viewport:
   legacy.native_pose_external=false;legacy.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 if enemy:
  for legacy in [models.arena.enemy_actor,models.arena.owner_app.get("discovery_actor")]:
   if legacy and legacy.viewport:
    legacy.native_pose_external=false;legacy.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func resume(dt:float=0):
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;sync(dt)
