extends RefCounted
# Experimental same-camera diagnostic, never called by the live game.
static func apply(stage)->Dictionary:
 var boundaries:Array=[]
 var camera:Camera3D=stage.camera
 var view:Transform3D=camera.global_transform.affine_inverse()
 for item in stage.props:boundaries.append(-(view*item.node.position).z)
 boundaries.sort()
 var replaced:=0;var added:=0;var copied:=0
 var result_nodes:Array=[]
 for chunk in stage.scenery.chunks:
  if not chunk.visible:continue
  var box:AABB=chunk.multimesh.custom_aabb
  var touches:=false
  for item in stage.props:
   var p:Vector3=item.node.position
   var width:float=item.node.texture.get_width()*item.node.pixel_size*.5
   if box.end.x>=p.x-width and box.position.x<=p.x+width and box.position.z<=p.z and box.end.z>=p.z:touches=true;break
  if not touches:continue
  var source:MultiMesh=chunk.multimesh
  var bands:Dictionary={}
  for i in source.instance_count:
   var t:Transform3D=source.get_instance_transform(i)
   var depth:float=-(view*t.origin).z
   var band:=0
   while band<boundaries.size() and depth>boundaries[band]:band+=1
   if not bands.has(band):bands[band]=[]
   bands[band].append(i)
  if bands.size()<2:continue
  replaced+=1;chunk.hide()
  for indices in bands.values():
   var center:=Vector3.ZERO
   for i in indices:center+=source.get_instance_transform(i).origin
   center/=indices.size()
   var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true
   mm.mesh=source.mesh;mm.instance_count=indices.size()
   for j in indices.size():
    var i:int=indices[j];var t:Transform3D=source.get_instance_transform(i);t.origin-=center
    mm.set_instance_transform(j,t);mm.set_instance_color(j,source.get_instance_color(i));mm.set_instance_custom_data(j,source.get_instance_custom_data(i))
   mm.custom_aabb=AABB(box.position-center,box.size)
   var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.position=center
   node.sorting_use_aabb_center=false
   node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   stage.scenery.add_child(node);result_nodes.append(node)
   added+=1;copied+=indices.size()
 return {"replaced_batches":replaced,"replacement_batches":added,"additional_draw_candidates":added-replaced,"copied_instances":copied}
