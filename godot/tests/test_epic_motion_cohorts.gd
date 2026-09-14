extends SceneTree
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LIB="res://assets/fx/epic181/library/"
func _initialize():call_deferred("run")
func run():
 var camera:=Camera3D.new();root.add_child(camera)
 var checked:=0
 for id in ["425d927f9eb0a72428aed6bb4c72fba1","7884076b8d0963745801613efb9b2fde","4e110ae3c6c4a44438488f03e233bfe1"]:
  var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(LIB+"effects/"+id+".json"))
  var actors:Array=[]
  for enabled in [false,true]:
   var actor:=FX.new();actor.gpu_curves=true;actor.gpu_motion=true;actor.particle_cohorts=enabled;root.add_child(actor);actor.setup(spec,camera,LIB);actors.append(actor)
  for cycle in 3:
   for actor in actors:actor.reset_particles();actor.age=0;actor.stopped=false
   for frame in 180:
    var dt:float=[1.0/60,.05,.011,0.0,.1][frame%5]
    for actor in actors:
     if frame==50:actor.stopped=true
     actor.advance(dt)
    for i in actors[0].layers.size():
     var before:Dictionary=actors[0].layers[i];var after:Dictionary=actors[1].layers[i]
     assert(before.particles.size()==after.particles.size(),"Cohort expiry changes the visible particle count")
     for j in before.particles.size():
      var a=before.particles[j];var b=after.particles[j]
      assert(a.random==b.random and a.life==b.life,"Compaction changed particle identity/order")
      assert(a.age==(b.cohort.age if after.gpu_motion else b.age),"Shared birth clock differs from individual accumulation")
      checked+=1
     assert(after.cohorts.size()+after.free_cohorts.size()<=FX.CAP,"Birth cohorts must be bounded and recycled")
   for layer in actors[1].layers:assert(layer.particles.is_empty() and layer.cohorts.is_empty())
  for actor in actors:actor.free()
 print("EPIC_MOTION_COHORTS_PASS particle_comparisons=",checked," reset_cycles=3 variable_step_and_zero_dt=true")
 quit()
