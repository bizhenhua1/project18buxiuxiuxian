extends SceneTree
func _initialize():
 var fit=load("res://scripts/spaces/skeleton_fit.gd")
 for file in ["transformation-skeleton.glb","gentleman.glb","isabella.glb"]:
  var model=load("res://assets/characters3d/"+file).instantiate()
  var rig=fit.rig_of(model)
  print(file)
  for bone in ["下半身","上半身","上半身2","首","頭","足.L","足.R","肩.L"]:
   var id=rig.find_bone(bone)
   if id>=0:print(bone," ",rig.get_bone_global_rest(id).origin," scale ",rig.get_bone_global_rest(id).basis.get_scale())
  model.free()
 quit()
