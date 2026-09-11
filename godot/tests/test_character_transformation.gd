extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1600,1000)
 var app=load("res://scenes/character_transformation_editor.tscn").instantiate();root.add_child(app)
 app.viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 await process_frame
 app.playing=false
 for model_index in range(app.MODELS.size()):
  app.select_model(model_index);app.playing=false
  assert(not app.fitted.is_empty())
  for effect_mode in [0,1]:
   for amount in [0.0,.5,1.0]:
    app.mode=effect_mode;app.progress=amount;app.update_effect()
    await process_frame
    await RenderingServer.frame_post_draw
    if model_index==4:app.viewport.get_texture().get_image().save_png("F:/GitHub/project18buxiuxiuxian/tempassets/work/transformation-%d-%s.png"%[effect_mode,str(amount)])
 app.select_model(3);app.skull_control.value=.8
 app.select_model(4);app.skull_control.value=1.3
 app.select_model(3);assert(is_equal_approx(app.skull_control.value,.8))
 app.select_model(4);assert(is_equal_approx(app.skull_control.value,1.3))
 # Head adjustment must leave every vertex without head influence untouched.
 var before:Array=[]
 for mesh in app.fitted:
  for surface in range(mesh.mesh.get_surface_count()):before.append(mesh.mesh.surface_get_arrays(surface))
 app.skull_control.value=1.8
 var surface_index:=0;var unchanged:=0;var changed:=0
 var head:int=app.rig.find_bone("頭")
 for mesh in app.fitted:
  for surface in range(mesh.mesh.get_surface_count()):
   var after:Array=mesh.mesh.surface_get_arrays(surface)
   var previous:Array=before[surface_index];surface_index+=1
   var stride:int=after[Mesh.ARRAY_BONES].size()/after[Mesh.ARRAY_VERTEX].size()
   for v in range(after[Mesh.ARRAY_VERTEX].size()):
    var head_weight:=0.0
    for k in range(stride):
     var slot:int=v*stride+k
     if after[Mesh.ARRAY_BONES][slot]==head:head_weight+=after[Mesh.ARRAY_WEIGHTS][slot]
    var distance:float=after[Mesh.ARRAY_VERTEX][v].distance_to(previous[Mesh.ARRAY_VERTEX][v])
    if head_weight<.00001:assert(distance<.00001);unchanged+=1
    elif distance>.00001:changed+=1
 assert(unchanged>0 and changed>0)
 app.skull_control.value=1.3
 for expression in range(4):
  app.material_control.item_selected.emit(expression)
  app.mode=0;app.progress=.65;app.update_effect()
  await create_timer(.05).timeout
  await RenderingServer.frame_post_draw
  app.viewport.get_texture().get_image().save_png("F:/GitHub/project18buxiuxiuxian/tempassets/work/transformation-style-%d.png"%expression)
 var path:String=app.SAVE
 var existed:=FileAccess.file_exists(path)
 var saved:=FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
 app.preset_name.text="test-transform";app.mode=1;app.duration=3.5;app.opacity=.6;app.save_preset()
 app.mode=0;app.duration=8
 for i in range(app.preset_list.item_count):
  if app.preset_list.get_item_text(i)=="test-transform":app.load_preset(i);break
 assert(is_equal_approx(app.skull_control.value,1.3))
 assert(app.mode==1 and is_equal_approx(app.duration,3.5) and is_equal_approx(app.opacity,.6))
 assert(app.material_style==3)
 if existed:
  var file:=FileAccess.open(path,FileAccess.WRITE);file.store_buffer(saved);file.close()
 else:DirAccess.remove_absolute(path)
 print("TRANSFORMATION_PASS all roster models, both modes, start/mid/end and preset roundtrip")
 quit()
