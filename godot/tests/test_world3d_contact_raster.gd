extends SceneTree
const GEOMETRY=preload("res://scripts/world3d/contact_geometry.gd")
func _initialize():call_deferred("run")
func terrain(p:Vector2,amplitude:float)->float:
 return (2.2*sin(p.y*.009)+1.3*sin(p.x*.017+p.y*.004))*amplitude/20.0
func snapshot()->Image:
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func green(c:Color)->bool:return c.g>.05 and c.g>c.r*1.5 and c.g>c.b*1.5
func run():
 if DisplayServer.get_name()=="headless":quit(1);return
 root.size=Vector2i(480,400)
 var scene:=Node3D.new();root.add_child(scene)
 var camera:=Camera3D.new();scene.add_child(camera);camera.current=true;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=4
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color.BLACK;scene.add_child(environment)
 var anchors:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/forest_asset_anchors.json"))

 var geometry:Mesh=GEOMETRY.base_contact_mesh()
 var material:=ShaderMaterial.new();material.shader=load("res://scripts/world3d/cutout.gdshader")
 if "--dense-foot" in OS.get_cmdline_user_args():material.set_shader_parameter("precise_ground_contact",true)
 material.set_shader_parameter("fog_range",Vector2(10000,20000))
 geometry.surface_set_material(0,material)
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=geometry;mm.instance_count=1
 mm.set_instance_color(0,Color.WHITE)
 var node:=MultiMeshInstance3D.new();node.multimesh=mm;scene.add_child(node);node.extra_cull_margin=20
 var with_ground:bool="--ground-mesh" in OS.get_cmdline_user_args()
 var floor_node:=MeshInstance3D.new();scene.add_child(floor_node)
 floor_node.mesh=preload("res://scripts/world3d/ground_grid.gd").mesh()
 var floor_shader:=Shader.new();var source:String=load("res://scripts/world3d/ground.gdshader").code
 # Preserve the production vertex shader and grid; neutralize only fragment color.
 floor_shader.code=source.substr(0,source.find("void fragment(){"))+"void fragment(){ALBEDO=vec3(.2);}"
 if "--contact-plane-ground" in OS.get_cmdline_user_args():
  # Diagnostic cross-section: exclude terrain between the camera and the
  # upright artwork plane. This separates foreground hills from penetration.
  floor_shader.code=source.substr(0,source.find("void fragment(){"))+"uniform vec2 diagnostic_origin; uniform float diagnostic_angle; void fragment(){vec2 p=vec2(floor_world.x,-floor_world.y)/20.0; if(p.y>diagnostic_origin.y+tan(diagnostic_angle)*(p.x-diagnostic_origin.x)+.001)discard; ALBEDO=vec3(.2);}"
 var floor_material:=ShaderMaterial.new();floor_material.shader=floor_shader;floor_node.material_override=floor_material;floor_node.hide()
 var max_lost_fraction:=0.0
 var worst:=0.0;var checks:=0
 var curved:bool="--curved-foot" in OS.get_cmdline_user_args()
 var rigid:bool="--rigid-anchor" in OS.get_cmdline_user_args()
 var skirt:bool="--ground-skirt" in OS.get_cmdline_user_args()
 var asset:=""
 var requested_height:=0.0
 var requested_width:=0.0
 var requested_pitch:=0.0
 var terrain_origin:=Vector2(10,0)
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--asset="):asset=argument.get_slice("=",1)
  if argument.begins_with("--height="):requested_height=float(argument.get_slice("=",1))
  if argument.begins_with("--width="):requested_width=float(argument.get_slice("=",1))
  if argument.begins_with("--pitch="):requested_pitch=float(argument.get_slice("=",1))
  if argument.begins_with("--origin="):
   var coordinates:=argument.get_slice("=",1).split(",")
   if coordinates.size()!=2:push_error("Expected --origin=x,z");quit(1);return
   terrain_origin=Vector2(float(coordinates[0]),float(coordinates[1]))
 for bottom in ([.98] if not asset.is_empty() else [.9,.98]):
  var pixels:=Image.create(128,128,false,Image.FORMAT_RGBA8)
  if not asset.is_empty():
   var source_texture:Texture2D=load("res://assets/"+asset+".png") if asset.contains("/") else load("res://assets/style2/"+asset+".png")
   if source_texture==null:push_error("Missing contact fixture asset: "+asset);quit(1);return
   pixels=source_texture.get_image();pixels.convert(Image.FORMAT_RGBA8)
   for y in pixels.get_height():
    for x in pixels.get_width():pixels.set_pixel(x,y,Color(0,1,0,pixels.get_pixel(x,y).a))
  else:
   for y in 128:
    for x in 128:
     var edge:float=bottom-.08*(.5+.5*cos(float(x)/127*TAU)) if curved else bottom
     pixels.set_pixel(x,y,Color(0,1,0,1) if (y+.5)/128.0<=edge else Color.TRANSPARENT)
  var actual_bottom:float=(floor(bottom*128-.5)+.5)/128
  material.set_shader_parameter("art",ImageTexture.create_from_image(pixels))
  var profile:=PackedFloat32Array()
  for column in 17:
   var x:=roundi(column/16.0*(pixels.get_width()-1));var foot:=1.0
   for y in range(pixels.get_height()-1,int(pixels.get_height()*.7),-1):
    if pixels.get_pixel(x,y).a>.5:foot=(y+.5)/pixels.get_height();break
   profile.append(foot)
  material.set_shader_parameter("base_contact",profile)
  geometry=GEOMETRY.base_contact_mesh(profile);geometry.surface_set_material(0,material);mm.mesh=geometry
  if rigid:geometry=QuadMesh.new();geometry.surface_set_material(0,material);mm.mesh=geometry
  if skirt:
   geometry=GEOMETRY.contact_mesh()
   geometry.surface_set_material(0,material);mm.mesh=geometry
  var model_height:float=12 if asset.begins_with("tree") or asset.ends_with("shell") else 2
  if requested_height>0:model_height=requested_height
  var model_width:float=model_height*float(pixels.get_width())/pixels.get_height() if not asset.is_empty() else 3
  if requested_width>0:model_width=requested_width
  if skirt and "--dense-foot" in OS.get_cmdline_user_args():
   var resolution:=GEOMETRY.contact_resolution(Vector2(model_width,model_height))
   geometry=GEOMETRY.contact_mesh(resolution.x,resolution.y);geometry.surface_set_material(0,material);mm.mesh=geometry
   print("CONTACT_FOOT_RESOLUTION ",resolution," vertices=",geometry.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
  var anchor:Vector2=Vector2(.5,1.0 if not asset.is_empty() and asset!="litter" else .82)
  if anchors.has(asset):anchor=Vector2(anchors[asset].ground_anchor[0],anchors[asset].ground_anchor[1])
  if rigid:anchor=Vector2(.5,1)
  if skirt:
   var marks:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/biomes/crystal/spatial-marks.json"))
   var mark:Array=marks[asset.get_file()+".png"].ground_anchor
   anchor=Vector2(mark[0],mark[1])
   if asset.ends_with("shell"):material.set_shader_parameter("rock_contact",GEOMETRY.contact_profile(pixels))
   if "--bounded-foot" in OS.get_cmdline_user_args():
    geometry=GEOMETRY.bounded_contact_mesh(Vector2(model_width,model_height),anchor.y,GEOMETRY.contact_profile(pixels) if asset.ends_with("shell") else PackedFloat32Array())
    geometry.surface_set_material(0,material);mm.mesh=geometry
    print("CONTACT_BOUNDED vertices=",geometry.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
  camera.size=maxf(4,maxf(model_height,model_width*float(root.size.y)/root.size.x)*1.1)
  for angle in [-.5,0.0,.5]:
   for amplitude in [1.0,5.0]:
    var origin:=Vector3(terrain_origin.x,terrain(Vector2(terrain_origin.x,-terrain_origin.y)*20,amplitude),terrain_origin.y)
    floor_node.position=Vector3(floor(terrain_origin.x),0,floor(terrain_origin.y))
    camera.position=origin+Vector3(0,model_height*.4,8);camera.rotation=Vector3.ZERO
    if skirt:camera.rotation.x=-.08
    if requested_pitch!=0:
     camera.position=origin+Vector3(0,model_height*.4,0)+Vector3(0,0,8).rotated(Vector3.RIGHT,requested_pitch)
     camera.rotation.x=requested_pitch
    material.set_shader_parameter("terrain_amplitude",amplitude)
    floor_material.set_shader_parameter("terrain_amplitude",amplitude)
    floor_material.set_shader_parameter("diagnostic_origin",terrain_origin)
    floor_material.set_shader_parameter("diagnostic_angle",angle)
    floor_node.hide()
    mm.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3(model_width,model_height,1)),origin))
    mm.set_instance_custom_data(0,Color(anchor.x,anchor.y,(5 if asset.ends_with("shell") else 4) if skirt else 2 if rigid else 7,angle))
    var output:=await snapshot()
    if with_ground:
     floor_node.show();var covered:=await snapshot();var total:=0;var lost:=0
     for y in root.size.y:
      for x in root.size.x:
       if green(output.get_pixel(x,y)):
        total+=1
        if not green(covered.get_pixel(x,y)):lost+=1
     assert(total>1000,"Ground contact fixture too small")
     var fraction:float=float(lost)/total;max_lost_fraction=maxf(max_lost_fraction,fraction)
     # Whole-art loss is diluted by the canopy. Also report the lowest fifth
     # of the rendered silhouette; diagnostic only, not a relaxed pass gate.
     var top:=root.size.y;var bottom_pixel:=-1
     for y in root.size.y:
      for x in root.size.x:
       if green(output.get_pixel(x,y)):top=mini(top,y);bottom_pixel=maxi(bottom_pixel,y)
     var foot_total:=0;var foot_lost:=0
     for y in range(top+int((bottom_pixel-top)*.8),bottom_pixel+1):
      for x in root.size.x:
       if green(output.get_pixel(x,y)):
        foot_total+=1
        if not green(covered.get_pixel(x,y)):foot_lost+=1
     print("CONTACT_FOOT_BAND pixels=",foot_total," lost=",foot_lost," fraction=",float(foot_lost)/maxi(1,foot_total))
     covered.save_png("res://../tempassets/work/world3d-contact-on-ground"+("-"+asset.replace("/","-") if not asset.is_empty() else "")+".png")
     print("CONTACT_GROUND angle=",angle," amplitude=",amplitude," lost_fraction=",fraction)
     if fraction>=.01:
      push_error("Production ground grid cuts away the contact mesh: "+str(fraction));quit(1);return
    var case_worst:=0.0
    if "--occlusion-only" in OS.get_cmdline_user_args():
     assert(with_ground,"Occlusion-only requires the ground mesh")
     checks+=1
     continue
    output.save_png("res://../tempassets/work/world3d-contact-raster.png")
    if bottom==.9 and angle==0 and amplitude==1:output.save_png("res://../tempassets/work/world3d-contact-raster-basic.png")
    for column in range(2,15):
     var source_x:=roundi(column/16.0*(pixels.get_width()-1));var has_foot:=false
     for y in range(pixels.get_height()-1,int(pixels.get_height()*.7),-1):
      if pixels.get_pixel(source_x,y).a>.5:has_foot=true;break
     if not has_foot:continue
     var offset:float=(column/16.0-anchor.x)*model_width
     var world:=origin+Vector3(cos(angle)*offset,0,sin(angle)*offset)
     world.y=terrain(Vector2(world.x,-world.z)*20,amplitude)
     var screen:Vector2=camera.unproject_position(world);var x:=roundi(screen.x)
     assert(x>=0 and x<root.size.x,"Contact fixture must frame the complete asset width")
     var last:=-1
     for y in root.size.y:
      if green(output.get_pixel(x,y)):last=y
     assert(last>=0,"Contact fixture not visible")
     var error:float=absf(last+.5-screen.y)
     case_worst=maxf(case_worst,error)
     worst=maxf(worst,error);checks+=1
    print("CONTACT_RASTER bottom=",bottom," angle=",angle," amplitude=",amplitude," max_pixels=",case_worst)
 scene.free()
 print("WORLD3D_CONTACT_RASTER checks=",checks," max_foot_error_pixels=",worst)
 FileAccess.open("res://../tempassets/work/world3d-contact-result"+("-"+asset.replace("/","-") if not asset.is_empty() else "")+("-height-"+str(requested_height) if requested_height>0 else "")+"-width-"+str(requested_width)+("-occlusion" if "--occlusion-only" in OS.get_cmdline_user_args() else "")+"-origin-"+str(terrain_origin.x)+"-"+str(terrain_origin.y)+"-pitch-"+str(requested_pitch)+("-section" if "--contact-plane-ground" in OS.get_cmdline_user_args() else "")+("-dense-foot" if "--dense-foot" in OS.get_cmdline_user_args() else "")+("-bounded" if "--bounded-foot" in OS.get_cmdline_user_args() else "")+".json",FileAccess.WRITE).store_string(JSON.stringify({"asset":asset,"terrain_origin_xz":[terrain_origin.x,terrain_origin.y],"pitch":requested_pitch,"section_diagnostic":"--contact-plane-ground" in OS.get_cmdline_user_args(),"requested_height":requested_height,"requested_width":requested_width,"occlusion_only":"--occlusion-only" in OS.get_cmdline_user_args(),"samples":checks,"max_foot_error_pixels":null if "--occlusion-only" in OS.get_cmdline_user_args() else worst,"max_lost_fraction":max_lost_fraction,"ground_mesh":with_ground,"curved_synthetic":curved,"rigid_artwork":rigid,"ground_skirt":skirt,"bounded_foot":"--bounded-foot" in OS.get_cmdline_user_args(),"experimental_dense_foot":"--dense-foot" in OS.get_cmdline_user_args(),"contact_line_test_applicable":not (rigid or skirt or "--occlusion-only" in OS.get_cmdline_user_args()),"passed":(with_ground and max_lost_fraction<.01) if (rigid or skirt) else worst<1.5},"  "))
 assert(checks>0,"Asset must exercise visible foot samples")
 if with_ground:print("WORLD3D_CONTACT_GROUND lost_fraction=",max_lost_fraction)
 # A rigid pile has deliberately raised leaves, so not every column is a foot.
 # The independent production-ground occlusion check above still applies.
 if rigid or skirt:assert(with_ground,"Rigid artwork and skirts require actual ground occlusion validation")
 else:assert(worst<1.5,"Rendered opaque foot does not meet analytic terrain")
 call_deferred("quit")








