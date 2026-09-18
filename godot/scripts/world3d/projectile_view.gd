extends Node3D
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LIB="res://assets/fx/epic181/library/"
var app
var enabled:=true
var disabled_cleared:=false
var pools:Dictionary={}
var bindings:Dictionary={}
var emission_offsets:Dictionary={}
var dropped_visuals:=0
var shared_muzzles:=0
var shared_impacts:=0
var requested_by_kind:Dictionary={}
var dropped_by_kind:Dictionary={}
var peak_by_kind:Dictionary={}
var particle_peak_by_kind:Dictionary={}
var gpu_curves_enabled:=false
var gpu_motion_enabled:=false
var capacities:Dictionary={"missile":128,"impact":96,"muzzle":24}
var render_batch
var ordinary_budget:bool="--ordinary-vfx-budget" in OS.get_cmdline_user_args()
var prewarm_usec:=0
var reservations=preload("res://scripts/world3d/vfx_reservations.gd").new()
var budget_profiles:Dictionary={}
var dense_instances:=0
static func requested_caps(profiles:Dictionary,kind:String,projectiles:int)->Array:
 var dense:Dictionary=profiles.get("dense",{})
 if projectiles>=int(dense.get("projectile_threshold",2147483647)):
  return dense.caps[kind].duplicate()
 return profiles.ordinary[kind].caps.duplicate()
func prewarm():
 var began:=Time.get_ticks_usec()
 var viewport:=SubViewport.new();viewport.size=Vector2i(64,64);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true
 var warmers:Array=[]
 for kind in pools:
  var source=pools[kind][0]
  var fx=FX.new();fx.gpu_curves=gpu_curves_enabled;fx.gpu_motion=gpu_motion_enabled
  viewport.add_child(fx);fx.position=Vector3(0,0,-4);fx.scale=Vector3.ONE*.1
  fx.setup({"layers":source.layers.map(func(layer):return layer.data)},camera,LIB)
  fx.stopped=true
  for layer in fx.layers:fx.spawn(layer,fx.global_position)
  fx.advance(.001);warmers.append(fx)
 # Draw actual material variants without advancing the real pools or their RNG.
 for i in 3:await get_tree().process_frame
 await RenderingServer.frame_post_draw
 viewport.free()
 prewarm_usec=Time.get_ticks_usec()-began
var lighting=preload("res://scripts/world3d/projectile_lights.gd").new()
func setup(owner_app):
 app=owner_app
 ordinary_budget=bool(get_tree().get_meta("world3d_ordinary_vfx_budget",ordinary_budget))
 lighting.shared_flights=ordinary_budget
 if ordinary_budget:
  budget_profiles=JSON.parse_string(FileAccess.get_file_as_string("res://data/world3d_vfx_budgets.json"))
  reservations.soft_limit=int(budget_profiles.soft_limit)
  lighting.burst_limit=int(budget_profiles.lighting.burst_limit)
  lighting.burst_merge_distance=float(budget_profiles.lighting.burst_merge_distance)
  lighting.burst_merge_window=float(budget_profiles.lighting.burst_merge_window)
 if "--batch-particles" in OS.get_cmdline_user_args():
  render_batch=preload("res://scripts/spaces/epic181_render_batch.gd").new();add_child(render_batch)
 if "--full-vfx-capacity" in OS.get_cmdline_user_args():capacities={"missile":160,"impact":128,"muzzle":24}
 gpu_curves_enabled=RenderingServer.get_current_rendering_method()=="gl_compatibility" and "--cpu-particle-curves" not in OS.get_cmdline_user_args()
 gpu_motion_enabled=gpu_curves_enabled and render_batch==null and "--cpu-particle-motion" not in OS.get_cmdline_user_args()
 var catalog=JSON.parse_string(FileAccess.get_file_as_string(LIB+"index.json"))
 var missile:Dictionary={}
 for entry in catalog:
  if entry.name=="StormMissile":missile=entry;break
 lighting.load_profile(missile.file)
 for pair in [["missile",missile.id],["impact",missile.impact_id],["muzzle",missile.muzzle_id]]:
  var spec:Dictionary={}
  for entry in catalog:
   if entry.id==pair[1]:spec=JSON.parse_string(FileAccess.get_file_as_string(LIB+entry.file));break
  if ordinary_budget:spec=preload("res://scripts/world3d/vfx_budget.gd").ordinary(spec,pair[0])
  pools[pair[0]]=[]
  for i in int(capacities[pair[0]]):
   var fx=FX.new();fx.gpu_curves=gpu_curves_enabled
   fx.gpu_motion=gpu_motion_enabled
   add_child(fx);fx.setup(spec,app.camera,LIB);fx.hide();fx.stopped=true;pools[pair[0]].append(fx)
   if render_batch!=null:fx.render_batch=render_batch;fx.render_kind=pair[0]
  if render_batch!=null:render_batch.register_kind(pair[0],pools[pair[0]][0])
func emit_effect(kind:String,position:Vector3,world_space:=false):
 requested_by_kind[kind]=int(requested_by_kind.get(kind,0))+1
 for fx in pools[kind]:
  if fx.visible:continue
  fx.position=position if world_space else app.world_point(position);fx.scale=Vector3.ONE*.3;fx.last_position=fx.global_position
  fx.age=0;fx.stopped=false;fx.show()
  fx.reset_particles()
  style_effect(fx,Color(1,1,1,0))
  if ordinary_budget:
   var requested:Array=requested_caps(budget_profiles,kind,app.sim.projectiles.active.size())
   if requested!=budget_profiles.ordinary[kind].caps:dense_instances+=1
   var minimum:Array=budget_profiles.minimum[kind].duplicate()
   for i in minimum.size():minimum[i]=mini(int(minimum[i]),int(requested[i]))
   var caps:Array=reservations.acquire(fx,requested,minimum,budget_profiles.reduce_order[kind])
   for i in fx.layers.size():fx.layers[i].instance_particle_limit=caps[i]
  return fx
 dropped_visuals+=1
 dropped_by_kind[kind]=int(dropped_by_kind.get(kind,0))+1
 return null
func clear():
 reservations.clear()
 if render_batch!=null:render_batch.clear()
 bindings.clear();emission_offsets.clear();lighting.clear();app.bridge.combat_lights.clear()
 for pool in pools.values():
  for fx in pool:fx.hide();fx.stopped=true;fx.reset_particles()
func advance(dt:float):
 if not enabled:
  if not disabled_cleared:clear();disabled_cleared=true
  return
 disabled_cleared=false
 if render_batch!=null:render_batch.begin_frame(app.camera)
 var alive:Dictionary={}
 var bound_effects:Dictionary={}
 var muzzle_origins:Dictionary={}
 var flight_positions:Array=[]
 for shot in app.sim.projectiles.active:
  alive[shot.id]=true
  if not bindings.has(shot.id):
   var origin:Vector3=app.world_point(shot.origin)
   var actor=app.source_actor(shot.source_id,shot.enemy)
   var offset:=Vector3.ZERO
   if app.portrait_mode and actor!=null:
    offset=actor.portrait_presenter.presented_attachment(origin,app.camera)-origin
   emission_offsets[shot.id]=offset
   bindings[shot.id]=emit_effect("missile",origin+offset,true)
   if shot.get("payload",{}).has("color"):style_effect(bindings[shot.id],Color(shot.payload.color))
   # A volley has one casting flash at its shared attachment, not one overlapping
   # copy per projectile. Distinct emitters/positions still get distinct flashes.
   var muzzle_key:Array=[shot.source_id,shot.enemy,origin+offset]
   if not muzzle_origins.has(muzzle_key):
    muzzle_origins[muzzle_key]=true;emit_effect("muzzle",origin+offset,true)
   else:shared_muzzles+=1
  var position:Vector3=app.world_point(shot.previous.lerp(shot.pos,clampf(app.step_clock/.05,0,1)))
  # Converge to the physical trajectory within 0.8 m; damage and impact remain
  # entirely on the swept 3D path, independent of the presentation option.
  var travelled:float=position.distance_to(app.world_point(shot.origin))
  position+=Vector3(emission_offsets[shot.id])*(1-smoothstep(0,.8,travelled))
  flight_positions.append(position)
  var fx=bindings[shot.id]
  if fx!=null:
   fx.position=position
   bound_effects[fx]=true
 for id in bindings.keys():
  if not alive.has(id):
   if bindings[id]!=null:bindings[id].stopped=true
   bindings.erase(id)
   emission_offsets.erase(id)
 var impacts:Array=group_impacts(app.sim.impact_events)
 shared_impacts+=app.sim.impact_events.size()-impacts.size()
 for event in impacts:
  var impact=emit_effect("impact",event.position)
  if event.has("color"):style_effect(impact,Color(event.color))
  lighting.impact(app.world_point(event.position))
 app.sim.impact_events.clear()
 app.bridge.combat_lights.assign(lighting.advance(dt,flight_positions))
 for kind in pools:
  var active_count:=0;var particle_count:=0
  for fx in pools[kind]:
   if not fx.visible:continue
   active_count+=1
   if kind!="missile" and fx.age>.35:fx.stopped=true
   fx.advance(dt)
   if app.profiling:
    for layer in fx.layers:particle_count+=layer.particles.size()
   if fx.finished() and not (kind=="missile" and bound_effects.has(fx)):
    reservations.release(fx);fx.hide();fx.stopped=true
  peak_by_kind[kind]=maxi(int(peak_by_kind.get(kind,0)),active_count)
  particle_peak_by_kind[kind]=maxi(int(particle_peak_by_kind.get(kind,0)),particle_count)
 if render_batch!=null:render_batch.finish_frame()

static func group_impacts(events:Array)->Array:
 # Same-frame hits on the same target within 0.25 world metres share feedback.
 # Keep the first actual contact point; don't move feedback to a synthetic centre.
 var groups:Array=[];var by_target:Dictionary={}
 for event in events:
  var target=event.target
  var contacts:Array=by_target.get(target,[])
  var shared:=false
  for contact in contacts:
   if contact.position.distance_squared_to(event.position)<=.625*.625:
    shared=true;break
  if shared:continue
  groups.append(event);contacts.append(event);by_target[target]=contacts
 return groups

func style_effect(fx,color:Color):
 if fx==null:return
 for layer in fx.layers:layer.material.set_shader_parameter("role_color",color)
