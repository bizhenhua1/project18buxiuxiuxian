extends Node3D
## Reusable bounded effects. Geometry, shader noise and mesh particles only.
signal impacted(kind: String)
var trail:MeshInstance3D
var fire:MeshInstance3D
var wake:MeshInstance3D
var blast:MeshInstance3D
var sparks:CPUParticles3D
var embers:CPUParticles3D
var light:OmniLight3D
var samples:Array[Dictionary]=[]
var time:=0.0
var flight:=false
var flight_age:=0.0
var flight_seconds:=.85
var origin:=Vector3.ZERO
var target:=Vector3.ZERO
var impact_age:=10.0
var impact_kind:=""
func material(ribbon:bool=false)->ShaderMaterial:
 var m:=ShaderMaterial.new();m.shader=preload("res://shaders/vfx_ember.gdshader");m.set_shader_parameter("ribbon",ribbon);return m
func _ready():
 trail=MeshInstance3D.new();trail.mesh=ImmediateMesh.new();trail.material_override=material(true);trail.material_override.set_shader_parameter("hot_color",Color("f4dfaf"));trail.material_override.set_shader_parameter("dark_color",Color("514939"));add_child(trail)
 fire=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=.22;ball.height=.44;ball.radial_segments=32;ball.rings=16;fire.mesh=ball;fire.material_override=material();fire.visible=false;add_child(fire)
 wake=MeshInstance3D.new();wake.material_override=material(true);wake.material_override.set_shader_parameter("flame_tail",true);wake.visible=false;add_child(wake)
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for fin in 3:
  var side:=Vector3(cos(fin*PI/3),sin(fin*PI/3),0)
  for i in range(16):
   for v in [[i,0],[i,1],[i+1,1],[i,0],[i+1,1],[i+1,0]]:
    var u:float=v[0]/16.0;var width:=.22*pow(1-u,.8)
    st.set_uv(Vector2(u,float(v[1])));st.add_vertex(Vector3(0,sin(u*PI)*.12,u*1.25)+side*(float(v[1])*2-1)*width)
 wake.mesh=st.commit()
 blast=MeshInstance3D.new();blast.mesh=ball;blast.material_override=material();blast.visible=false;add_child(blast)
 sparks=emitter(32,.48);embers=emitter(48,.42);embers.explosiveness=0;embers.one_shot=false;embers.initial_velocity_min=.1;embers.initial_velocity_max=.35;embers.gravity=Vector3(0,.45,0)
 light=OmniLight3D.new();light.omni_range=2.8;light.light_color=Color("ff983e");light.light_energy=0;light.shadow_enabled=false;add_child(light)
func emitter(count:int,lifetime:float)->CPUParticles3D:
 var p:=CPUParticles3D.new();p.amount=count;p.lifetime=lifetime;p.one_shot=true;p.explosiveness=1;p.emitting=false;p.local_coords=false
 var mesh:=SphereMesh.new();mesh.radius=.018;mesh.height=.06;mesh.radial_segments=6;mesh.rings=3
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mesh.material=mat;p.mesh=mesh
 p.direction=Vector3(0,1,0);p.spread=160;p.initial_velocity_min=1;p.initial_velocity_max=3;p.gravity=Vector3(0,-3.5,0);p.scale_amount_min=.45;p.scale_amount_max=1.2
 var gradient:=Gradient.new();gradient.set_color(0,Color("ffd28a"));gradient.add_point(.35,Color("d57939"));gradient.set_color(1,Color(0.2,.12,.08,0));p.color_ramp=gradient
 add_child(p);return p
func blade(base:Vector3,tip:Vector3):
 samples.append({"base":base,"tip":tip,"time":time})
 if samples.size()>18:samples.pop_front()
func launch(start:Vector3,finish:Vector3,seconds:float=.85):
 origin=start;target=finish;flight_seconds=maxf(seconds,.1);flight_age=0;flight=true;fire.visible=true;fire.position=start
 embers.position=start;embers.restart();embers.emitting=true
func impact(at:Vector3,kind:String):
 impact_age=0;impact_kind=kind;blast.position=at;blast.visible=true
 blast.material_override.set_shader_parameter("hot_color",Color("ffc176") if kind=="fire" else Color("e4d4af"))
 blast.material_override.set_shader_parameter("dark_color",Color("6c1d0b") if kind=="fire" else Color("292c2b"))
 sparks.position=at;sparks.restart();sparks.emitting=true;impacted.emit(kind)
func _process(dt:float):
 time+=dt
 while not samples.is_empty() and time-float(samples[0].time)>.16:samples.pop_front()
 trail.visible=samples.size()>1
 if trail.visible:
  var geometry:ImmediateMesh=trail.mesh;geometry.clear_surfaces();geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
  for i in range(1,samples.size()):
   for entry in [[i-1,0],[i-1,1],[i,1],[i-1,0],[i,1],[i,0]]:
    var s:Dictionary=samples[entry[0]];var u:=1.0-(time-float(s.time))/.16
    geometry.surface_set_uv(Vector2(u,float(entry[1])));geometry.surface_add_vertex(s.base if entry[1]==0 else s.tip)
  geometry.surface_end()
 if flight:
  flight_age+=dt;var t:=minf(1,flight_age/flight_seconds)
  fire.position=origin.lerp(target,t)+Vector3.UP*sin(t*PI)*.18
  fire.material_override.set_shader_parameter("age",time);fire.rotation.z=time*3
  wake.visible=true;wake.position=fire.position;wake.look_at(target+(target-origin).normalized());wake.material_override.set_shader_parameter("age",time)
  embers.position=fire.position;light.position=fire.position;light.light_energy=.7
  if t>=1:flight=false;fire.visible=false;wake.visible=false;embers.emitting=false;impact(target,"fire")
 impact_age+=dt
 if impact_age<.5:
  var t:=impact_age/.5;blast.visible=true;blast.scale=Vector3.ONE*(1+t*(3.8 if impact_kind=="fire" else 1.8));blast.material_override.set_shader_parameter("age",time);blast.material_override.set_shader_parameter("opacity",pow(1-t,2))
  if impact_kind=="fire":light.position=blast.position;light.light_energy=(1-t)*1.1
 else:
  blast.visible=false
  if not flight:light.light_energy=0
