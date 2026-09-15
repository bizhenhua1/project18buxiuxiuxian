extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(800,600)
 var actor=load("res://scripts/world3d/allied_actor.gd").new();root.add_child(actor);actor.setup("mary-kuromi.glb")
 var empty:Dictionary={"right":"","left":"","head":"","body":"","jewel":"","feet":""}
 for weapon in ["","sword_B.gltf","sword_E.gltf",""]:
  var data=empty.duplicate();data.right=weapon
  actor.refresh_equipment(data);actor.locomotion_blend_enabled=false
  var both:bool=weapon=="sword_E.gltf"
  assert(actor.hand_pose.size()==(0 if weapon.is_empty() else 30 if both else 15))
  for gait in ["walk","run"]:
   for frame in 60:
    actor.advance(.025,Vector3(0,0,float(actor.strides[actor.model_key][gait])*1.05))
    var submitted:Dictionary={}
    for bone in actor.retarget.evaluation_bones:submitted[bone]=actor.rig.get_bone_pose_rotation(bone)
    actor.retarget.apply(fmod(actor.clock,float(actor.retarget.frames-1)/actor.retarget.fps))
    for bone in submitted:
     if actor.hand_pose.has(bone):assert(submitted[bone].is_equal_approx(actor.hand_pose[bone]))
     else:assert(submitted[bone].is_equal_approx(actor.rig.get_bone_pose_rotation(bone)),"Non-equipped bones must match the source animation")
    actor.apply_hand_pose()
 if "--capture" in OS.get_cmdline_user_args():
  var camera:=Camera3D.new();root.add_child(camera);camera.position=Vector3(.6,.9,1.5);camera.look_at(Vector3(0,.8,0));camera.current=true
  var light:=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-30,-25,0);light.light_energy=2
  for frame in 3:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://../tempassets/work/world3d-hand-grip.png")
 print("HAND_GRIP_PASS empty, one-handed, two-handed and unequipped; free bones match source through walk/run")
 quit()

