extends SceneTree
const PROGRESS=preload("res://scripts/world3d/travel_progress.gd")
func _initialize():
 for offset in [Vector3(.25,0,-.1),Vector3(-.5,0,.4)]:
  var point:=func(s:float)->Vector3:return Vector3(.1*sin(s*.02),.03*sin(s*.01),-s/20)
  var position:Vector3=point.call(0)+offset;var distance:=0.0
  for i in 300:
   var before:=position;var old_distance:=distance
   var step:Dictionary=PROGRESS.step(position,distance,1000,.03,point)
   distance=step.distance;position=position.move_toward(step.target,.03)
   assert(position.distance_to(before)<=.030001,"No catch-up speed boost")
   assert(distance>=old_distance and distance-old_distance<=.600001)
  assert(position.distance_to(point.call(distance))<.00001,"No permanent moving-target lag")
 print("WORLD3D_TRAVEL_PROGRESS_PASS bounded speed, curved terrain, convergent startup, monotonic route")
 quit()
