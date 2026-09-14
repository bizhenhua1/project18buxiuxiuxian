extends RefCounted
var actors:Array=[]
var skipped_passes:=0
func scan(node:Node,actor,links:Array):
 if node is MeshInstance3D:
  for i in node.mesh.get_surface_count():
   var source=node.get_active_material(i)
   if not source is ShaderMaterial or not source.next_pass is ShaderMaterial:continue
   var outline:ShaderMaterial=source.next_pass
   if not "outline" in outline.shader.resource_path:continue
   var width:float=outline.get_shader_parameter("width")
   var scale:Vector3=node.global_transform.basis.get_scale().abs()
   var actor_scale:Vector3=actor.global_transform.basis.get_scale().abs()
   var relative:float=scale[scale.max_axis_index()]/maxf(.0001,actor_scale[actor_scale.max_axis_index()])
   links.append({"source":source,"outline":outline,"width":width,"current_width":width,"extrusion":width*relative})
 for child in node.get_children():scan(child,actor,links)
func setup(units:Array):
 for actor in units:
  var links:Array=[];scan(actor.body,actor,links)
  var minimum:=INF;var maximum:=0.0
  for link in links:minimum=minf(minimum,link.extrusion);maximum=maxf(maximum,link.extrusion)
  actors.append({"actor":actor,"links":links,"minimum":minimum,"maximum":maximum,"band":-1,"tail":null})
func sync(camera:Camera3D,size:Vector2,weak:bool,enabled:=true):
 skipped_passes=0
 var focal:float=absf(camera.get_camera_projection().y.y)*size.y*.5
 for group in actors:
  var actor=group.actor
  if not actor.visible:continue
  var scale:Vector3=actor.global_transform.basis.get_scale().abs()
  var largest:float=scale[scale.max_axis_index()]
  var depth:float=-camera.to_local(actor.global_position).z
  if not weak:depth-=1.8*largest
  var factor:float=largest*focal/maxf(.05,depth)
  var band:int=2 if not enabled or group.minimum*factor>=.65 else 0 if group.maximum*factor<=.25 else 1
  var tail:Material=group.links[0].outline.next_pass if not group.links.is_empty() else null
  if band!=1 and group.band==band and group.tail==tail:
   if band==0:skipped_passes+=group.links.size()
   continue
  group.band=band;group.tail=tail
  for link in group.links:
   var pixels:float=link.extrusion*factor
   var weight:float=smoothstep(.25,.65,pixels) if enabled else 1.0
   var width:float=link.width*weight
   if link.current_width!=width:link.outline.set_shader_parameter("width",width);link.current_width=width
   # Keep the atmosphere tail even while bypassing an invisible outline.
   var next:Material=link.outline if weight>.001 else link.outline.next_pass
   if link.source.next_pass!=next:link.source.next_pass=next
   if weight<=.001:skipped_passes+=1
