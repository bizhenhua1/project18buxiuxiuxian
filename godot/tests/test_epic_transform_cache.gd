extends SceneTree
const FX=preload("res://scripts/spaces/epic181_effect.gd")
const OLD=preload("res://tests/fixtures/epic181_effect_reference.gd")
const LIB="res://assets/fx/epic181/library/"
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":
  push_error("Particle MultiMesh readback requires a graphics backend; headless equality is not rendering evidence")
  quit(1);return
 var camera:=Camera3D.new();root.add_child(camera)
 var catalog=JSON.parse_string(FileAccess.get_file_as_string(LIB+"index.json"));var entry:Dictionary={}
 for item in catalog:
  if item.name=="StormMissile":entry=item;break
 var worst:=0.0;var samples:=0;var timings:=[0,0]
 for id in [entry.id,entry.muzzle_id,entry.impact_id]:
  var spec:Dictionary={}
  for item in catalog:
   if item.id==id:spec=JSON.parse_string(FileAccess.get_file_as_string(LIB+item.file));break
  var pair=[OLD.new(),FX.new()]
  if "--sheet-fixture" in OS.get_cmdline_user_args():
   for layer in spec.layers:layer.sheet={"enabled":true,"x":4,"y":4,"cycles":3.5,"row_mode":1,"row":2,"frame":[[0.0,1.0],[0.0,1.0]],"start":[[.1],[.3]]}
  for actor in pair:root.add_child(actor);actor.setup(spec,camera,LIB)
  for frame in 120:
   camera.rotation.y=frame*.005
   for actor in pair:
    actor.position=Vector3(sin(frame*.05),frame*.001,-frame*.01);actor.rotation.y=frame*.01;actor.scale=Vector3(.3,.4,.5)
   # Alternate order to reduce systematic timing bias.
   for k in [frame%2,1-frame%2]:
    var began:=Time.get_ticks_usec();pair[k].advance(1.0/60);timings[k]+=Time.get_ticks_usec()-began
   for layer_index in pair[0].layers.size():
    var a=pair[0].layers[layer_index];var b=pair[1].layers[layer_index]
    assert(a.particles.size()==b.particles.size(),"Emitter counts changed")
    for i in a.particles.size():
     var x:Transform3D=a.mm.get_instance_transform(i);var y:Transform3D=b.mm.get_instance_transform(i)
     worst=maxf(worst,x.origin.distance_to(y.origin))
     for axis in 3:worst=maxf(worst,x.basis[axis].distance_to(y.basis[axis]))
     assert(a.mm.get_instance_color(i).is_equal_approx(b.mm.get_instance_color(i)))
     assert(a.mm.get_instance_custom_data(i)==b.mm.get_instance_custom_data(i))
     samples+=1
  for actor in pair:actor.free()
 assert(worst<.0001,"Transform cache changed particle geometry")
 print("EPIC_TRANSFORM_CACHE_PASS samples=",samples," max_error=",worst," reference_usec=",timings[0]," cached_usec=",timings[1])
 quit()
