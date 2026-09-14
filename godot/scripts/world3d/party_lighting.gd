extends Node3D
const INK=preload("res://scripts/battle/character_ink_material.gd")
var entries:Array=[]
func set_layer(node:Node,mask:int):
 if node is GeometryInstance3D:node.layers=mask
 for child in node.get_children():set_layer(child,mask)
func setup(actors:Array):
 for i in actors.size():
  # Character-only masks keep saved portrait fill off scenery and other party members.
  var mask:int=1<<(i+2)
  set_layer(actors[i],mask)
  var key:=OmniLight3D.new();key.light_cull_mask=mask;key.shadow_enabled=false;add_child(key)
  var rim:=DirectionalLight3D.new();rim.light_cull_mask=mask;rim.shadow_enabled=false;add_child(rim)
  entries.append({"actor":actors[i],"key":key,"rim":rim,"fill":-1.0,"color":Color.TRANSPARENT})
func sync(data:Dictionary,tint:Color,heading:float):
 var orientation:=Basis(Vector3.UP,-heading)
 for entry in entries:
  var actor=entry.actor
  entry.key.visible=actor.visible;entry.rim.visible=actor.visible
  if not actor.visible:continue
  var size:float=actor.scale.x
  entry.key.global_position=actor.global_position+orientation*Vector3(data.x,data.y,data.z)*size
  entry.key.light_energy=data.energy;entry.key.omni_range=data.range*size;entry.key.light_color=data.color*tint
  entry.rim.rotation_degrees=Vector3(-30,-25-rad_to_deg(heading),0)
  entry.rim.light_color=Color("829cab")*tint;entry.rim.light_energy=data.rim
  var color:Color=Color("98afbf")*tint
  if entry.fill!=data.ambient or entry.color!=color:
   INK.set_environment_fill(actor.body,data.ambient,color);entry.fill=data.ambient;entry.color=color
