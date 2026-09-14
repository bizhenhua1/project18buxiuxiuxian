extends SceneTree
# Production renderer only: fixed distance samples isolate framing from combat RNG.
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/defense_route.tscn").instantiate();root.add_child(app)
 while not app.defense_ready:await process_frame
 app.reset_defense(true);app.defense.begin();app.paused=true;app.set_process(false)
 var selected:Dictionary={}
 for e in app.defense.enemies:
  if selected.has(e.type):e.state="leaked";continue
  selected[e.type]=e
  e.state="walk";e.entry="road";e.entry_phase="advance";e.activate_at=0;e.born=-10
  e.hp=e.max_hp;e.actual_speed=1.0;e.heading=0.0
 assert(selected.size()==5)
 var report:Dictionary={"source":"res://scenes/defense_route.tscn","controlled_distance_samples":true,"samples":[]}
 for sample in [{"name":"far","z":-14.0},{"name":"middle","z":0.0},{"name":"near","z":6.0}]:
  for kind in selected:
   var e=selected[kind];e.pos=Vector3((kind-2)*1.9,0,sample.z);e.previous_pos=e.pos
  app._process(0)
  for i in 4:await process_frame
  var renderer=app.arena.scenery.renderer
  var screen:Transform2D=app.arena.get_global_transform_with_canvas()
  for kind in selected:
   var e=selected[kind]
   var matches:Array=renderer.battle_actors.filter(func(a):return a.id==900000+e.id)
   assert(matches.size()==1)
   var sprite:Dictionary=matches[0]
   var key:String=str(kind)+app.motion_bucket(e)
   var portrait=app.sources[key]
   var near:bool=app.near_actors.bindings.has(e.id)
   if near:portrait=app.near_actors.slots[app.near_actors.bindings[e.id]].actor
   var relative:Vector2=ForestRoute.to_camera(sprite.position,renderer.camera_world,renderer.heading)
   var k:float=renderer.focal()/relative.y
   var ground:float=ForestEcology.height_at(sprite.position)-ForestEcology.height_at(renderer.camera_world)
   var foot:=Vector2(renderer.view_size.x*.5+relative.x*k,renderer.horizon_y()+(renderer.camera_height()-ground-sprite.altitude)*k)
   var dimensions:=Vector2(sprite.w,sprite.h)*k
   var origin:Vector2=foot-sprite.ground_anchor*dimensions
   var landmarks:Dictionary={};var weak_error:=0.0;var near_error:=0.0
   var anchor_view:=Vector3(relative.x,ground+sprite.altitude-renderer.camera_height(),-relative.y)/20
   var model_scale:float=sprite.h/52.0
   var calculator=preload("res://scripts/world3d/enemy_portrait_projection.gd")
   var parameters:Dictionary=calculator.parameters(anchor_view,model_scale,dimensions.y)
   for name in ["頭","首","手首.L","手首.R","足首.L","足首.R"]:
    var bone:int=portrait.rig.find_bone(name)
    if bone<0:continue
    var point:Vector3=portrait.rig.global_transform*portrait.rig.get_bone_global_pose(bone).origin
    var uv:Vector2=portrait.actor_camera.unproject_position(point)/Vector2(portrait.viewport.size)
    var pixel:Vector2=screen*(origin+uv*dimensions)
    # Current native weak projection flattens the pose to its ground anchor.
    # This isolates internal perspective from model size, pose and world placement.
    var weak:Vector2=screen*(foot+Vector2(point.x,-point.y)*sprite.h*k/2.6)
    weak_error=maxf(weak_error,pixel.distance_to(weak))
    if near and parameters.portrait_near_params.x==1.0:
     var corrected:Vector2=calculator.offset(anchor_view+point*model_scale,parameters)
     var corrected_pixel:Vector2=screen*(foot+Vector2(corrected.x,-corrected.y)*k*20)
     near_error=maxf(near_error,corrected_pixel.distance_to(pixel))
    landmarks[name]=[pixel.x,pixel.y]
   var camera=portrait.actor_camera
   if near and parameters.portrait_near_params.x==1.0:
    assert(near_error<.02,"Native near projection differs from independent production camera")
    print("NEAR_PROJECTION_PARITY ",sample.name," kind=",kind," max pixels=",near_error)
   report.samples.append({"sample":sample.name,"kind":kind,"model":app.defense.config.enemies[kind].model,"body_scale":e.body_scale,"near_renderer":near,"depth":relative.y,"portrait_height_pixels":dimensions.y*screen.y.length(),"portrait_height_fraction":dimensions.y/renderer.view_size.y,"ground_anchor":[sprite.ground_anchor.x,sprite.ground_anchor.y],"camera_projection":camera.projection,"camera_fov":camera.fov,"camera_position":[camera.position.x,camera.position.y,camera.position.z],"landmarks":landmarks,"flat_pose_max_error_pixels":weak_error})
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/formal-enemies-"+sample.name+".png")
 assert(report.samples.size()==15)
 FileAccess.open("res://../tempassets/work/formal-enemy-framing.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FORMAL_ENEMY_FRAMING_CAPTURE 15 independent production samples, 5 models at 3 distances")
 quit()
