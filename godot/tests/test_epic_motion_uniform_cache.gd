extends SceneTree
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LIB="res://assets/fx/epic181/library/"
func _initialize():call_deferred("run")
func run():
 var camera:=Camera3D.new();root.add_child(camera)
 var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LIB+"effects/425d927f9eb0a72428aed6bb4c72fba1.json"))
 var actors:Array=[];var checks:=0
 for cached in [false,true]:
  var fx:=FX.new();fx.gpu_curves=true;fx.gpu_motion=true;fx.cache_motion_uniforms=cached;root.add_child(fx);fx.setup(spec,camera,LIB);actors.append(fx)
 for frame in 90:
  if frame==20:camera.rotation.y=.3
  if frame==40:camera.position=Vector3(3,2,1)
  for fx in actors:
   if frame==30:fx.position=Vector3(120,7,-256)
   if frame==50:fx.scale=Vector3(.6,.7,.8)
   if frame==60:fx.rotation.y=.6
   if frame==70:fx.reset_particles();fx.age=0
   fx.advance(0.0 if frame%7==0 else 1.0/60)
  for i in actors[0].layers.size():
   var a:ShaderMaterial=actors[0].layers[i].material;var b:ShaderMaterial=actors[1].layers[i].material
   for field in ["motion_emitter","motion_inverse","motion_billboard","motion_age"]:
    assert(a.get_shader_parameter(field)==b.get_shader_parameter(field),"Cached uniform stale after transform/camera/reset: "+field)
    checks+=1
 print("EPIC_MOTION_UNIFORM_CACHE_PASS comparisons=",checks," stationary/move/rotate/scale/camera/reset")
 quit()
