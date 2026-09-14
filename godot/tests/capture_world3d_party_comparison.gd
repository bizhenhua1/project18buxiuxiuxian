extends SceneTree
# Projection diagnostic only: reference actors inherit native world positions,
# frame and pose. This cannot validate the formal game's independent formation,
# content viewport, battle camera lifecycle or actual on-screen occupancy.
# Full composition acceptance requires an independently captured formal battle.
const P=preload("res://scripts/world3d/projection.gd")
func _initialize():call_deferred("run")
func settle():
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
func project_weapon(node:Node,anchor:Vector3):
 if node is MeshInstance3D:
  for i in node.mesh.get_surface_count():
   var original=node.get_active_material(i)
   if not original is StandardMaterial3D:continue
   var material:=ShaderMaterial.new();material.shader=load("res://scripts/world3d/weapon_portrait.gdshader")
   material.set_shader_parameter("base_color",original.albedo_color)
   material.set_shader_parameter("base_texture",original.albedo_texture)
   material.set_shader_parameter("textured",original.albedo_texture!=null)
   material.set_shader_parameter("roughness",original.roughness);material.set_shader_parameter("metallic",original.metallic)
   material.set_shader_parameter("portrait_anchor",anchor);material.set_shader_parameter("portrait_weight",1.0)
   node.set_surface_override_material(i,material)
 for child in node.get_children():project_weapon(child,anchor)
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 var travel_mode:bool="--travel" in OS.get_cmdline_user_args()
 var atmosphere_reference:bool=not ("--reference-no-atmosphere" in OS.get_cmdline_user_args())
 var prefix:String="res://../tempassets/work/world3d-travel" if travel_mode else "res://../tempassets/work/world3d-party"
 if app.theme_key not in ["connected","forest"]:prefix+="-"+app.theme_key
 if travel_mode:
  app.start_travel()
  for tick in 140:app._process(.01)
  assert(app.phase=="travel")
  app.preview.hide()
 var weak_mode:bool="--weak-projection" in OS.get_cmdline_user_args()
 app.portrait_mode=weak_mode
 app.atmosphere_mode="--actor-atmosphere" in OS.get_cmdline_user_args()
 for actor in app.team:actor.portrait_presenter.set_enabled(weak_mode);actor.portrait_presenter.sync()
 app.actor_atmosphere.set_enabled(app.atmosphere_mode);app.actor_atmosphere.sync(app.bridge,weak_mode)
 if app.atmosphere_mode:prefix+="-atmosphere"
 for child in app.get_children():
  if child is CanvasLayer:child.hide()
 var portraits:Array=[];var actors:Array[Dictionary]=[];var report:Array=[]
 for i in app.team.size():
  var native=app.team[i];var slot:Dictionary=app.profiles[app.team_slots[i]]
  if native.opacity<.001:continue
  var portrait=load("res://scripts/battle/enemy_actor.gd").new();portrait.ally=true
  portrait.model_scene=load("res://assets/characters3d/"+native.model_key);root.add_child(portrait)
  portrait.body.rotation.y=native.rotation.y+app.bridge.heading
  for bone in native.rig.get_bone_count():
   portrait.rig.set_bone_pose_position(bone,native.rig.get_bone_pose_position(bone))
   portrait.rig.set_bone_pose_rotation(bone,native.rig.get_bone_pose_rotation(bone))
   portrait.rig.set_bone_pose_scale(bone,native.rig.get_bone_pose_scale(bone))
  for bone in native.rig.get_bone_count():
   assert(portrait.rig.get_bone_global_pose(bone).is_equal_approx(native.rig.get_bone_global_pose(bone)),"Reference must preserve the exact native rig pose")
  portrait.scene_light_tint=app.bridge.environment_light_tint()
  portrait.update_team_light("travel" if travel_mode else "battle",0);portraits.append(portrait)
  var position:Vector2=Vector2(native.position.x,-native.position.z)*20
  var foot:Vector2=P.project_reference(position,native.position.y*20,Vector2(root.size),app.bridge.camera_world,app.bridge.heading,app.frame.height,app.frame.lens,app.frame.horizon)
  var relative:Vector2=ForestRoute.to_camera(position,app.bridge.camera_world,app.bridge.heading)
  var height:float=slot.height*app.bridge.focal()/relative.y
  var rect:=Rect2(foot-Vector2(height*640.0/768*.5,height*portrait.ground_uv()),Vector2(height*640.0/768,height))
  for name in ["頭","首","手首.L","手首.R","足首.L","足首.R"]:
   var bone:int=native.rig.find_bone(name)
   if bone<0:continue
   var expected:Vector2=rect.position+portrait.actor_camera.unproject_position(portrait.rig.global_transform*portrait.rig.get_bone_global_pose(bone).origin)/Vector2(portrait.viewport.size)*rect.size
   var actual:Vector2=app.camera.unproject_position(native.rig.global_transform*native.rig.get_bone_global_pose(bone).origin)
   var anchor_view:Vector3=app.camera.to_local(native.global_position)
   var vertex_view:Vector3=app.camera.to_local(native.rig.global_transform*native.rig.get_bone_global_pose(bone).origin)
   var delta:Vector3=vertex_view-anchor_view
   var weak:Vector2=foot+Vector2(delta.x,-delta.y)*app.bridge.focal()/(-anchor_view.z)
   if weak_mode:actual=weak
   report.append({"model":native.model_key,"bone":name,"reference":[expected.x,expected.y],"native":[actual.x,actual.y],"error_pixels":actual.distance_to(expected),"weak_projection_error":weak.distance_to(expected),"local_depth":delta.z,"camera_depth":-anchor_view.z})
  actors.append({"actor":true,"live_companion":true,"born_at":-100.0,"hidden":false,"position":position,"texture":portrait.texture(),"w":slot.height*640.0/768,"h":slot.height,"altitude":slot.clearance,"ground_anchor":Vector2(.5,portrait.ground_uv()),"flip":false,"kind":0,"id":200000+i,"region":app.world.camera_region,"motion":"static","ecology_tint":Color.WHITE})
 for item in app.props:
  if item.node.modulate.a<.001:continue
  var slot:Dictionary=app.profiles[item.slot];var texture:Texture2D=item.node.texture
  var position:Vector2=Vector2(item.node.position.x,-item.node.position.z)*20
  actors.append({"actor":true,"born_at":-100.0,"hidden":false,"position":position,"texture":texture,"w":slot.height*texture.get_width()/float(texture.get_height()),"h":slot.height,"altitude":slot.clearance,"ground_anchor":Vector2(.5,1),"flip":false,"kind":0,"id":210000+item.slot,"region":app.world.camera_region,"motion":"static","ecology_tint":Color.WHITE})
 await settle()
 root.get_texture().get_image().save_png(prefix+("-weak-projection.png" if weak_mode else "-native.png"))
 for native in app.team:native.hide()
 var old:=SegmentView.new();old.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(old);old.setup(ForestArt.new(),app.world,1,ThemeDB.fallback_font)
 old.renderer.runtime_camera=app.frame.duplicate();old.renderer.lantern_enabled=atmosphere_reference;old.renderer.battle_frame_shift=app.bridge.battle_frame_shift
 old.renderer.battle_actors=actors
 old.sync(app.bridge.camera_world,app.bridge.heading,app.clock,0,app.branch,false,false,app.distance)
 old.renderer.environment=app.world.environment();old.renderer.queue_redraw()
 await settle()
 root.get_texture().get_image().save_png(prefix+("-reference.png" if atmosphere_reference else "-reference-no-atmosphere.png"))
 if app.atmosphere_mode:
  var native_material:ShaderMaterial=app.actor_atmosphere.entries[0].material
  var reference_material:ShaderMaterial=old.renderer.forest_batch.material
  for key in ["lantern_position","team_light_energy","team_light_radius","team_light_color","lantern_forward","fog_range","fog_color","environment_light_tint","atmosphere_time"]:
   var a=native_material.get_shader_parameter(key);var b=reference_material.get_shader_parameter(key)
   if a!=b:print("ATMOSPHERE_PARAMETER_DIFFERENCE ",key," native=",a," reference=",b)
 var markers:=Node2D.new();root.add_child(markers)
 markers.draw.connect(func():
  for item in report:
   var actual:=Vector2(item.native[0],item.native[1]);var expected:=Vector2(item.reference[0],item.reference[1])
   markers.draw_line(expected,actual,Color(.9,.4,.2),2)
   markers.draw_circle(expected,5,Color(1,.8,.1),false,2)
   markers.draw_circle(actual,4,Color(.1,.9,1),false,2))
 markers.queue_redraw();await settle()
 root.get_texture().get_image().save_png(prefix+("-weak-overlay.png" if weak_mode else "-landmark-overlay.png"))
 var output:=FileAccess.open(prefix+("-weak-landmarks.json" if weak_mode else "-landmarks.json"),FileAccess.WRITE);output.store_string(JSON.stringify(report,"  "))
 print("WORLD3D_PARTY_COMPARISON_READY real original portrait cameras and production renderer; landmarks=",report.size())
 quit()
