extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 app._process(0)
 # Fresh ordinary 3D must fade equipped weapons before any portrait toggle.
 for member in app.team:
  if member.attachments.is_empty():continue
  assert(not member.portrait_presenter.weapons.is_empty())
  var opacity:float=member.opacity;member.set_opacity(.25)
  for weapon in member.portrait_presenter.weapons:
   assert(weapon.mesh.get_active_material(weapon.index)==weapon.original)
   assert(is_equal_approx(weapon.original.albedo_color.a,weapon.base_alpha*.25))
  member.set_opacity(opacity)
 app.atmosphere_mode=true;app._process(0)
 for entry in app.actor_atmosphere.entries:assert(entry.tail.next_pass==entry.material)
 app.atmosphere_mode=false;app._process(0)
 for entry in app.actor_atmosphere.entries:assert(entry.tail.next_pass==null)
 for entry in app.party_lighting.entries:
  for node in app.get_children():
   if node is DirectionalLight3D:
    assert((node.light_cull_mask & entry.key.light_cull_mask)==0,"Scene sun must not duplicate saved party lighting")
 var actor=app.team[0];var original_shader:Shader=actor.fade_materials[0].shader
 var original_transform:Transform3D=actor.transform
 app.portrait_mode=true;app._process(0)
 assert(actor.transform==original_transform,"Projection mode must not move world actor")
 assert(actor.fade_materials[0].shader!=original_shader)
 app.start_travel()
 for i in 60:app._process(.02)
 assert(actor.fade_materials[0].get_shader_parameter("portrait_anchor")==actor.global_position,"Moving actor must refresh projection anchor")
 for entry in actor.portrait_presenter.weapons:
  assert(entry.material.get_shader_parameter("portrait_anchor")==actor.global_position,"Weapon must use the same anchor")
 actor.refresh_equipment()
 assert(actor.portrait_presenter.enabled)
 for entry in actor.portrait_presenter.weapons:assert(is_instance_valid(entry.mesh))
 app.portrait_mode=false;app._process(0)
 assert(actor.fade_materials[0].shader==original_shader,"Toggle restores the original shader")
 for entry in actor.portrait_presenter.weapons:assert(entry.mesh.get_active_material(entry.index)==entry.original)
 for i in 400:
  if app.phase=="event":break
  app._process(.02)
 assert(app.phase=="event")
 for key in ["height","lens","horizon","forward","lateral","yaw"]:
  assert(is_equal_approx(float(app.frame.get(key,0)),float(app.composition.frames.event.get(key,0))),"Event camera must reach saved frame: "+key)
 app.portrait_mode=true;app.start_battle()
 for i in 160:app._process(.02)
 assert(app.phase=="battle")
 var near_checked:=0
 for slot in app.enemy_pool:
  var enemy=slot.actor
  if not enemy.visible:continue
  var presenter=enemy.portrait_presenter
  if presenter.near_parameters.portrait_near_params.x<=0:continue
  near_checked+=1
  for entry in presenter.surfaces:
   assert(entry.material.get_shader_parameter("portrait_near_params")==presenter.near_parameters.portrait_near_params)
  var point:Vector3=enemy.global_position+Vector3(.1,.7,.2)
  var actual:Vector3=presenter.presented_attachment(point,app.camera)
  var view:Transform3D=app.camera.global_transform.affine_inverse()
  assert(absf((view*actual).z-(view*point).z)<.0001,"Projection must preserve actual attachment depth")
 assert(near_checked>0,"Actual battle must exercise near projection")
 for key in ["height","lens","horizon","forward","lateral","yaw"]:
  assert(is_equal_approx(float(app.frame.get(key,0)),float(app.composition.frames.battle.get(key,0))),"Battle camera must reach saved frame: "+key)
 for member in app.team:assert(is_equal_approx(member.opacity,1.0),"Battle must complete the returning allies' entry fade")
 # Actual hand origin survives the route/world conversion, including terrain.
 var source=app.sim.allies[app.team_slots[0]]
 var bone:int=actor.rig.find_bone("手首.R")
 var hand:Vector3=(actor.rig.global_transform*actor.rig.get_bone_global_pose(bone)).origin
 var expected:Vector3=hand+app.world_point(source.pos)-actor.global_position
 expected.y+=float(app.profiles[source.id].clearance)/20
 assert(app.world_point(app.emission_origin(source,false)).distance_to(expected)<.0001)
 var origin:Vector3=app.emission_origin(source,false)
 var shot_id:int=app.sim.projectiles.launch(origin,Vector3(0,0,-1),14,1,false,1,source.id)
 app.projectile_view.advance(0)
 var projected:Vector3=actor.portrait_presenter.projected_attachment(app.world_point(origin),actor.global_position,app.camera,actor.portrait_presenter.vertical_offset)
 assert(app.projectile_view.bindings[shot_id].global_position.distance_to(projected)<.0001)
 var shot:Dictionary=app.sim.projectiles.active.back()
 assert(shot.origin==origin and shot.pos==origin,"Presentation must not alter simulation")
 shot.pos=origin+Vector3(0,0,-3);shot.previous=shot.pos
 app.projectile_view.advance(0)
 assert(app.projectile_view.bindings[shot_id].global_position.distance_to(app.world_point(shot.pos))<.0001,"Flight converges fully to the physical path")
 for p in [hand,hand+Vector3(.2,.3,.1),hand+Vector3(-.3,-.4,-.2)]:
  var view:Transform3D=app.camera.global_transform.affine_inverse()
  var q:Vector3=view*p;var anchor:Vector3=view*actor.global_position
  var matrix:Projection=app.camera.get_camera_projection()
  var clip:Vector4=matrix*Vector4(q.x,q.y,q.z,1)
  var anchor_clip:Vector4=matrix*Vector4(anchor.x,anchor.y,anchor.z,1)
  var ndc:=Vector2(clip.x,clip.y)/anchor_clip.w
  # Off-axis projection contributes a constant centre shift, not scaled depth.
  ndc=Vector2(anchor_clip.x,anchor_clip.y)/anchor_clip.w+Vector2(matrix.x.x*(q.x-anchor.x),matrix.y.y*(q.y-anchor.y))/anchor_clip.w
  var result:Vector3=view*actor.portrait_presenter.projected_attachment(p,actor.global_position,app.camera)
  var result_clip:Vector4=matrix*Vector4(result.x,result.y,result.z,1)
  assert((Vector2(result_clip.x,result_clip.y)/result_clip.w).distance_to(ndc)<.00001)
  assert(is_equal_approx(result.z,q.z))
 for slot in app.enemy_pool:
  if slot.id>=0:
   assert(slot.actor.portrait_presenter.enabled)
   assert(slot.actor.fade_materials[0].get_shader_parameter("portrait_anchor")==slot.actor.global_position)
 for i in 3:await process_frame
 var leader=app.team[0];var presenter=leader.portrait_presenter
 var original_position:Vector3=leader.position
 leader.dead=false;presenter.corpse_blend=0;presenter.advance_anchor(0,true);presenter.sync()
 var standing:float=presenter.vertical_offset
 leader.set_opacity(.25)
 for entry in presenter.weapons:
  assert(is_equal_approx(entry.material.get_shader_parameter("actor_opacity"),.25))
  assert(is_equal_approx(entry.original.albedo_color.a,entry.base_alpha*.25))
 leader.set_opacity(0)
 for attachment in leader.attachments:assert(not attachment.visible)
 leader.set_opacity(1)
 for attachment in leader.attachments:assert(attachment.visible)
 for entry in presenter.weapons:assert(entry.original.transparency==entry.base_transparency)
 assert(standing>0)
 leader.dead=true;presenter.advance_anchor(.2,true);presenter.sync()
 assert(is_equal_approx(presenter.vertical_offset,standing*.5))
 presenter.advance_anchor(.2,true);presenter.sync();assert(is_zero_approx(presenter.vertical_offset))
 leader.dead=false;presenter.advance_anchor(.4,true);presenter.sync()
 assert(is_equal_approx(presenter.vertical_offset,standing) and leader.position==original_position)
 for entry in presenter.surfaces:assert(is_equal_approx(entry.material.get_shader_parameter("portrait_vertical_offset"),standing))
 for entry in presenter.weapons:assert(is_equal_approx(entry.material.get_shader_parameter("portrait_vertical_offset"),standing))
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-portrait-runtime.png")
 print("WORLD3D_PORTRAIT_RUNTIME_PASS no position mutation, moving body/weapon anchors, equipment refresh, toggle restoration, real battle")
 quit()
