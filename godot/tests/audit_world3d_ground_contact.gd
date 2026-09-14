extends SceneTree
const GRID=preload("res://scripts/world3d/ground_grid.gd")
func _initialize():call_deferred("run")
func run():
 if DisplayServer.get_name()=="headless":push_error("Contact audit requires actual MultiMesh GPU readback");quit(1);return
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
 while not app.stage or not app.stage.ready_stage:await process_frame
 var stage=app.stage;stage.set_process(false);stage._process(0)
 var all_placements:bool="--all-placements" in OS.get_cmdline_user_args()
 var view_heading:float=stage.bridge.heading
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--heading="):view_heading=float(argument.get_slice("=",1))
 assert(not stage.scenery.conform_bases,"This audit measures original upright geometry; use GPU contact validation for deformed bases")
 var profiles:Dictionary={};var results:Dictionary={};var instances:=0;var buried:=0;var excluded_deformed:=0
 for chunk in stage.scenery.chunks:
  if not all_placements and not chunk.visible:continue
  var mm:MultiMesh=chunk.multimesh
  var texture:Texture2D=mm.mesh.surface_get_material(0).get_shader_parameter("art")
  if not profiles.has(texture):
   var image:=texture.get_image();var bottoms:Array=[]
   for column in 17:
    var x:=roundi(float(column)/16*(image.get_width()-1));var bottom:=-1.0
    for y in range(image.get_height()-1,-1,-1):
     if image.get_pixel(x,y).a>.5:bottom=(y+.5)/image.get_height();break
    bottoms.append(bottom)
   profiles[texture]=bottoms
  var path:String=mm.mesh.surface_get_material(0).get_meta("source_asset",texture.resource_path)
  for original in stage.scenery.by_texture:
   if path.is_empty() and stage.scenery.by_texture[original].get_shader_parameter("art")==texture:path=original.resource_path;break
  if path.is_empty():path="generated-texture-"+str(texture.get_instance_id())
  if not results.has(path):results[path]={"texture":path,"instances":0,"buried_instances":0,"worst_metres":0.0,"floating_candidates":0,"max_support_gap":0.0,"roles":{},"examples":[],"floating_examples":[]}
  for i in mm.instance_count:
   var custom:Color=mm.get_instance_custom_data(i);var mode:int=int(absf(custom.b))%8
   if mode>=3:excluded_deformed+=1;continue
   var tr:Transform3D=mm.get_instance_transform(i);var size:Vector3=tr.basis.get_scale()
   if size.x<.0001:continue
   var view:Vector3=stage.camera.to_local(tr.origin)
   if not all_placements and (-view.z*20<16 or -view.z*20>1700):continue
   if not all_placements and absf(view.x)>-view.z*stage.bridge.view_size.x/(2*stage.bridge.focal())+size.x:continue
   var angle:float=custom.a if mode==2 else view_heading
   var support_delta:=0.0
   if int(absf(custom.b))>=32:
    var offset:float=(.5-custom.r)*size.x*signf(custom.b)
    var support:=tr.origin+Vector3(cos(angle)*offset,0,sin(angle)*offset)
    support_delta=(ForestEcology.height_at(Vector2(support.x,-support.z)*20)-ForestEcology.height_at(Vector2(tr.origin.x,-tr.origin.z)*20))/20
   var lowest:=INF
   for column in 17:
    var bottom:float=profiles[texture][column]
    if bottom<0:continue
    var x:float=(column/16.0-custom.r)*size.x*signf(custom.b)
    var world:Vector3=tr.origin+Vector3(cos(angle)*x,(custom.g-bottom)*size.y,sin(angle)*x)
    world.y+=support_delta
    var terrain:float=GRID.support_height(Vector2(world.x,world.z))
    lowest=minf(lowest,world.y-terrain)
   if lowest==INF:continue
   instances+=1;results[path].instances+=1
   var role:String=chunk.get_meta("contact_roles",[])[i]
   results[path].roles[role]=int(results[path].roles.get(role,0))+1
   if lowest<-.02:
    buried+=1;results[path].buried_instances+=1;results[path].worst_metres=maxf(results[path].worst_metres,-lowest)
    if results[path].examples.size()<3:results[path].examples.append({"anchor":[custom.r,custom.g],"height":size.y,"depth_below_ground":-lowest})
   if lowest>.02:
    results[path].floating_candidates+=1;results[path].max_support_gap=maxf(results[path].max_support_gap,lowest)
    if results[path].floating_examples.size()<3:results[path].floating_examples.append({"anchor":[custom.r,custom.g],"height":size.y,"support_gap":lowest,"role":role})
 var ordered:Array=results.values();ordered.sort_custom(func(a,b):return a.worst_metres>b.worst_metres)
 var report:Dictionary={"theme":stage.theme_key,"all_placements":all_placements,"view_heading":view_heading,"scope":"Upright cutouts, opaque alpha foot samples against actual metre-grid triangle interpolation; not full pixel intersection. Optional all-placements checks all initially built route chunks, not ungenerated future routes. Deformed mesh counts are excluded, never treated as validated contacts.","excluded_deformed_instances":excluded_deformed,"instances":instances,"buried_instances":buried,"textures":ordered}
 var suffix:String=("-all-"+str(view_heading)) if all_placements else ""
 FileAccess.open("res://../tempassets/work/world3d-ground-contact-audit-"+stage.theme_key+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 FileAccess.open("res://../tempassets/work/world3d-ground-contact-audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("GROUND_CONTACT_AUDIT instances=",instances," buried=",buried," texture_count=",ordered.size())
 for i in mini(8,ordered.size()):print(JSON.stringify(ordered[i]))
 var hovering:Array=ordered.duplicate();hovering.sort_custom(func(a,b):return a.max_support_gap>b.max_support_gap)
 print("SUPPORT_GAP_CANDIDATES (includes deliberately elevated art; not automatic errors)")
 for i in mini(8,hovering.size()):print(JSON.stringify(hovering[i]))
 quit()
