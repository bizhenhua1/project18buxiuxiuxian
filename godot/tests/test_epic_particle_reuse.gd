extends SceneTree
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const LIB="res://assets/fx/epic181/library/"
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 var camera:=Camera3D.new();root.add_child(camera)
 var catalog=JSON.parse_string(FileAccess.get_file_as_string(LIB+"index.json"));var entry:Dictionary={}
 for item in catalog:
  if item.name=="StormMissile":entry=item;break
 var samples:=0
 for id in [entry.id,entry.muzzle_id,entry.impact_id]:
  var spec:Dictionary={}
  for item in catalog:
   if item.id==id:spec=JSON.parse_string(FileAccess.get_file_as_string(LIB+item.file));break
  for mode in 3:
   var reused=FX.new();reused.gpu_curves=mode>0;reused.gpu_motion=mode==2
   root.add_child(reused);reused.setup(spec,camera,LIB)
   var high_water:=0
   for cycle in 3:
    var fresh=FX.new();fresh.gpu_curves=mode>0;fresh.gpu_motion=mode==2
    root.add_child(fresh);fresh.setup(spec,camera,LIB)
    reused.reset_particles();reused.age=0.0;reused.rng.state=fresh.rng.state
    reused.position=Vector3.ZERO;reused.last_position=Vector3.ZERO
    for layer in reused.layers:
     assert(layer.particles.is_empty() and layer.mm.visible_instance_count==0)
    for frame in 90:
     var dt:float=[1.0/120,.05,.011,1.0/30][frame%4]
     for actor in [fresh,reused]:
      actor.position=Vector3(sin(frame*.05)*.2,0,0);actor.rotation.y=frame*.01;actor.advance(dt)
     for layer_index in fresh.layers.size():
      var a=fresh.layers[layer_index];var b=reused.layers[layer_index]
      assert(a.particles.size()==b.particles.size())
      assert(b.particles.size()+b.recycled.size()<=FX.CAP,"Pool exceeded per-layer bound")
      for i in a.particles.size():
       for field in ["age","life","random","position","velocity","rotation","size","tile","base_color","gpu_color","motion_data","motion_slot"]:
        assert(a.particles[i].get(field)==b.particles[i].get(field),"Reused state differs: "+field)
       assert(a.mm.get_instance_transform(i)==b.mm.get_instance_transform(i))
       assert(a.mm.get_instance_color(i)==b.mm.get_instance_color(i))
       assert(a.mm.get_instance_custom_data(i)==b.mm.get_instance_custom_data(i))
       samples+=1
    if cycle==0:high_water=reused.particle_allocations
    else:assert(reused.particle_allocations==high_water,"Repeated workload allocated new particles")
    fresh.free()
   reused.free()
 print("EPIC_PARTICLE_REUSE_PASS samples=",samples," repeated_allocations=0")
 quit()
