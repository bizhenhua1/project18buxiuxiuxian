extends SceneTree
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_stage.tscn").instantiate();root.add_child(app)
 while not app.ready_stage:await process_frame
 app.set_process(false)
 var checks:=0;var peak_saving:=0
 for sample in [Vector3(0,0,0),Vector3(500,300,.6),Vector3(-400,700,-.4),Vector3(0,0,0)]:
  app.bridge.camera_world=Vector2(sample.x,sample.y);app.bridge.heading=sample.z;app.bridge.elapsed+=.37
  app.scenery.update_all_materials=false;app.scenery.update_view(app.bridge)
  var saved:Dictionary={}
  var names:Array=["lantern_position","heading","atmosphere_time","fog_color","team_light_energy","team_light_color","combat_light_positions","biome_kind"]
  for mat in app.scenery.visible_materials:
   var values:Array=[]
   for key in names:values.append(mat.get_shader_parameter(key))
   saved[mat]=values
  peak_saving=maxi(peak_saving,app.scenery.materials.size()+1-app.scenery.material_updates)
  app.scenery.update_all_materials=true;app.scenery.update_view(app.bridge)
  for mat in saved:
   for i in names.size():
    assert(saved[mat][i]==mat.get_shader_parameter(names[i]),"Visible material has stale state after camera change")
    checks+=1
 assert(peak_saving>0,"Invisible material updates should be avoided")
 print("WORLD3D_VISIBLE_MATERIALS_PASS checks=",checks," peak_skipped_materials=",peak_saving)
 quit()
