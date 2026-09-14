extends SceneTree
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LIB="res://assets/fx/epic181/library/"
func _initialize():call_deferred("run")
func run():
 var camera:=Camera3D.new();root.add_child(camera)
 var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LIB+"effects/425d927f9eb0a72428aed6bb4c72fba1.json"))
 var actors:Array=[];var checks:=0;var empty_checks:=0
 for skip in [false,true]:
  var fx:=FX.new();fx.gpu_curves=true;fx.gpu_motion=true;fx.cache_motion_uniforms=true;fx.skip_empty_layers=skip;root.add_child(fx);fx.setup(spec,camera,LIB);fx.stopped=true;actors.append(fx)
 for frame in 100:
  if frame in [10,65]:camera.rotation.y+=.4;camera.position+=Vector3(2,1,-3)
  for fx in actors:
   if frame in [10,65]:fx.position+=Vector3(120,7,-256);fx.scale=Vector3(.6,.7,.8)
   if frame==50:fx.reset_particles();fx.stopped=true
   if frame in [20,75]:fx.stopped=false;fx.age=0
   fx.advance(0.0 if frame%7==0 else 1.0/60)
  for i in actors[0].layers.size():
   var a:Dictionary=actors[0].layers[i];var b:Dictionary=actors[1].layers[i]
   assert(a.particles.size()==b.particles.size())
   if a.particles.is_empty():empty_checks+=1;continue
   for field in ["motion_emitter","motion_inverse","motion_billboard","motion_age"]:
    assert(a.material.get_shader_parameter(field)==b.material.get_shader_parameter(field),"Sleeping layer resumed with stale uniform: "+field);checks+=1
   for p in a.particles.size():assert(a.particles[p].age==b.particles[p].age and a.particles[p].position==b.particles[p].position)
 assert(checks>0 and empty_checks>0)
 print("EPIC_EMPTY_LAYER_RESUME_PASS uniforms=",checks," empty_samples=",empty_checks," move/scale/camera during sleep and restart")
 quit()
