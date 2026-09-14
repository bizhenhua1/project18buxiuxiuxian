extends MultiMeshInstance3D
const PUFFS:=12
const DURATION:=1.35
var entries:Array=[]
var age:=0.0
func setup(capacity:int):
 var material:=ShaderMaterial.new()
 material.shader=preload("res://shaders/island_fog_particle.gdshader")
 material.render_priority=-80
 var quad:=QuadMesh.new();quad.material=material
 multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D
 multimesh.use_colors=true;multimesh.mesh=quad;multimesh.instance_count=capacity*PUFFS
 multimesh.visible_instance_count=0
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func clear():
 entries.clear();age=0;multimesh.visible_instance_count=0
func begin(stage):
 clear()
 var actors:Array=stage.team.duplicate()
 for slot in stage.enemy_pool:
  if slot.actor.visible:actors.append(slot.actor)
 for actor in actors:
  if not actor.visible:continue
  var delay:=0.0
  if actor.dead and actor.clip in actor.library.clips:
   var clip:Dictionary=actor.library.clips[actor.clip]
   delay=maxf(0,float(clip.frames-1)/clip.fps-actor.clock)
  entries.append({"node":actor,"actor":true,"origin":actor.position,"delay":delay,"alpha":actor.opacity,"height":(.4 if actor.dead else 2.6)*actor.scale.y})
 for item in stage.props:
  if item.node.modulate.a>.001:entries.append({"node":item.node,"actor":false,"origin":item.node.position,"delay":0.0,"alpha":item.node.modulate.a,"height":.7})
func advance(dt:float,camera:Camera3D):
 if entries.is_empty():return
 age+=dt
 var count:=0
 for entry in entries:
  entry.node.position=entry.origin
  var time:float=maxf(0,age-entry.delay)
  var opacity:float=entry.alpha*(1-smoothstep(.12,1.05,time))
  if entry.actor:entry.node.set_opacity(opacity)
  else:entry.node.modulate.a=opacity
  if time<=0 or time>=DURATION:continue
  var fraction:float=time/DURATION
  for puff in PUFFS:
   if count>=multimesh.instance_count:break
   var angle:float=puff*TAU/PUFFS+float(count)*.17
   var radius:float=.12+fraction*.7
   var position:Vector3=entry.origin+Vector3(cos(angle)*radius,.1+float(puff%4)/3*entry.height*.8+fraction*.55+sin(puff*2.3)*.12,sin(angle)*radius)
   var size:float=.3+fraction*.6
   multimesh.set_instance_transform(count,Transform3D(camera.global_basis.scaled(Vector3.ONE*size),position))
   multimesh.set_instance_color(count,Color(1,1,1,sin(PI*fraction)*.7))
   count+=1
 multimesh.visible_instance_count=count
