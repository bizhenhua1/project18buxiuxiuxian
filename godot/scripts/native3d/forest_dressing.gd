extends RefCounted
## Native counterpart of the accepted forest ecology: groves, mixed groundcover, root skirts.
var rng:=RandomNumberGenerator.new()
var batches:Dictionary={}
var app:Node3D
func road_distance(x:float,z:float) -> float:
 var center:=.35*sin(z*.14)
 var result:=absf(x-center)
 if z< -40:result=minf(result,minf(absf(x-(-z-40)*.5),absf(x+(-z-40)*.5)))
 return result
func add(key:String,x:float,z:float,height:float) -> void:
 if not batches.has(key):batches[key]=[]
 var mirror:float=-1 if rng.randf()<.5 else 1
 batches[key].append(Transform3D(Basis.from_scale(Vector3(height*mirror,height,height)),Vector3(x,app.ground(x,z),z)))
func populate(owner:Node3D) -> void:
 app=owner;rng.seed=48119
 # Trees occupy irregular groups near both verges, with small specimens between old trunks.
 for i in range(1150):
  var z:=rng.randf_range(-90,12);var x:=rng.randf_range(-22,22)
  var key:="tree-a" if rng.randf()<.5 else "tree-b"
  var h:=rng.randf_range(3.6,6.1) if rng.randf()<.30 else rng.randf_range(7.0,11.8)
  var clearance:=2.75+.35*sin(z*.22)+h*.09
  if road_distance(x,z)<clearance:continue
  add(key,x,z,h)
  # Ground-level cover belongs to each tree, with slight forward offsets instead of floating roots.
  for j in range(5):
   add(["fern","clover","short-grass"][rng.randi_range(0,2)],x+(j-2)*h*.05,z+rng.randf_range(.08,.26),rng.randf_range(.25,.55))
 var mixed:=["fern","clover","shrub","short-grass","reeds"]
 for i in range(800):
  var z:=rng.randf_range(-90,12);var x:=rng.randf_range(-12,12)
  var fern_grove:=rng.randf()<.5
  for j in range(rng.randi_range(4,10)):
   var px:=x+rng.randf_range(-1.1,1.1);var pz:=z+rng.randf_range(-1.1,1.1)
   var d:=road_distance(px,pz)
   var key:String="short-grass" if d<1.0 else "fern" if fern_grove and rng.randf()<.5 else mixed[rng.randi_range(0,4)]
   add(key,px,pz,rng.randf_range(.12,.28) if d<1.2 else rng.randf_range(.3,.75))
  if road_distance(x,z)>2.8 and rng.randf()<.2:add("stump" if fern_grove else "rocks",x,z,rng.randf_range(.35,.65))
 for i in range(900):
  var z:=rng.randf_range(-90,12);var x:=rng.randf_range(-2.8,2.8)
  add("short-grass" if rng.randf()<.7 else "litter",x,z,rng.randf_range(.13,.30))
 var marks:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/forest_asset_anchors.json"))
 for key in batches:
  var texture:Texture2D=load("res://assets/style2/"+key+".png")
  var ratio:=float(texture.get_width())/texture.get_height()
  var anchor:Vector2=Vector2(marks[key].ground_anchor[0],marks[key].ground_anchor[1]) if marks.has(key) else Vector2(.5,1)
  var quad:=QuadMesh.new();quad.size=Vector2(ratio,1);quad.center_offset=Vector3((.5-anchor.x)*ratio,anchor.y-.5,0)
  var mat:StandardMaterial3D=app.material("res://assets/style2/"+key+".png")
  mat.albedo_color=Color(.78,.84,.86)
  var image:=texture.get_image();image.generate_mipmaps()
  mat.albedo_texture=ImageTexture.create_from_image(image)
  mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  quad.material=mat
  var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=quad;mm.instance_count=batches[key].size()
  for i in range(mm.instance_count):mm.set_instance_transform(i,batches[key][i])
  var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;app.add_child(node)
 # Local pockets, with clear space between them. Real depth testing against units and trees.
 for i in range(62):
  var mist:=Sprite3D.new();mist.texture=load("res://assets/style2/mist.png");mist.pixel_size=rng.randf_range(.004,.008)
  mist.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;mist.shaded=false
  mist.modulate=Color(.38,.49,.54,rng.randf_range(.20,.34))
  mist.position=Vector3(rng.randf_range(-6.5,6.5),rng.randf_range(.12,.48),rng.randf_range(-85,5))
  app.add_child(mist);app.fogs.append(mist)
