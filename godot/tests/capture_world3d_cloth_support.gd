extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(800,600)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(2.6,1.6,3.2);camera.look_at(Vector3(0,.4,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.8
 var environment:=WorldEnvironment.new();scene.add_child(environment);environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.15,.17,.18)
 var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=2.0
 var ground:=MeshInstance3D.new();ground.mesh=PlaneMesh.new();ground.mesh.size=Vector2(8,8);scene.add_child(ground)
 var material:=StandardMaterial3D.new();material.albedo_color=Color(.32,.34,.36);ground.material_override=material
 var actor=preload("res://scripts/world3d/actor.gd").new();scene.add_child(actor);actor.setup("isabella.glb");actor.play("death")
 for fraction in [.75,1.0]:
  for corrected in [false,true]:
   for bone in actor.rig.get_bone_count():
    if actor.rig.get_bone_name(bone).begins_with("sk_"):actor.rig.set_bone_pose_rotation(bone,actor.rig.get_bone_rest(bone).basis.get_rotation_quaternion())
   actor.retarget.apply((actor.library.clips.death.frames-1)/actor.library.clips.death.fps*fraction)
   if corrected:preload("res://tests/cloth_ground_fit.gd").apply(actor.rig)
   for frame in 3:await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://../tempassets/work/cloth-support-"+str(fraction)+("-after" if corrected else "-before")+".png")
 print("CLOTH_SUPPORT_STUDY_CAPTURED")
 quit()
