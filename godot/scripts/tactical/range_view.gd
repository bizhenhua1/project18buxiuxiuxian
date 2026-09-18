extends Node3D
const RANGE=preload("res://scripts/tactical/range.gd")
var stage
var floor_view:MeshInstance3D
var wall_view:MeshInstance3D
var rings:MultiMeshInstance3D
var floor_material:ShaderMaterial
var wall_material:ShaderMaterial
var last_origin:=Vector3(INF,INF,INF)
var last_spec:Dictionary={}
var last_build:=-1000
var affected:Array[int]=[]
func material(kind:int)->ShaderMaterial:
 var m:=ShaderMaterial.new();m.shader=preload("res://scripts/tactical/range_surface.gdshader");m.set_shader_parameter("surface_kind",kind);return m
func setup(owner_stage):
 stage=owner_stage
 floor_view=MeshInstance3D.new();wall_view=MeshInstance3D.new();add_child(floor_view);add_child(wall_view)
 floor_material=material(0);wall_material=material(1);floor_view.material_override=floor_material;wall_view.material_override=wall_material
 for node in [floor_view,wall_view]:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 rings=MultiMeshInstance3D.new();add_child(rings);rings.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var mesh:=PlaneMesh.new();mesh.size=Vector2(2,2)
 var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh;multi.instance_count=50;multi.visible_instance_count=0;rings.multimesh=multi;rings.material_override=material(2)
 hide()
func point(origin:Vector3,local:Vector3)->Vector3:return stage.world_point(origin+local)+Vector3.UP*.055
func vertex(tool:SurfaceTool,p:Vector3,uv:Vector2):tool.set_uv(uv);tool.add_vertex(p)
func rebuild(origin:Vector3,spec:Dictionary):
 var center:=RANGE.center(origin,spec)
 var width:float=spec.width if spec.shape=="line" else spec.radius*2
 var length:float=spec.length if spec.shape=="line" else spec.radius*2
 var start:float=-length if spec.shape=="line" else -length*.5
 var nx:int=maxi(2,ceili(width));var nz:int=maxi(2,ceili(length))
 var floor_tool:=SurfaceTool.new();floor_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in nz:
  for x in nx:
   for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
    var uv:=Vector2((x+corner.x)/nx,(z+corner.y)/nz)
    vertex(floor_tool,point(center,Vector3((uv.x-.5)*width,0,start+uv.y*length)),uv)
 floor_view.mesh=floor_tool.commit()
 floor_material.set_shader_parameter("circular",spec.shape!="line");floor_material.set_shader_parameter("extent",Vector2(width,length)*.4)
 var border:=RANGE.boundary(origin,spec);var wall_tool:=SurfaceTool.new();wall_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for i in border.size()-1:
  var count:int=maxi(1,ceili(border[i].distance_to(border[i+1])))
  for j in count:
   var a:Vector3=stage.world_point(border[i].lerp(border[i+1],float(j)/count))+Vector3.UP*.055
   var b:Vector3=stage.world_point(border[i].lerp(border[i+1],float(j+1)/count))+Vector3.UP*.055
   for item in [[a,Vector2(0,0)],[b,Vector2(1,0)],[b+Vector3.UP*.65,Vector2(1,1)],[a,Vector2(0,0)],[b+Vector3.UP*.65,Vector2(1,1)],[a+Vector3.UP*.65,Vector2(0,1)]]:vertex(wall_tool,item[0],item[1])
 wall_view.mesh=wall_tool.commit();last_origin=origin;last_spec=spec.duplicate(true);last_build=Time.get_ticks_msec()
func sync(origin:Vector3,spec:Dictionary,enabled:bool,mark_units:bool=true):
 visible=enabled;affected.clear()
 if not enabled:rings.multimesh.visible_instance_count=0;return
 if spec!=last_spec or (origin.distance_to(last_origin)>.02 and Time.get_ticks_msec()-last_build>=100):rebuild(origin,spec)
 var color:=Color(spec.get("color","80dbb8"))
 floor_material.set_shader_parameter("tint",color);wall_material.set_shader_parameter("tint",color)
 wall_view.visible=bool(spec.get("wall",true))
 if not mark_units:rings.multimesh.visible_instance_count=0;return
 var friends:bool=spec.get("target","")=="ally"
 var targets:Array=stage.sim.allies if friends else stage.sim.enemies
 if spec.get("effect","")=="needle":targets=stage.sim.roles.candidates({"role":"needle","pos":origin,"range":spec.radius}).slice(0,3)
 for e in targets:
  if e.hp<=0 or e.get("resolved",false) or stage.sim.clock<float(e.get("activate_at",0)) or not RANGE.contains(origin,e.pos,spec):continue
  if friends and not stage.sim.alive(e):continue
  if spec.get("target","")=="taunt":
   if e.get("blocked_by",-1)>=0 or abs(preload("res://scripts/tactical/engagements.gd").column(stage.sim,e.pos.x)-preload("res://scripts/tactical/engagements.gd").column(stage.sim,origin.x))!=1:continue
  if affected.size()>=50:break
  # Ground contact stays on the ground even for an enemy falling from above.
  var ground:Vector3=e.pos;ground.y=0
  var p:Vector3=stage.world_point(ground)+Vector3.UP*.075
  var radius:float=clampf(.32*float(e.get("body_scale",1)),.28,.85)
  var xp:Vector3=stage.world_point(ground+Vector3(radius/.4,0,0));var zp:Vector3=stage.world_point(ground+Vector3(0,0,radius/.4))
  var xaxis:Vector3=(xp-(p-Vector3.UP*.075)).normalized();var zaxis:Vector3=(zp-(p-Vector3.UP*.075)).normalized()
  var normal:=zaxis.cross(xaxis).normalized()
  if normal.y<0:normal=-normal
  rings.multimesh.set_instance_transform(affected.size(),Transform3D(Basis(xaxis*radius,normal,zaxis*radius),p));affected.append(e.id)
 rings.multimesh.visible_instance_count=affected.size()
