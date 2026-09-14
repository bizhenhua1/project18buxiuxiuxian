extends MultiMeshInstance3D
# A test-range marker in the same world as the effect; not screen-space UI.
func _ready():
 var ring:=TorusMesh.new();ring.inner_radius=.965;ring.outer_radius=1.0;ring.rings=48;ring.ring_segments=4
 var material:=ShaderMaterial.new();material.shader=preload("res://scripts/world3d/area_marker.gdshader")
 ring.material=material
 multimesh=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.use_colors=true;multimesh.mesh=ring
 multimesh.instance_count=64;multimesh.visible_instance_count=0;cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func sync(zones:Array):
 multimesh.mesh.material.set_shader_parameter("terrain_amplitude",ForestSettings.values.height)
 multimesh.visible_instance_count=zones.size()
 for i in zones.size():
  var zone:Dictionary=zones[i]
  multimesh.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(zone.radius,.18,zone.radius)),zone.center+Vector3.UP*.08))
  multimesh.set_instance_color(i,Color(.2,.85,.7,clampf((zone.duration-zone.age)*2,0,.65)))
