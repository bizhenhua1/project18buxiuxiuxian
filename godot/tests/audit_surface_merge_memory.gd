extends SceneTree
const MERGER=preload("res://scripts/world3d/surface_merge.gd")
func _initialize():call_deferred("run")
func storage(mesh:ArrayMesh)->Dictionary:
 var result:Dictionary={"surfaces":mesh.get_surface_count(),"geometry_bytes":0,"lod_bytes":0,"lod_levels":0}
 for index in mesh.get_surface_count():
  var surface:Dictionary=RenderingServer.mesh_get_surface(mesh.get_rid(),index)
  for field in ["vertex_data","attribute_data","skin_data","index_data"]:result.geometry_bytes+=surface.get(field,PackedByteArray()).size()
  for lod in surface.get("lods",[]):result.lod_bytes+=lod.index_data.size();result.lod_levels+=1
 return result
func scan(node:Node,rows:Array):
 if node is MeshInstance3D and node.mesh is ArrayMesh:
  var start:=Time.get_ticks_usec();var merged:=MERGER.merge(node.mesh);var elapsed:=Time.get_ticks_usec()-start
  assert(MERGER.merge(node.mesh)==merged,"Repeated instances must share converted geometry")
  rows.append({"source":storage(node.mesh),"merged":storage(merged),"build_ms":elapsed/1000.0})
 for child in node.get_children():scan(child,rows)
func run():
 var report:Dictionary={};var source_bytes:=0;var merged_bytes:=0
 for key in ["composer","composer-george","joseph-summer","isabella","gardener-kitty-dada","geisha-thirteen"]:
  var model=load("res://assets/characters3d/"+key+".glb").instantiate()
  var rows:Array=[];scan(model,rows);model.free();report[key]=rows
  for row in rows:
   source_bytes+=row.source.geometry_bytes+row.source.lod_bytes
   merged_bytes+=row.merged.geometry_bytes+row.merged.lod_bytes
 print("SURFACE_MERGE_MEMORY source_bytes=",source_bytes," converted_bytes=",merged_bytes," cache_entries=",MERGER.cache.size())
 FileAccess.open("res://../tempassets/work/surface-merge-memory.json",FileAccess.WRITE).store_string(JSON.stringify({"models":report,"source_bytes":source_bytes,"converted_bytes":merged_bytes,"cache_entries":MERGER.cache.size(),"scope":"Raw mesh buffers only; not driver VRAM or total runtime memory"},"  "))
 quit()
