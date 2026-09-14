extends RefCounted
var values:=PackedFloat32Array()
func _init(capacity:int):values.resize(capacity*20)
func write(index:int,transform:Transform3D,color:Color,custom:Color):
 var offset:=index*20;var b:=transform.basis;var p:=transform.origin
 values[offset]=b.x.x;values[offset+1]=b.y.x;values[offset+2]=b.z.x;values[offset+3]=p.x
 values[offset+4]=b.x.y;values[offset+5]=b.y.y;values[offset+6]=b.z.y;values[offset+7]=p.y
 values[offset+8]=b.x.z;values[offset+9]=b.y.z;values[offset+10]=b.z.z;values[offset+11]=p.z
 values[offset+12]=color.r;values[offset+13]=color.g;values[offset+14]=color.b;values[offset+15]=color.a
 values[offset+16]=custom.r;values[offset+17]=custom.g;values[offset+18]=custom.b;values[offset+19]=custom.a
