extends SceneTree
class Owner extends Node3D:
 var opacity:=1.0
 var fade_materials:Array=[]
 var attachments:Array=[]
func _initialize():call_deferred("run")
func run():
 var actor:=Owner.new();root.add_child(actor)
 var weapon:=MeshInstance3D.new();weapon.mesh=BoxMesh.new()
 var original:=StandardMaterial3D.new();original.albedo_color=Color(.4,.5,.6,.8)
 weapon.mesh.material=original;actor.add_child(weapon);actor.attachments=[weapon]
 var presenter=preload("res://scripts/world3d/portrait_presenter.gd").new();presenter.setup(actor)
 presenter.set_enabled(false)
 assert(presenter.weapons.size()==1,"Default 3D must prepare fading without first enabling portrait projection")
 actor.opacity=.4;presenter.sync_opacity()
 var active=weapon.get_active_material(0)
 assert(is_equal_approx(active.albedo_color.a,.32))
 assert(active.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_HASH)
 assert(is_equal_approx(original.albedo_color.a,.8),"Shared source material must remain untouched")
 presenter.set_enabled(true)
 assert(is_equal_approx(float(weapon.get_active_material(0).get_shader_parameter("actor_opacity")),.4))
 presenter.set_enabled(false);presenter.set_enabled(false)
 assert(presenter.weapons.size()==1,"Repeated toggle must not duplicate weapon materials")
 actor.opacity=1;presenter.sync_opacity()
 assert(weapon.get_active_material(0).transparency==original.transparency)
 assert(is_equal_approx(weapon.get_active_material(0).albedo_color.a,.8))
 print("WORLD3D_WEAPON_FADE_PASS native and portrait modes, source isolation, fade restore")
 quit()
