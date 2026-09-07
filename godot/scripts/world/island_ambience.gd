class_name IslandAmbience
extends Node3D
## Separate world-space atmosphere; never participates in exploration or picking.
var view: IslandView3D
var clouds: Array[Dictionary] = []
func setup(target: IslandView3D) -> void:
	view = target
	var rng := RandomNumberGenerator.new()
	rng.seed = 8271
	for i in range(22):
		var layer := i%3
		var angle := TAU*float(i)/22
		var radius := 3.5+layer*1.5+rng.randf_range(-.4,.4)
		var tex: Texture2D = load(StyleLibrary.path("res://assets/cloudsea/puff-%d.png" % (i%4+1)))
		var mesh := QuadMesh.new()
		var width := 3.0+layer*.6
		mesh.size = Vector2(width,width*tex.get_height()/tex.get_width())
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.basis = view.camera.basis
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = tex
		mat.albedo_color = Color(.57,.66,.62,.13-layer*.025)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = -20
		instance.material_override = mat
		add_child(instance)
		clouds.append({"node":instance,"base":Vector3(cos(angle)*radius,-1.2-layer*.75,sin(angle)*radius),"phase":rng.randf()*TAU,"speed":.022-layer*.005})
func _process(_dt: float) -> void:
	if not view: return
	for cloud in clouds:
		var p: Vector3 = cloud.base
		p.x += sin(view.model.elapsed*cloud.speed+cloud.phase)*1.3
		cloud.node.position = p
