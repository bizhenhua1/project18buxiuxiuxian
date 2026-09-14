extends SceneTree
const PROJECTION=preload("res://scripts/world3d/enemy_portrait_projection.gd")
func _initialize():call_deferred("run")
func run():
 var viewport:=SubViewport.new();viewport.size=Vector2i(640,800);root.add_child(viewport)
 var camera:=Camera3D.new();viewport.add_child(camera)
 var count:=0;var maximum:=0.0
 for size in [.5,.730769,1.315384]:
  for lateral in [-2.0,0.0,2.0]:
   for depth in [1.5,3.0,7.0,20.0]:
    var anchor:=Vector3(lateral,-1.1,-depth)
    var eye:Vector3=-anchor/size;eye.z=maxf(.6,eye.z)
    camera.position=eye;camera.look_at(Vector3(0,.9,0))
    camera.fov=clampf(rad_to_deg(2*atan(1.3/maxf(.3,eye.distance_to(Vector3(0,.9,0))))),4,110)
    var parameters:Dictionary=PROJECTION.parameters(anchor,size,200)
    var ground:Vector2=camera.unproject_position(Vector3.ZERO)/Vector2(viewport.size)
    for point in [Vector3.ZERO,Vector3(0,1.8,0),Vector3(.4,.9,.3),Vector3(-.4,.2,-.4)]:
     var uv:Vector2=camera.unproject_position(point)/Vector2(viewport.size)
     var expected:Vector2=Vector2((uv.x-.5)*.8,-(uv.y-ground.y))*2.6*size
     var actual:Vector2=PROJECTION.offset(anchor+point*size,parameters)
     maximum=maxf(maximum,actual.distance_to(expected));count+=1
     assert(actual.distance_to(expected)<.0001,"Independent Camera3D projection differs")
    var last:=0.0
    for pixels in range(120,166):
     var weight:float=PROJECTION.parameters(anchor,size,pixels).portrait_near_params.x
     assert(weight>=last and weight-last<.045,"Near transition must be continuous and monotonic")
     last=weight
 assert(PROJECTION.parameters(Vector3(0,-1,-20),.73,100).portrait_near_params==Vector3.ZERO)
 print("WORLD3D_ENEMY_PROJECTION_PASS samples=",count," max model-space error=",maximum," smooth distance blend")
 quit()
