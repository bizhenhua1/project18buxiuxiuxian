extends SceneTree
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LIB="res://assets/fx/epic181/library/"
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(480,320)
 var stage:=Node3D.new();root.add_child(stage)
 var camera:=Camera3D.new();stage.add_child(camera);camera.position=Vector3(0,3,10);camera.look_at(Vector3.ZERO);camera.current=true
 var index:Array=JSON.parse_string(FileAccess.get_file_as_string(LIB+"index.json"))
 var paths:Dictionary={};var count:=0;var particles:=0
 for entry in index:
  if not entry.playable or paths.has(entry.file):continue
  paths[entry.file]=true
  var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LIB+entry.file))
  for layer in data.layers:
   if not layer.material.texture.is_empty():assert(ResourceLoader.exists(LIB+layer.material.texture))
   if not layer.mesh.is_empty():assert(ResourceLoader.exists(LIB+layer.mesh))
  var fx=FX.new();stage.add_child(fx);fx.setup(data,camera,LIB)
  for frame in 6:
   fx.position.z-=.4;fx.advance(.08)
   for layer in fx.layers:
    for p in layer.particles:assert(p.position.is_finite());particles+=1
  await process_frame
  fx.free();count+=1
  if count%200==0:print("ASSET_CHECK ",count)
 print("EPIC_ASSETS_PASS unique=",count," finite_particle_samples=",particles)
 quit()
