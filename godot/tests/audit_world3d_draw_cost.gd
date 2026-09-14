extends SceneTree
func _initialize():call_deferred("run")
func measure()->Dictionary:
 for i in 4:await process_frame
 var calls:Array=[];var primitives:Array=[]
 for i in 12:
  await process_frame
  calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
  primitives.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
 calls.sort();primitives.sort()
 return {"draw_calls":calls[6],"primitives":primitives[6]}
func census(node:Node,result:Dictionary):
 if node is GeometryInstance3D:node.layers=2
 if node is MeshInstance3D and node.mesh!=null and node.is_visible_in_tree():
  result.meshes+=1;result.surfaces+=node.mesh.get_surface_count()
  for index in node.mesh.get_surface_count():
   var material:Material=node.get_active_material(index)
   if not material is ShaderMaterial:continue
   var texture=material.get_shader_parameter("base_texture")
   var texture_key:String=texture.resource_path if texture is Texture2D else "untextured"
   var key:String=texture_key+"|"+str(material.get_shader_parameter("base_color"))
   result.material_classes[key]=int(result.material_classes.get(key,0))+1
 for child in node.get_children():census(child,result)
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 root.size=Vector2i(1440,900)
 var shell=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(shell)
 while not shell.stage or not shell.stage.ready_stage:await process_frame
 var stage=shell.stage;stage.set_process(false);seed(714603);stage.start_battle()
 for i in 240:stage._process(1.0/60);await process_frame
 stage.process_mode=Node.PROCESS_MODE_DISABLED
 var actors:Array=stage.team+[stage.preview]
 for slot in stage.enemy_pool:actors.append(slot.actor)
 var visible:Array=actors.filter(func(actor):return actor.visible)
 var models:Dictionary={}
 for actor in visible:
  if not models.has(actor.model_key):models[actor.model_key]={"actors":0,"meshes":0,"surfaces":0,"material_classes":{}}
  models[actor.model_key].actors+=1;census(actor,models[actor.model_key])
 var report:Dictionary={"scope":"Frozen same battle frame; diagnostic render removal only, not a proposed visual reduction or a frame-time benchmark","visible_actors":visible.size(),"models":models}
 report.baseline=await measure()
 stage.actor_atmosphere.set_enabled(false)
 report.without_actor_atmosphere=await measure()
 stage.actor_atmosphere.set_enabled(true)
 report.after_atmosphere_restore=await measure()
 var original_mask:int=stage.camera.cull_mask
 stage.camera.cull_mask=original_mask & ~2
 report.without_actors=await measure()
 stage.camera.cull_mask=original_mask
 report.after_actor_restore=await measure()
 stage.scenery.hide()
 report.without_scenery=await measure()
 stage.scenery.show()
 report.restored=await measure()
 FileAccess.open("res://../tempassets/work/world3d-draw-cost.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("WORLD3D_DRAW_COST ",JSON.stringify(report))
 assert(report.baseline==report.restored,"Diagnostic toggles must restore the original draw workload")
 quit()

