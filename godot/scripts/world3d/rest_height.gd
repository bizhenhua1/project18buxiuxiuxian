extends RefCounted
# Bake bind-pose vertex height in the model body's local frame. Neither the
# actor's world position nor its crawling rotation defines the health threshold.
static func collect(node:Node,meshes:Array):
 if node is BoneAttachment3D:return
 if node is MeshInstance3D and node.mesh!=null:meshes.append(node)
 for child in node.get_children():collect(child,meshes)
static func bake(body:Node3D)->Dictionary:
 var meshes:Array=[];collect(body,meshes)
 var bottom:=INF;var top:=-INF;var frames:Array[Transform3D]=[]
 var inverse:Transform3D=body.global_transform.affine_inverse()
 for mesh in meshes:
  var frame:Transform3D=inverse*mesh.global_transform;frames.append(frame)
  var bounds:AABB=mesh.mesh.get_aabb()
  for corner in 8:
   var point:Vector3=frame*bounds.get_endpoint(corner)
   bottom=minf(bottom,point.y);top=maxf(top,point.y)
 if meshes.is_empty():return {}
 for i in meshes.size():preload("res://scripts/spaces/transformation_height.gd").bake(meshes[i],bottom,top,frames[i])
 return {"bottom":bottom,"top":top,"mesh_count":meshes.size()}
