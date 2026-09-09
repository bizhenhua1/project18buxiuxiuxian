extends RefCounted
## Runtime copy of the Shader browser's "Black ink / bold line" preset.
const SURFACE=preload("res://shaders/character_study.gdshader")
const OUTLINE=preload("res://shaders/character_study_outline.gdshader")
static func apply(root:Node) -> void:
 if root is MeshInstance3D:
  for i in range(root.mesh.get_surface_count()):
   var original=root.get_active_material(i)
   if not original is StandardMaterial3D:continue
   var material=ShaderMaterial.new();material.shader=SURFACE
   material.set_shader_parameter("base_texture",original.albedo_texture)
   material.set_shader_parameter("textured",original.albedo_texture!=null)
   material.set_shader_parameter("base_color",original.albedo_color)
   var parameters={"style":2,"threshold":.52,"softness":.03,"ambient":.22,"saturation":.55,"ink":.35,"shadow_color":Color("#18232e")}
   for key in parameters:material.set_shader_parameter(key,parameters[key])
   var outline=ShaderMaterial.new();outline.shader=OUTLINE
   outline.set_shader_parameter("base_texture",original.albedo_texture)
   outline.set_shader_parameter("textured",original.albedo_texture!=null)
   outline.set_shader_parameter("opacity",original.albedo_color.a)
   outline.set_shader_parameter("width",.012)
   outline.set_shader_parameter("ink_color",Color("#0c1119"))
   material.next_pass=outline
   root.set_surface_override_material(i,material)
 for child in root.get_children():apply(child)
