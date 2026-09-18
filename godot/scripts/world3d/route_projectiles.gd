extends Node3D
## Read-only adapter: BattleModel owns launch times, age, resolution and damage.
const P=preload("res://scripts/world3d/projection.gd")
var camera:Camera3D
var bridge:SegmentRenderer
var arena:BattleArena
var models
var portrait_mode:=false
var profiling:=false
var step_clock:=.05
var sim:Dictionary={"projectiles":{"active":[]},"impact_events":[]}
var effects
var tracked:Array=[]
var next_id:=0
var generation:=-1
var dropped_tracks:=0
var beams:ImmediateMesh
var beam_node:MeshInstance3D
var beam_material:StandardMaterial3D
func setup(source:BattleArena,view:Camera3D,presenters):
 arena=source;camera=view;bridge=arena.scenery.renderer;models=presenters
 effects=preload("res://scripts/world3d/projectile_view.gd").new();add_child(effects)
 effects.capacities={"missile":32,"impact":24,"muzzle":8};effects.ordinary_budget=true;effects.setup(self)
 beams=ImmediateMesh.new();beam_node=MeshInstance3D.new();beam_node.mesh=beams;add_child(beam_node)
 beam_material=StandardMaterial3D.new();beam_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 beam_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;beam_material.vertex_color_use_as_albedo=true
 beam_material.cull_mode=BaseMaterial3D.CULL_DISABLED;beam_material.blend_mode=BaseMaterial3D.BLEND_MODE_ADD
 beam_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 arena.model.emitted.connect(on_event)
func _exit_tree():
 if arena and arena.model.emitted.is_connected(on_event):arena.model.emitted.disconnect(on_event)
func world_point(value:Vector3)->Vector3:return value
func source_actor(_uid:int,_enemy:bool):return null
func anchor(uid:int)->Vector3:
 var sprite:Dictionary=models.samples.get(200000+uid,{})
 if sprite.is_empty():return models.bridge.bodies.get(uid,{}).get("position",Vector3.ZERO)+Vector3.UP*.7
 return P.point(sprite.position,ForestEcology.height_at(sprite.position)+float(sprite.get("altitude",0))+float(sprite.h)*.52)
func on_event(event:Dictionary):
 if event.type!="shot" or event.get("style","")=="melee" or event.from.get("sword_combo",false):return
 if generation!=arena.model.result_generation:reset()
 if tracked.size()>=256:dropped_tracks+=1;return
 # Keep the original dictionary reference to observe the authoritative resolved flag.
 tracked.append({"id":next_id,"shot":event,"origin":anchor(event.from.uid),"impact":false})
 next_id+=1
func reset():
 tracked.clear();effects.clear();sim.projectiles.active.clear();sim.impact_events.clear()
 generation=arena.model.result_generation;beams.clear_surfaces()
func sync(dt:float):
 if generation!=arena.model.result_generation:reset()
 sim.projectiles.active.clear();beams.clear_surfaces()
 var lines:Array=[];var remaining:Array=[]
 for entry in tracked:
  var shot:Dictionary=entry.shot
  if not shot.get("resolved",false) and not arena.model.shots.has(shot):continue
  var destination:=anchor(int(shot.to.uid))
  var color:Color=OccultEffects.color_for(shot.from)
  if shot.get("resolved",false) and not entry.impact:
   sim.impact_events.append({"position":destination,"target":int(shot.to.uid),"color":color});entry.impact=true
  if shot.age>=shot.duration:continue
  remaining.append(entry)
  var t:float=clampf(shot.age/shot.duration,0,1)
  if shot.style=="beam":
   if lines.size()<32:lines.append({"a":entry.origin,"b":destination,"color":Color(color,smoothstep(0,.12,t)*(1-smoothstep(.72,1,t)))})
  elif sim.projectiles.active.size()<32:
   var point:Vector3=entry.origin.lerp(destination,t)
   sim.projectiles.active.append({"id":entry.id,"origin":entry.origin,"pos":point,"previous":point,"source_id":int(shot.from.uid),"enemy":shot.from.side=="enemy","payload":{"color":color}})
 tracked=remaining
 if not lines.is_empty():
  beams.surface_begin(Mesh.PRIMITIVE_TRIANGLES,beam_material)
  for line in lines:
   var normal:Vector3=(line.b-line.a).cross(camera.global_basis.z).normalized()*.025
   for point in [line.a-normal,line.a+normal,line.b+normal,line.a-normal,line.b+normal,line.b-normal]:
    beams.surface_set_color(line.color);beams.surface_add_vertex(point)
  beams.surface_end()
 effects.advance(dt)
