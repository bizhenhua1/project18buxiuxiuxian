extends RefCounted
static func base_contact_mesh(profile:PackedFloat32Array=PackedFloat32Array())->ArrayMesh:
 var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
 var columns:=17
 for row in 5:
  for x in columns:
   var foot:float=profile[x] if profile.size()==columns else .97
   var v:float=[0.0,maxf(0.0,foot-.24),maxf(0.0,foot-.08),foot,1.0][row]
   var u:=float(x)/(columns-1);vertices.append(Vector3(u-.5,.5-v,0));uv.append(Vector2(u,v))
 for y in 4:
  for x in columns-1:
   var a:=y*columns+x;indices.append_array(PackedInt32Array([a,a+1,a+columns,a+1,a+columns+1,a+columns]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

static func contact_resolution(size:Vector2)->Vector2i:
 # Shared bounded size buckets: at most 65 columns and 32 added foot intervals.
 # One bucket covers a range of instances rather than a new mesh per plant.
 var segments:=8
 while segments<64 and float(segments)*.5<absf(size.x):segments*=2
 var depth_steps:=clampi(ceili(absf(size.y)*.4/.25/8.0)*8,8,32)
 return Vector2i(segments+1,depth_steps)
static func contact_mesh(columns:int=9,foot_steps:int=0)->ArrayMesh:
 columns=clampi(columns,2,65);foot_steps=clampi(foot_steps,0,32)
 var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
 var rows:=[0.0,.25,.5,.65,.75,.84,.86,.87,.88,.9,.92,1.0]
 if foot_steps>0:
  # Restrict the extra depth samples to the folded foot, preserving upper art.
  for step_index in range(1,foot_steps):rows.append(lerpf(.75,1.0,float(step_index)/foot_steps))
  rows.sort()
  var unique:Array=[]
  for value in rows:
   if unique.is_empty() or absf(value-float(unique.back()))>.00001:unique.append(value)
  rows=unique
 for v in rows:
  for x in columns:
   var u:=float(x)/(columns-1);vertices.append(Vector3(u-.5,.5-v,0));uv.append(Vector2(u,v))
 for y in range(rows.size()-1):
  for x in columns-1:
   var a:=y*columns+x;indices.append_array(PackedInt32Array([a,a+1,a+columns,a+1,a+columns+1,a+columns]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

static func bounded_resolution(size:Vector2,anchor_y:float,profile:PackedFloat32Array=PackedFloat32Array())->Vector2i:
 var foot:=anchor_y
 if profile.size()==17:
  foot=1.0
  for value in profile:foot=minf(foot,value)
 var depth:float=(1-clampf(foot,.01,.999))*absf(size.y)*1.6
 return Vector2i(contact_resolution(size).x,clampi(ceili(depth/.25),1,32))
static func bounded_contact_mesh(size:Vector2,anchor_y:float,profile:PackedFloat32Array=PackedFloat32Array())->ArrayMesh:
 var resolution:=bounded_resolution(size,anchor_y,profile)
 var columns:int=resolution.x;var steps:int=resolution.y
 var feet:=PackedFloat32Array()
 for x in columns:
  var u:=float(x)/(columns-1);var foot:=anchor_y
  if profile.size()==17:
   var index:=u*16;var left:=mini(15,floori(index))
   foot=lerpf(profile[left],profile[left+1],index-left)
  foot=clampf(foot,.01,.999)
  feet.append(foot)
 var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
 # One upper strip; every remaining row is in the actual folded contact band.
 for row in steps+2:
  for x in columns:
   var u:=float(x)/(columns-1)
   var v:float=0 if row==0 else lerpf(feet[x],1,float(row-1)/steps)
   vertices.append(Vector3(u-.5,.5-v,0));uv.append(Vector2(u,v))
 for row in steps+1:
  for x in columns-1:
   var a:=row*columns+x
   indices.append_array(PackedInt32Array([a,a+1,a+columns,a+1,a+columns+1,a+columns]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);return mesh

static func contact_profile(im:Image) -> PackedFloat32Array:
 # Find the lowest robust opaque pixels, including art whose feet stop well
 # above the image bottom. An arch's high canopy is rejected relative to its
 # real feet; empty doorway columns then borrow the nearest real support.
 var result:=PackedFloat32Array();result.resize(17);result.fill(-1.0)
 for column in range(17):
  var x:=clampi(roundi(column/16.0*(im.get_width()-1)),0,im.get_width()-1)
  for y in range(im.get_height()-1,-1,-1):
   var covered:=0
   for offset in range(-2,3):
    if im.get_pixel(clampi(x+offset,0,im.get_width()-1),y).a>.5:covered+=1
   if covered>=2:
    result[column]=(y+.5)/float(im.get_height())
    break
 var deepest:=0.0
 for foot in result:deepest=maxf(deepest,foot)
 for column in range(17):
  if result[column]<deepest-.18:result[column]=-1.0
 var sampled:=result.duplicate()
 for column in range(17):
  if result[column]>=0:continue
  var nearest:=-1
  for candidate in range(17):
   if sampled[candidate]>=0 and (nearest<0 or abs(candidate-column)<abs(nearest-column)):nearest=candidate
  result[column]=sampled[nearest] if nearest>=0 else 1.0
 return result



