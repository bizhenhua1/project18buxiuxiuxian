extends Node3D
# Experimental depth-sliced renderer. Simulation and emitter ownership stay in FX.
const FIRST=-2
const LAST=18
const WIDTH=4.0
const CAPACITY=1024
var groups:Dictionary={}
var camera:Camera3D
var view_inverse:=Transform3D.IDENTITY
var dropped:=0
func register_kind(kind:String,fx):
 for i in fx.layers.size():
  var source=fx.layers[i]
  var material:Material=fx.get_child(i).material_override
  for bucket in range(FIRST,LAST):
   var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=source.mm.mesh;mm.instance_count=CAPACITY;mm.visible_instance_count=0
   mm.custom_aabb=AABB(Vector3.ONE*-100,Vector3.ONE*200)
   var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.material_override=material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.sorting_offset=-i*.001;add_child(node)
   groups[kind+":"+str(i)+":"+str(bucket)]={"node":node,"mm":mm,"cursor":0,"bucket":bucket}
func begin_frame(cam:Camera3D):
 camera=cam;view_inverse=cam.global_transform.affine_inverse()
 for group in groups.values():
  group.cursor=0
  group.node.global_position=cam.global_position-cam.global_basis.z*(float(group.bucket)+.5)*WIDTH
func target(kind:String,index:int,origin:Vector3):
 var bucket:=int(floor(-(view_inverse*origin).z/WIDTH))
 return groups.get(kind+":"+str(index)+":"+str(bucket))
func finish_frame():
 for group in groups.values():group.mm.visible_instance_count=group.cursor
func clear():
 for group in groups.values():group.cursor=0;group.mm.visible_instance_count=0
