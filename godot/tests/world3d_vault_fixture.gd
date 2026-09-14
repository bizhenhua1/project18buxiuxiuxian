extends RefCounted
# Visual prototype only: a continuous chamber roof behind the original arches.
static func build(route)->MeshInstance3D:
 var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
 for row in 17:
  var s:float=route.junction_s-180+row*180
  for column in 17:
   var t:=float(column)/16
   var lateral:=lerpf(-720,720,t)
   var p:Vector2=route.point(s,0,lateral)
   var height:float=220+180*sin(t*PI)
   vertices.append(Vector3(p.x,ForestEcology.height_at(p)+height,-p.y)/20)
   uvs.append(Vector2(lateral/120,s/120))
 for row in 16:
  for column in 16:
   var a:=row*17+column
   indices.append_array(PackedInt32Array([a,a+1,a+17,a+1,a+18,a+17]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 var shader:=Shader.new()
 shader.code="shader_type spatial; render_mode unshaded,cull_disabled; uniform sampler2D stone:source_color,filter_linear_mipmap,repeat_enable; varying float depth; void vertex(){depth=-(MODELVIEW_MATRIX*vec4(VERTEX,1)).z;} void fragment(){vec3 c=texture(stone,UV).rgb*vec3(.075,.12,.10); ALBEDO=mix(c,vec3(.014,.023,.02),smoothstep(12.,75.,depth));}"
 var material:=ShaderMaterial.new();material.shader=shader;material.set_shader_parameter("stone",load("res://assets/biomes/palace/ground.png"))
 mesh.surface_set_material(0,material)
 var node:=MeshInstance3D.new();node.mesh=mesh;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return node
