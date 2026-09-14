extends RefCounted
static func coarse(source:ArrayMesh,columns:int)->ArrayMesh:
 var arrays:=source.surface_get_arrays(0)
 var rows:int=arrays[Mesh.ARRAY_VERTEX].size()/columns
 var xs:Array[int]=[];var ys:Array[int]=[0,1]
 for x in range(0,columns,2):xs.append(x)
 if xs.back()!=columns-1:xs.append(columns-1)
 for y in range(3,rows,2):ys.append(y)
 if ys.back()!=rows-1:ys.append(rows-1)
 var indices:=PackedInt32Array()
 for y in ys.size()-1:
  for x in xs.size()-1:
   var a:int=ys[y]*columns+xs[x];var b:int=ys[y]*columns+xs[x+1]
   var c:int=ys[y+1]*columns+xs[x];var d:int=ys[y+1]*columns+xs[x+1]
   indices.append_array(PackedInt32Array([a,b,c,b,d,c]))
 arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 mesh.surface_set_material(0,source.surface_get_material(0))
 return mesh
static func distant(box:AABB,origin:Vector2,heading:float,was_far:bool)->bool:
 var center:=box.get_center();var half:=box.size*.5
 var relative:=ForestRoute.to_camera(Vector2(center.x,-center.z)*20,origin,heading)
 var extent:float=(absf(sin(heading))*half.x+absf(cos(heading))*half.z)*20
 return relative.y-extent>(1000.0 if was_far else 1200.0)
