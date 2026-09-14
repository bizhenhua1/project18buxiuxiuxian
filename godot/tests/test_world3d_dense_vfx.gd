extends SceneTree
func _initialize():
 var profiles:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world3d_vfx_budgets.json"))
 var view=preload("res://scripts/world3d/projectile_view.gd")
 for kind in ["missile","impact","muzzle"]:
  var normal:Array=view.requested_caps(profiles,kind,23)
  var dense:Array=view.requested_caps(profiles,kind,24)
  assert(normal==profiles.ordinary[kind].caps)
  assert(dense==profiles.dense.caps[kind] and dense[0]==normal[0],"Core survives density reduction")
  assert(view.requested_caps(profiles,kind,200)==dense)
  assert(view.requested_caps(profiles,kind,0)==normal,"New effects recover after crowd clears")
  dense[0]=0
  assert(profiles.dense.caps[kind][0]>0,"Reservations must not mutate the profile")
 print("WORLD3D_DENSE_VFX_PASS threshold, core, recovery, independent caps")
 quit()
