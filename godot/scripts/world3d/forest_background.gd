extends MeshInstance3D
var material:=ShaderMaterial.new()
var cached:Dictionary={}
func _init():
 mesh=QuadMesh.new();mesh.size=Vector2(2,2)
 material.shader=preload("res://scripts/world3d/forest_background.gdshader")
 # This shader moves the quad to the far plane, but its node lives by the
 # camera. Draw it before transparent foliage, rather than sorting by that node.
 material.render_priority=-128
 material_override=material
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 position.z=-1
func sync(renderer):
 visible=str(renderer.world.camera_region.space.key)=="forest"
 if not visible:return
 var env:Dictionary=renderer.environment
 var values:Dictionary={"sky_top":env.a.top_color.lerp(env.b.top_color,env.weight),"sky_bottom":env.a.atmosphere.haze_color.lerp(env.b.atmosphere.haze_color,env.weight),"horizon":renderer.horizon_y()/renderer.view_size.y,"lantern_enabled":renderer.lantern_enabled,"far_distance":get_parent().far}
 values.merge({"far_ground":env.a.atmosphere.depth_color.lerp(env.b.atmosphere.depth_color,env.weight),"camera_world":renderer.camera_world,"resolution":renderer.view_size,"heading":renderer.heading,"camera_height":renderer.camera_height(),"focal":renderer.focal(),"lantern_position":renderer.lantern_position(),"lantern_forward":Vector2(sin(renderer.heading),cos(renderer.heading)),"atmosphere_time":renderer.elapsed})
 values.merge(renderer.biome_parameters());values.merge(renderer.combat_light_parameters())
 for key in values:
  if cached.get(key)==values[key]:continue
  material.set_shader_parameter(key,values[key]);cached[key]=values[key]
