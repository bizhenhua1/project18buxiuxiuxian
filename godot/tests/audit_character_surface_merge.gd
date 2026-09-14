extends SceneTree
func _initialize():call_deferred("run")
func scan(node:Node,output:Array):
 if node is MeshInstance3D and node.mesh!=null:
  var mesh:Mesh=node.mesh;var surfaces:Array=[]
  for i in mesh.get_surface_count():
   var arrays:=mesh.surface_get_arrays(i)
   var mat:Material=node.get_active_material(i)
   var entry:Dictionary={"index":i,"vertices":arrays[Mesh.ARRAY_VERTEX].size(),"indices":arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null else 0,"format":mesh.surface_get_format(i),"lods":RenderingServer.mesh_get_surface(mesh.get_rid(),i).get("lods",[]).map(func(lod):return {"edge_length":lod.edge_length,"index_bytes":lod.index_data.size()}),"material":mat.get_class() if mat!=null else "none"}
   if mat is StandardMaterial3D:
    entry.texture=mat.albedo_texture.resource_path if mat.albedo_texture else "none"
    entry.color=str(mat.albedo_color)
   surfaces.append(entry)
  output.append({"mesh":node.name,"blend_shapes":mesh.get_blend_shape_count(),"surfaces":surfaces})
 for child in node.get_children():scan(child,output)
func run():
 var report:Dictionary={}
 for key in ["composer","composer-george","joseph-summer","isabella","gardener-kitty-dada","geisha-thirteen"]:
  var model=load("res://assets/characters3d/"+key+".glb").instantiate()
  var meshes:Array=[];scan(model,meshes);report[key]=meshes;model.free()
 FileAccess.open("res://../tempassets/work/character-surface-merge-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CHARACTER_SURFACE_AUDIT ",JSON.stringify(report));quit()


