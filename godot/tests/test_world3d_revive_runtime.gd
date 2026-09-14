extends SceneTree
func _initialize():call_deferred("run")
func snapshot(label:String):
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/revive-"+label+".png")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
 while not app.stage or not app.stage.ready_stage:await process_frame
 var stage=app.stage;stage.set_process(false);stage.start_battle();stage.sim.next_spawn=INF
 var actor=stage.team[1];var unit:Dictionary=stage.sim.allies[stage.team_slots[1]]
 var home:Vector3=unit.pos
 unit.attack_origin=home;unit.attack_tip=home+Vector3(0,0,-3);unit.pos=unit.attack_tip
 unit.attack_duration=1.0;unit.changed=stage.sim.clock;unit.state="attack"
 unit.previous_pos=unit.pos;stage._process(0)
 var death_position:Vector3=actor.position
 stage.sim.hurt(unit,unit.max_hp+1)
 for i in 70:stage._process(.05)
 assert(actor.dead)
 assert(actor.position.is_equal_approx(death_position))
 var projection_report:Dictionary={"anchor_uv":stage.camera.unproject_position(actor.global_position)/stage.bridge.view_size,"vertical_offset":actor.portrait_presenter.vertical_offset,"bones":{}}
 for name in ["頭","下半身","足首.L","足首.R"]:
  var bone:int=actor.rig.find_bone(name)
  if bone<0:continue
  var world:Vector3=actor.rig.global_transform*actor.rig.get_bone_global_pose(bone).origin
  projection_report.bones[name]={"native_uv":stage.camera.unproject_position(world)/stage.bridge.view_size,"presented_uv":stage.camera.unproject_position(actor.portrait_presenter.presented_attachment(world,stage.camera))/stage.bridge.view_size}
 print("CORPSE_PROJECTION_DIAGNOSTIC ",projection_report)
 await snapshot("corpse")
 if "--compare-corpse-projection" in OS.get_cmdline_user_args():
  # Diagnostic only. Freeze simulation and override the same material weight
  # that the production atmosphere service writes; restore before continuing.
  var weights:Dictionary={}
  for entry in actor.portrait_presenter.weapons:
   var mesh:MeshInstance3D=entry.mesh
   var vertices:PackedVector3Array=mesh.mesh.surface_get_arrays(entry.index)[Mesh.ARRAY_VERTEX]
   var near_depth:=INF;var far_depth:=-INF;var bounds:=Rect2();var first:=true
   for vertex in vertices:
    var world:Vector3=mesh.global_transform*vertex
    var depth:float=-stage.camera.to_local(world).z
    near_depth=minf(near_depth,depth);far_depth=maxf(far_depth,depth)
    if depth<=stage.camera.near:continue
    var uv:Vector2=stage.camera.unproject_position(world)/stage.bridge.view_size
    if first:bounds=Rect2(uv,Vector2.ZERO);first=false
    else:bounds=bounds.expand(uv)
   print("CORPSE_WEAPON_DIAGNOSTIC model=",actor.model_key," loadout=",actor.applied_loadout," mesh=",mesh.name," near=",near_depth," far=",far_depth," camera_near=",stage.camera.near," native_uv=",bounds)
  for entry in actor.portrait_presenter.surfaces+actor.portrait_presenter.weapons:
   var material:Material=entry.material
   while material!=null:
    if material is ShaderMaterial and not weights.has(material):
     var value=material.get_shader_parameter("portrait_weight")
     if value!=null:
      weights[material]=value
      material.set_shader_parameter("portrait_weight",0.0)
    material=material.next_pass
  await snapshot("corpse-native")
  actor.hide()
  await snapshot("corpse-hidden")
  actor.show()
  var attachment_visibility:Array=[]
  for attachment in actor.attachments:
   attachment_visibility.append(attachment.visible);attachment.hide()
  await snapshot("corpse-native-no-weapons")
  for i in actor.attachments.size():actor.attachments[i].visible=attachment_visibility[i]
  for material in weights:material.set_shader_parameter("portrait_weight",weights[material])
 actor.rotation.y=.73
 unit.hp=unit.max_hp
 stage._process(.05)
 assert(unit.state=="rising" and actor.clip=="rise" and not actor.dead)
 var stopped:Vector3=unit.pos
 var recovery_frames:=0
 while unit.state=="rising":
  stage._process(.05)
  recovery_frames+=1
  if recovery_frames in [4,12]:await snapshot("rise-"+str(recovery_frames))
  assert(unit.pos==stopped,"Actor translates before completing recovery")
  assert(is_equal_approx(actor.rotation.y,.73),"Battle facing overwrote stationary recovery heading")
 for i in 40:stage._process(.05)
 assert(unit.pos.is_equal_approx(home) and not actor.dead)
 assert(actor.clip=="idle")
 await snapshot("home")
 actor.trigger("death");actor.advance(10,Vector3.ZERO)
 var poses:Array=[]
 for bone in actor.retarget.evaluation_bones:poses.append(actor.rig.get_bone_pose(bone))
 actor.trigger("battle_revive");actor.advance(0,Vector3.ZERO)
 for i in poses.size():
  assert(poses[i].is_equal_approx(actor.rig.get_bone_pose(actor.retarget.evaluation_bones[i])),"Recovery first frame snaps from corpse pose")
 print("WORLD3D_REVIVE_RUNTIME PASS stationary rise then return to original home")
 quit()
