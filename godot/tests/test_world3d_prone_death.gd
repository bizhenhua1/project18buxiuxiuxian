extends SceneTree
var capture_enabled:bool="--capture" in OS.get_cmdline_user_args()
func snapshot(label:String):
 if not capture_enabled:return
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/crawl-death-"+label+".png")
func _initialize():call_deferred("run")
func run():
 var model:="composer.glb"
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--model="):model=argument.get_slice("=",1)
 var actor=preload("res://scripts/world3d/actor.gd").new();root.add_child(actor)
 actor.setup(model)
 if capture_enabled:
  root.size=Vector2i(640,480)
  var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(2,1.5,3);camera.look_at(Vector3(0,.4,0));camera.current=true
  var light:=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-40,-30,0)
 var unit={"hp":10,"entry":"crawl","entry_phase":"advance","state":"advance","running":false,"body_scale":1.0,"changed":1.0,"phase_started":0.0}
 actor.animate_unit(unit,.9,.1,Vector3(0,0,1))
 await snapshot("alive")
 var before:Array[Vector3]=[]
 for i in actor.rig.get_bone_count():before.append((actor.rig.global_transform*actor.rig.get_bone_global_pose(i)).origin)
 unit.hp=0;actor.animate_unit(unit,1,.01,Vector3.ZERO)
 var error:=0.0
 for i in actor.rig.get_bone_count():error=maxf(error,before[i].distance_to((actor.rig.global_transform*actor.rig.get_bone_global_pose(i)).origin))
 assert(error<.0001,"Death entry must preserve all world bone positions")
 await snapshot("start")
 var anchor:Vector3=actor.position
 for frame in 42:
  actor.animate_unit(unit,1+frame*.01,.01,Vector3.ZERO)
  if frame==20:await snapshot("middle")
 await snapshot("end")
 assert(actor.death_pose_finished and actor.position==anchor)
 var head:int=actor.rig.find_bone("頭")
 var height:float=(actor.rig.global_transform*actor.rig.get_bone_global_pose(head)).origin.y-actor.global_position.y
 assert(height<.3 and height>-.15,"Terminal head must be near the ground")
 var final:Transform3D=actor.rig.get_bone_global_pose(head)
 actor.animate_unit(unit,20,.01,Vector3.ZERO)
 assert(actor.rig.get_bone_global_pose(head).is_equal_approx(final))
 unit.hp=10;unit.entry="road";actor.animate_unit(unit,21,.01,Vector3.ZERO)
 assert(actor.prone_death_transition==null and not actor.dead and actor.body.rotation.x==0)
 var fresh=preload("res://scripts/world3d/actor.gd").new();root.add_child(fresh);fresh.setup(model)
 fresh.animate_unit(unit,21,.01,Vector3.ZERO)
 for i in actor.rig.get_bone_count():
  assert(actor.rig.get_bone_global_pose(i).is_equal_approx(fresh.rig.get_bone_global_pose(i)),"Reused corpse must match a fresh idle rig")
 print("WORLD3D_PRONE_DEATH_PASS ",model," world pose error=",error," terminal head=",height," anchor, persistence, fresh-rig reuse parity")
 quit()
