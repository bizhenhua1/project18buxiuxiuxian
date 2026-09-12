extends Node
# A single merged silhouette avoids drawing every hair/material normal as a separate rim.
var mask:SubViewport
var mask_camera:Camera3D
var copy:Node3D
var copy_rig:Skeleton3D
var screen:MeshInstance3D
var material:ShaderMaterial
func setup(actor):
 mask=SubViewport.new();mask.own_world_3d=true;mask.transparent_bg=true
 mask.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(mask)
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color.BLACK
 mask.add_child(env)
 mask_camera=Camera3D.new();mask_camera.projection=Camera3D.PROJECTION_ORTHOGONAL;mask.add_child(mask_camera);mask_camera.current=true
 copy=load("res://assets/characters3d/"+actor.MODELS[actor.selected_model].file).instantiate()
 mask.add_child(copy);actor.disable_animation(copy);copy_rig=actor.find_rig(copy)
 prepare(copy)
 screen=MeshInstance3D.new();screen.mesh=QuadMesh.new();screen.mesh.size=Vector2(2,2)
 screen.extra_cull_margin=16384;screen.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 material=ShaderMaterial.new();material.shader=preload("res://shaders/world_hero_occlusion.gdshader")
 material.render_priority=100;material.set_shader_parameter("actor_mask",mask.get_texture())
 screen.material_override=material;actor.add_child(screen)
func prepare(node:Node):
 if node is MeshInstance3D:
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  for i in node.mesh.get_surface_count():
   var original=node.get_active_material(i)
   var shader:=ShaderMaterial.new();shader.shader=preload("res://shaders/world_hero_mask.gdshader")
   if original is StandardMaterial3D:
    shader.set_shader_parameter("textured",original.albedo_texture!=null)
    shader.set_shader_parameter("art",original.albedo_texture)
    shader.set_shader_parameter("opacity",original.albedo_color.a)
   node.set_surface_override_material(i,shader)
 for child in node.get_children():prepare(child)
func sync(actor,view:IslandView3D):
 mask.size=view.viewport.size
 mask_camera.global_transform=view.camera.global_transform
 mask_camera.size=view.camera.size;mask_camera.near=view.camera.near;mask_camera.far=view.camera.far
 mask_camera.keep_aspect=view.camera.keep_aspect
 mask_camera.v_offset=view.camera.v_offset;mask_camera.h_offset=view.camera.h_offset
 copy.global_transform=actor.body.global_transform
 for i in actor.rig.get_bone_count():
  copy_rig.set_bone_pose_position(i,actor.rig.get_bone_pose_position(i))
  copy_rig.set_bone_pose_rotation(i,actor.rig.get_bone_pose_rotation(i))
  copy_rig.set_bone_pose_scale(i,actor.rig.get_bone_pose_scale(i))
 material.set_shader_parameter("pixel_size",Vector2.ONE/Vector2(mask.size))
func _exit_tree():
 if is_instance_valid(screen):screen.queue_free()
