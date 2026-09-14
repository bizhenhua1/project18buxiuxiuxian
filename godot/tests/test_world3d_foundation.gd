extends SceneTree
const P=preload("res://scripts/world3d/projection.gd")
const INDEX=preload("res://scripts/world3d/spatial_index.gd")
const BOUNDS=preload("res://scripts/world3d/cutout_bounds.gd")
func _initialize():call_deferred("run")
func run():
 var viewport:=SubViewport.new();viewport.size=Vector2i(1440,900);root.add_child(viewport)
 var camera:=Camera3D.new();viewport.add_child(camera)
 var presets=JSON.parse_string(FileAccess.get_file_as_string("res://data/traditional_camera_active.json"))
 var worst:=0.0
 for size in [Vector2i(1440,900),Vector2i(1920,1080),Vector2i(900,900)]:
  viewport.size=size
  for frame in presets.frames.values()+[{"height":32,"lens":.95,"horizon":.3,"forward":17,"lateral":-23,"yaw":27}]:
   for angle in [0.0,.4,-.8]:
    var origin:=Vector2(123,210)
    var effective:=origin+Vector2(cos(angle),-sin(angle))*float(frame.get("lateral",0))+Vector2(sin(angle),cos(angle))*float(frame.get("forward",0))
    var effective_angle:float=angle+deg_to_rad(float(frame.get("yaw",0)))
    P.configure(camera,Vector2(size),P.frame_origin(origin,angle,frame),P.frame_heading(angle,frame),frame.height,frame.lens,frame.horizon)
    for depth in [30.0,80.0,300.0,1000.0]:
     for lateral in [-40.0,0.0,35.0]:
      var p:=effective+Vector2(lateral,depth).rotated(-effective_angle)
      for h in [0.0,20.0,45.0]:
       var expected:=P.project_reference(p,h,Vector2(size),effective,effective_angle,frame.height,frame.lens,frame.horizon)
       var actual:=camera.unproject_position(P.point(p,h))
       worst=maxf(worst,expected.distance_to(actual))
 assert(worst<.02,"Off-axis camera must match traditional projection: "+str(worst))
 var frame_test={"yaw":179.0}
 P.blend_frame(frame_test,{"yaw":-179.0},.5)
 assert(absf(absf(frame_test.yaw)-180)<.001,"Yaw transition must take the short arc")
 # Independent shader-corner samples: no visible point may be rejected by the broad phase.
 for anchor in [Vector2(.5,1),Vector2(-.7,1.3),Vector2(1.6,-.2)]:
  for dimensions in [Vector2(2,20),Vector2(12,1)]:
   for position in [Vector3(0,0,-10),Vector3(20,0,-10),Vector3(-12,0,-2),Vector3(0,0,5)]:
    var box:=BOUNDS.enclosing(position,dimensions,anchor)
    for angle in [0.0,.4,-.8,2.1]:
     for flip in [-1,1]:
      for x in [0.0,1.0]:
       for y in [0.0,1.0]:
        var corner:Vector3=position+Vector3(cos(angle),0,sin(angle))*(x-anchor.x)*dimensions.x*flip+Vector3.UP*(y+anchor.y-1)*dimensions.y
        assert(box.has_point(corner),"Billboard bounds lost a rotated/anchored corner")
        var relative:=ForestRoute.to_camera(Vector2(corner.x,-corner.z)*20,Vector2.ZERO,angle)
        if relative.y>=1 and relative.y<=1700 and absf(relative.x)<=relative.y*.9:
         assert(BOUNDS.visible(box,Vector2.ZERO,angle,.9),"Visible art was incorrectly culled")
 var units:Array=[];var rng:=RandomNumberGenerator.new();rng.seed=9834
 for id in 500:units.append({"id":id,"pos":Vector3(rng.randf_range(-40,40),0,rng.randf_range(-40,40)),"hp":1,"radius":rng.randf_range(.1,1.2)})
 var index=INDEX.new();index.rebuild(units)
 for trial in 100:
  var a:=Vector3(rng.randf_range(-40,40),0,rng.randf_range(-40,40));var b:=a+Vector3(4,0,9);var radius:=rng.randf_range(.1,5)
  var expected:Array=[]
  for u in units:
   if a.distance_to(u.pos)<=radius+u.radius:expected.append(u.id)
  assert(index.circle(a,radius)==expected,"Circle broad phase parity")
  expected.clear()
  for u in units:
   var t:=clampf((u.pos-a).dot(b-a)/(b-a).length_squared(),0,1)
   if u.pos.distance_to(a+(b-a)*t)<=radius+u.radius:expected.append(u.id)
  assert(index.sweep(a,b,radius)==expected,"Piercing/swept projectile must not miss targets")
 print("WORLD3D_FOUNDATION_PASS projection max pixels=",worst,"; 500-unit AoE/sweep parity")
 quit()

