extends SceneTree
func _initialize():call_deferred("run")
func controllers(node:Node)->Array:
 var found:Array=[]
 if node.get_script()==load("res://scripts/battle/character_ink_material.gd"):found.append(node)
 for child in node.get_children():found.append_array(controllers(child))
 return found
func capture(name:String):
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://../tempassets/work/world3d-material-"+name+".png")
func run():
 root.size=Vector2i(1440,900)
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false);app._process(0)
 await capture("current")
 for actor in app.team:
  for controller in controllers(actor):
   controller.set_process(false)
   for surface in controller.surfaces:surface.material.next_pass=null
 await capture("no-outline")
 for actor in app.team:
  for controller in controllers(actor):
   for surface in controller.surfaces:surface.mesh.set_surface_override_material(surface.index,surface.original)
 await capture("original")
 print("WORLD3D_MATERIAL_COMPARISON_READY same camera, pose and geometry")
 quit()
