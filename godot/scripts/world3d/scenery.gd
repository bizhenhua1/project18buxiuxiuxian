extends Node3D
const P=preload("res://scripts/world3d/projection.gd")
const BOUNDS=preload("res://scripts/world3d/cutout_bounds.gd")
var materials:Array=[]
var by_texture:Dictionary={}
var mesh_cache:Dictionary={}
var contact_cache:Dictionary={}
var bounded_ground:bool="--bounded-ground-contact" in OS.get_cmdline_user_args()
var contact_lod_enabled:bool="--contact-mesh-lod" in OS.get_cmdline_user_args()
var contact_specs:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world3d_asset_contacts.json"))
var contact_offsets:Dictionary={}
var trunk_placement=preload("res://scripts/world3d/trunk_placement.gd").new() if "--resolve-trunk-contacts" in OS.get_cmdline_user_args() else null
var conform_bases:bool="--contact-bases" in OS.get_cmdline_user_args()
var fixed_shells:bool="--fixed-route-shells" in OS.get_cmdline_user_args()
var shared_shell_heading:bool="--shared-shell-heading" in OS.get_cmdline_user_args()
var shared_shell_chambers:bool="--shared-shell-chambers" in OS.get_cmdline_user_args()
func route_shells(sprites:Array,route)->Array:
 if route==null:return sprites
 if fixed_shells and shared_shell_chambers:sprites=preload("res://scripts/world3d/shared_chamber.gd").apply(sprites,route)
 var result:Array=[]
 for original in sprites:
  if not original.get("root_cover",[]).is_empty():
   original=original.duplicate()
   original.native_cover_heading=route.pose(float(original.route_s),int(original.get("route_branch",0))).heading
  if not original.has("plane_heading") and is_low_foliage(original.texture):
   var plant:Dictionary=original.duplicate()
   plant.plane_heading=route.pose(float(original.route_s),int(original.get("route_branch",0))).heading
   result.append(plant)
  elif fixed_shells and original.get("shell",false) and not original.has("plane_heading"):
   var sprite:Dictionary=original.duplicate()
   sprite.plane_heading=route.pose(float(sprite.route_s),int(sprite.get("route_branch",0))).heading
   if shared_shell_heading and int(sprite.get("route_branch",0))!=0:
    # In the shared chamber, full-width arches must not turn into each other.
    # Use an immutable cross-section until the branch has enough lateral space.
    var local:Vector2=(sprite.position-route.origin).rotated(route.heading)
    var half_width:float=absf(float(sprite.w))*.5
    # With a middle exit, the nearest neighbour is only half as far away.
    var neighbour_factor:float=2.0 if route.exits==3 else 1.0
    var separation:float=smoothstep((half_width+20.0)*neighbour_factor,(half_width*2.0+40.0)*neighbour_factor,absf(local.x))
    sprite.plane_heading=lerp_angle(route.heading,float(sprite.plane_heading),separation)
   result.append(sprite)
  else:result.append(original)
 return result
func is_low_foliage(texture:Texture2D)->bool:
 for key in ["fern","clover","litter","grass","short-grass"]:
  if texture==ForestEcology.textures.get(key):return true
 return false
var floor_types:Array=[]
var floor_node:MeshInstance3D
var chunks:Array=[]
var upload_jobs:Array=[]
var stream_spatial_blocks:bool=not "--whole-route-upload" in OS.get_cmdline_user_args()
var track_pending_bounds:bool="--visible-route-handoff" in OS.get_cmdline_user_args()
var retired_distance:=-INF
var upload_peak_usec:=0
var imported_count:=0
var visible_chunks:=0
var cull_updates:=0
var last_cull_pose:=Vector4(INF,INF,INF,INF)
var last_cull_size:=Vector2.ZERO
var visible_materials:Array=[]
var material_updates:=0
var texture_prepare_usec:=0
var update_all_materials:=false
var floor_material:ShaderMaterial
var mist_source:ForestBatch
var mist_batch:MultiMesh
func populate(world:SegmentWorld,route=null):
 last_cull_pose=Vector4(INF,INF,INF,INF)
 append_sprites(world.sprites,route)
 create_ground(world)
 mist_source=ForestBatch.new();mist_source.source=world.sprites;mist_source.hide();add_child(mist_source)
 var mist_material:=ShaderMaterial.new();mist_material.shader=preload("res://scripts/world3d/mist.gdshader");materials.append(mist_material)
 var quad:=QuadMesh.new();quad.size=Vector2.ONE;quad.material=mist_material
 mist_batch=MultiMesh.new();mist_batch.transform_format=MultiMesh.TRANSFORM_3D;mist_batch.use_colors=true;mist_batch.use_custom_data=true;mist_batch.mesh=quad;mist_batch.instance_count=256;mist_batch.visible_instance_count=0
 mist_batch.custom_aabb=AABB(Vector3(-200,-20,-400),Vector3(400,100,800))
 var fog_node:=MultiMeshInstance3D.new();fog_node.multimesh=mist_batch;fog_node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(fog_node)
func append_sprites(sprites:Array,route=null):
 sprites=route_shells(sprites,route)
 if trunk_placement!=null:sprites=trunk_placement.prepare(sprites,route)
 last_cull_pose=Vector4(INF,INF,INF,INF)
 var groups:Dictionary={}
 for sprite in sprites:add_sprite_to_groups(sprite,groups)
 for group in groups.values():build_group(group)
func add_sprite_to_groups(sprite:Dictionary,groups:Dictionary,placement_done:=false):
 if trunk_placement!=null and float(sprite.get("trunk_radius",0))>0 and float(sprite.get("route_s",INF))<retired_distance:return
 if trunk_placement!=null and not placement_done:sprite=trunk_placement.place(sprite)
 if sprite.get("actor",false) or sprite.get("mist",false) or sprite.get("firefly",false):return
 var grounded:bool=sprite.region.space.key==&"crystal" and (sprite.has("plane_heading") or sprite.get("biome_prop",false) or sprite.get("emissive",false))
 var squash:Vector2=sprite.get("squash",Vector2.ONE)
 var members:Array=[{"texture":sprite.texture,"w":sprite.w*squash.x,"h":sprite.h*squash.y,"anchor":sprite.get("ground_anchor",Vector2(.5,1)),"role":"body"}]
 # The legacy .82 litter anchor intentionally painted the foreground of the
 # pile below its screen-space origin. In depth-tested 3D that buries its leaves.
 # Keep the three-quarter artwork upright and intact, with its real bottom at ground.
 if sprite.texture==ForestEcology.textures.get("litter"):members[0].anchor=Vector2(.5,1)
 for cover in sprite.get("root_cover",[]):
  var h:float=sprite.h*cover.height;var w:float=h*cover.texture.get_width()/cover.texture.get_height()
  var anchor:Vector2=sprite.get("ground_anchor",Vector2(.5,1))
  members.append({"texture":cover.texture,"w":w,"h":h,"anchor":Vector2(.5-(cover.x-anchor.x)*sprite.w/w,1-(cover.foot_y-anchor.y)*sprite.h/h),"role":"root_cover"})
 for member in members:
  # Adjust only the native member anchor, never shared source art or legacy data.
  # Cache by texture so thousands of tree-root covers need no image inspection.
  if not contact_offsets.has(member.texture):
   var correction:=0.0
   for asset_key in contact_specs:
    if member.texture==ForestEcology.textures.get(asset_key) or member.texture.resource_path==asset_key:
     correction=float(contact_specs[asset_key].anchor_y_offset);break
   contact_offsets[member.texture]=correction
  member.anchor.y+=float(contact_offsets[member.texture])
  var adaptive_contact:bool=conform_bases or (member.role=="body" and (sprite.get("trunk_radius",0.0)>0 or (sprite.get("shell",false) and (sprite.region.space.key in [&"swamp",&"palace",&"sewer",&"whale"] or FairytaleCatalog.has_scene(sprite.region.space.key)))))
  var cell:=Vector2i(floor(sprite.position.x/240),floor(sprite.position.y/240))
  var key:=str(member.texture.get_instance_id())+":"+str(cell)+":"+str(grounded)+":"+str(adaptive_contact)
  # Bounded geometry bakes its fold boundary into the mesh. Instance custom
  # data cannot correct a mesh built for a different anchor or shell profile.
  if grounded and bounded_ground:key+=":"+str(member.anchor.y)+":"+str(sprite.get("shell",false))
  if not groups.has(key):groups[key]={"texture":member.texture,"grounded":grounded,"adaptive_contact":adaptive_contact,"items":[],"first_s":INF,"order":groups.size()}
  groups[key].first_s=minf(groups[key].first_s,float(sprite.get("route_s",0)))
  var contact_box:=BOUNDS.enclosing(P.point(sprite.position,ForestEcology.height_at(sprite.position)+float(sprite.get("altitude",0))),Vector2(member.w,member.h)/20,member.anchor)
  if member.role=="root_cover":contact_box=contact_box.grow(.35*absf(float(ForestSettings.values.height)))
  if adaptive_contact and not grounded:contact_box=contact_box.grow(maxf(0,1-member.anchor.y)*member.h/20*1.6+.4*absf(float(ForestSettings.values.height)))
  if grounded:contact_box=contact_box.grow((maxf(0,1-member.anchor.y)+.15)*member.h/20*1.6+.4*absf(float(ForestSettings.values.height)))
  groups[key].bounds=groups[key].bounds.merge(contact_box) if groups[key].has("bounds") else contact_box
  groups[key].items.append({"sprite":sprite,"member":member});imported_count+=1
func build_group(group:Dictionary):
 var texture:Texture2D=group.texture
 if not by_texture.has(texture):
  var mat:=ShaderMaterial.new()
  mat.shader=preload("res://scripts/world3d/foliage_depth.gd").shader() if is_low_foliage(texture) else preload("res://scripts/world3d/cutout.gdshader")
  var source_path:String=texture.resource_path
  if source_path.is_empty():
   for asset_key in ForestEcology.textures:
    if ForestEcology.textures[asset_key]==texture:source_path=StyleLibrary.ROOT+str(asset_key)+".png";break
  mat.set_meta("source_asset",source_path)
  if is_low_foliage(texture):mat.set_shader_parameter("foliage_depth_bias",.0001*(1+posmod(source_path.hash(),31)))
  var texture_started:=Time.get_ticks_usec()
  mat.set_shader_parameter("art",preload("res://scripts/world3d/texture_sampling.gd").mipmapped(texture))
  texture_prepare_usec+=Time.get_ticks_usec()-texture_started
  # Fractional foliage fades render after actor atmosphere (-100), before mist.
  # Otherwise transparent batch sorting can paint whole plant chunks over fog.
  mat.render_priority=-90
  by_texture[texture]=mat;materials.append(mat)
 # A texture may have been encountered first as an ordinary decorative member.
 # Prepare contact data on demand independently of material creation order.
 if group.adaptive_contact and not by_texture[texture].has_meta("base_contact_ready"):
  var contact_started:=Time.get_ticks_usec()
  var image:=texture.get_image();var profile:=PackedFloat32Array()
  for column in 17:
   var x:=roundi(float(column)/16*(image.get_width()-1));var bottom:=1.0
   for y in range(image.get_height()-1,int(image.get_height()*.7),-1):
    if image.get_pixel(x,y).a>.5:bottom=(y+.5)/image.get_height();break
   profile.append(bottom)
  by_texture[texture].set_shader_parameter("base_contact",profile)
  by_texture[texture].set_meta("base_contact_ready",true)
  texture_prepare_usec+=Time.get_ticks_usec()-contact_started
 var grounded:bool=group.grounded
 if group.items.any(func(item):return item.sprite.get("shell",false)) and not contact_cache.has(texture):
  contact_cache[texture]=preload("res://scripts/world3d/contact_geometry.gd").contact_profile(texture.get_image())
  by_texture[texture].set_shader_parameter("rock_contact",contact_cache[texture])
 var mesh_key:=str(texture.get_instance_id())+":"+str(grounded)+":"+str(group.adaptive_contact)
 var contact_size:=Vector2.ZERO
 var foot_profile:PackedFloat32Array=contact_cache[texture] if group.items[0].sprite.get("shell",false) else PackedFloat32Array()
 if grounded and bounded_ground:
  for item in group.items:contact_size=contact_size.max(Vector2(item.member.w,item.member.h)/20)
  var resolution:=preload("res://scripts/world3d/contact_geometry.gd").bounded_resolution(contact_size,float(group.items[0].member.anchor.y),foot_profile)
  mesh_key+=":bounded:"+str(resolution)+":"+str(group.items[0].member.anchor.y)+":"+str(group.items[0].sprite.get("shell",false))
  by_texture[texture].set_shader_parameter("precise_ground_contact",true)
 if not mesh_cache.has(mesh_key):
  var geometry:Mesh=contact_mesh() if grounded else base_contact_mesh(by_texture[texture].get_shader_parameter("base_contact")) if group.adaptive_contact else QuadMesh.new()
  if grounded and bounded_ground:
   var shape:=preload("res://scripts/world3d/contact_geometry.gd")
   geometry=shape.bounded_contact_mesh(contact_size,float(group.items[0].member.anchor.y),foot_profile)
  geometry.surface_set_material(0,by_texture[texture]);mesh_cache[mesh_key]=geometry
 var mesh:Mesh=mesh_cache[mesh_key]
 var far_mesh:Mesh
 if grounded and bounded_ground and contact_lod_enabled:
  var far_key:=mesh_key+":far"
  if not mesh_cache.has(far_key):
   var columns:int=preload("res://scripts/world3d/contact_geometry.gd").bounded_resolution(contact_size,float(group.items[0].member.anchor.y),foot_profile).x
   mesh_cache[far_key]=preload("res://scripts/world3d/contact_mesh_lod.gd").coarse(mesh,columns)
  far_mesh=mesh_cache[far_key]
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.use_custom_data=true;mm.mesh=mesh;mm.instance_count=group.items.size()
 var bounds:AABB=group.bounds
 for i in group.items.size():
  var item=group.items[i];var sprite=item.sprite;var member=item.member
  var pos:=P.point(sprite.position,ForestEcology.height_at(sprite.position)+float(sprite.get("altitude",0)))
  var anchor:Vector2=member.anchor
  var fixed_cover:bool=member.role=="root_cover" and is_low_foliage(member.texture)
  var cover_angle:float=float(sprite.get("native_cover_heading",sprite.get("plane_heading",0)))
  if fixed_cover:
   # Convert the legacy parent-relative rectangle into its own fixed world
   # root. A turning camera must not orbit the grass around the parent tree.
   var offset:float=(.5-anchor.x)*member.w/20*(-1 if sprite.flip else 1)
   pos+=Vector3(cos(cover_angle),0,sin(cover_angle))*offset
   pos.y=ForestEcology.height_at(Vector2(pos.x,-pos.z)*20)/20+float(sprite.get("altitude",0))/20+(anchor.y-1)*member.h/20
   anchor=Vector2(.5,1)
  mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(member.w/20,member.h/20,1)),pos))
  var mode:int=(5 if sprite.get("shell",false) else 4 if sprite.has("plane_heading") else 3) if grounded else 2 if sprite.has("plane_heading") else 1
  if group.adaptive_contact and not grounded:mode=7 if sprite.has("plane_heading") else 6
  if fixed_cover:mode=2
  if sprite.get("emissive",false):mode+=8
  if sprite.get("shell",false):mode+=16
  if member.role=="root_cover":mode+=32
  var extra:float=float(sprite.get("plane_heading",0))
  if fixed_cover:extra=cover_angle
  elif member.role=="root_cover" and not sprite.has("plane_heading"):
   # Formal renderer hides root attachments when parent rect's .86-height
   # point falls below the viewport. Free billboard covers do not use yaw.
   extra=(float(sprite.get("ground_anchor",Vector2(.5,1)).y)-.86)*float(sprite.h)*float(sprite.get("squash",Vector2.ONE).y)/20.0
  mm.set_instance_custom_data(i,Color(anchor.x,anchor.y,(-1 if sprite.flip else 1)*mode,extra))
  mm.set_instance_color(i,sprite.region.space.ambient*sprite.get("ecology_tint",Color.WHITE))
 mm.custom_aabb=bounds
 var node:=MultiMeshInstance3D.new();node.multimesh=mm;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node);chunks.append(node)
 if far_mesh!=null:node.set_meta("contact_fine",mesh);node.set_meta("contact_far",far_mesh);node.set_meta("contact_is_far",false)
 var end_s:float=-INF
 for item in group.items:end_s=maxf(end_s,float(item.sprite.get("route_s",0)))
 node.set_meta("end_s",end_s)
 node.set_meta("route_samples",group.items.map(func(item):return float(item.sprite.get("route_s",0))))
 # Diagnostics retain semantic identity without splitting otherwise identical batches.
 node.set_meta("contact_roles",group.items.map(func(item):return str(item.member.role)))
func queue_sprites(sprites:Array,route=null):
 sprites=route_shells(sprites,route)
 var job:Dictionary={"sprites":sprites.duplicate() if trunk_placement!=null else sprites,"route":route,"reserve_cursor":0,"cursor":0,"groups":{},"ready":[],"group_cursor":0,"grouped":false}
 if stream_spatial_blocks and trunk_placement==null:
  job.partition_cursor=0;job.cells={};job.cell_order=[];job.cell_cursor=0;job.partitioned=false
 upload_jobs.append(job)
func pending_sprite_rect(sprite:Dictionary)->Rect2:
 var anchor:Vector2=sprite.get("ground_anchor",Vector2(.5,1))
 var squash:Vector2=sprite.get("squash",Vector2.ONE)
 var correction:=0.0
 for spec in contact_specs.values():correction=minf(correction,float(spec.anchor_y_offset))
 var members:Array=[Vector3(sprite.w*squash.x,sprite.h*squash.y,maxf(absf(anchor.x),absf(1-anchor.x)))]
 var anchors:Array=[anchor.y]
 for cover in sprite.get("root_cover",[]):
  var h:float=sprite.h*cover.height
  var w:float=h*cover.texture.get_width()/cover.texture.get_height()
  if absf(w)<.00001 or absf(h)<.00001:continue
  var x:float=.5-(cover.x-anchor.x)*sprite.w/w
  members.append(Vector3(w,h,maxf(absf(x),absf(1-x))))
  anchors.append(1-(cover.foot_y-anchor.y)*sprite.h/h)
 var radius:=0.0
 for i in members.size():
  var member:Vector3=members[i]
  # Union of every possible contact mode, including the most negative asset
  # anchor correction. This can overestimate but never omit a root-cover edge.
  var growth:float=(maxf(0,1-float(anchors[i])-correction)+.15)*absf(member.y)*1.6+15*absf(float(ForestSettings.values.height))
  radius=maxf(radius,absf(member.x)*member.z+growth+.02)
 return Rect2(sprite.position-Vector2.ONE*radius,Vector2.ONE*radius*2)
func rect_near(rect:Rect2,origin:Vector2,radius:float)->bool:
 return origin.clamp(rect.position,rect.end).distance_squared_to(origin)<=radius*radius
func route_nearby_ready(route,origin:Vector2,radius:=1900.0)->bool:
 # Conservative all-angle coverage includes oversized/off-centre art. Bounds
 # are computed once while grouping and reused by final culling; no raycasts.
 for job in upload_jobs:
  if job.route!=route:continue
  if job.has("partitioned"):
   if not job.partitioned:return false
   for cell_index in range(job.cell_cursor+(1 if job.grouped else 0),job.cell_order.size()):
    var cell:Dictionary=job.cell_order[cell_index]
    if not cell.has("bounds") or rect_near(cell.bounds,origin,radius):return false
   if not job.grouped:continue
  elif not job.grouped:return false
  for i in range(job.group_cursor,job.ready.size()):
   var box:AABB=job.ready[i].bounds
   var low:=Vector2(box.position.x,-box.end.z)*20
   var high:=Vector2(box.end.x,-box.position.z)*20
   var nearest:=origin.clamp(low,high)
   if nearest.distance_squared_to(origin)<=radius*radius:return false
 return true
func process_uploads(budget_usec:int=1500):
 var began:=Time.get_ticks_usec()
 while not upload_jobs.is_empty():
  var job:Dictionary=upload_jobs[0]
  if job.has("partitioned") and not job.partitioned:
   if job.partition_cursor<job.sprites.size():
    var source:Dictionary=job.sprites[job.partition_cursor];job.partition_cursor+=1
    var cell:=Vector2i(floor(source.position.x/240),floor(source.position.y/240))
    if not job.cells.has(cell):job.cells[cell]={"items":[],"first_s":INF,"order":job.cells.size()}
    job.cells[cell].items.append(source)
    if track_pending_bounds:
     var rectangle:=pending_sprite_rect(source)
     job.cells[cell].bounds=job.cells[cell].bounds.merge(rectangle) if job.cells[cell].has("bounds") else rectangle
    job.cells[cell].first_s=minf(job.cells[cell].first_s,float(source.get("route_s",0)))
   else:
    job.cell_order=job.cells.values()
    job.cell_order.sort_custom(func(a,b):return a.order<b.order if a.first_s==b.first_s else a.first_s<b.first_s)
    job.partitioned=true
   if Time.get_ticks_usec()-began>=budget_usec:break
   continue
  if trunk_placement!=null and job.reserve_cursor<job.sprites.size():
   job.sprites[job.reserve_cursor]=trunk_placement.reserve(job.sprites[job.reserve_cursor],job.route);job.reserve_cursor+=1
   if Time.get_ticks_usec()-began>=budget_usec:break
   continue
  if not job.grouped:
   var sources:Array=job.cell_order[job.cell_cursor].items if job.has("partitioned") and job.cell_cursor<job.cell_order.size() else job.sprites
   if job.cursor<sources.size():
    var sprite:Dictionary=sources[job.cursor]
    if trunk_placement!=null and float(sprite.get("trunk_radius",0))>0 and float(sprite.get("route_s",INF))>=retired_distance:
     if not job.has("placement"):job.placement=trunk_placement.begin_place(sprite)
     else:trunk_placement.step_place(job.placement)
     if not job.placement.done:
      if Time.get_ticks_usec()-began>=budget_usec:break
      continue
     sprite=job.placement.result;job.erase("placement")
    elif job.has("placement"):job.erase("placement")
    add_sprite_to_groups(sprite,job.groups,true);job.cursor+=1
   else:
    job.ready=job.groups.values()
    # Upload complete existing batches from the route entrance outward. Do not
    # reorder instances inside transparent batches or split them into more draws.
    job.ready.sort_custom(func(a,b):return a.order<b.order if a.first_s==b.first_s else a.first_s<b.first_s)
    job.grouped=true
    if not job.has("partitioned"):job.sprites=[]
  elif job.group_cursor<job.ready.size():
   var group:Dictionary=job.ready[job.group_cursor];job.group_cursor+=1
   var end_s:float=-INF
   for item in group.items:end_s=maxf(end_s,float(item.sprite.get("route_s",0)))
   if end_s>=retired_distance:
    build_group(group);last_cull_pose=Vector4(INF,INF,INF,INF)
  else:
   if job.has("partitioned") and job.cell_cursor+1<job.cell_order.size():
    job.cell_cursor+=1;job.cursor=0;job.groups={};job.ready=[];job.group_cursor=0;job.grouped=false
   else:
    upload_jobs.pop_front();release_unused_art()
  if Time.get_ticks_usec()-began>=budget_usec:break
 upload_peak_usec=maxi(upload_peak_usec,Time.get_ticks_usec()-began)
func retire_before(distance:float):
 if trunk_placement!=null:trunk_placement.retire_before(distance)
 retired_distance=maxf(retired_distance,distance)
 var removed:=false
 for i in range(chunks.size()-1,-1,-1):
  if float(chunks[i].get_meta("end_s",INF))<distance:
   chunks[i].hide();chunks[i].queue_free();chunks.remove_at(i)
   removed=true
 if removed:release_unused_art()
 last_cull_pose=Vector4(INF,INF,INF,INF)
func release_unused_art():
 # Keep shared art while any live chunk or pending upload still needs it.
 var used:Dictionary={}
 for chunk in chunks:used[chunk.multimesh.mesh.surface_get_material(0)]=true
 var pending:Dictionary={}
 for job in upload_jobs:
  for sprite in job.sprites:
   pending[sprite.texture]=true
   for cover in sprite.get("root_cover",[]):pending[cover.texture]=true
  for group in job.groups.values():pending[group.texture]=true
 for texture in by_texture.keys():
  var material:ShaderMaterial=by_texture[texture]
  if used.has(material) or pending.has(texture):continue
  for key in mesh_cache.keys():
   if mesh_cache[key].surface_get_material(0)==material:mesh_cache.erase(key)
  materials.erase(material);visible_materials.erase(material)
  contact_cache.erase(texture);contact_offsets.erase(texture);by_texture.erase(texture)
func update_region_bounds(world:SegmentWorld):
 var regions:=PackedVector4Array();var types:Array=floor_types.duplicate()
 for region in world.plan.regions:
  if region.space not in types:types.append(region.space)
  regions.append(Vector4(region.start,region.end,region.branch,types.find(region.space)))
 floor_material.set_shader_parameter("region_count",regions.size())
 regions.resize(12);floor_material.set_shader_parameter("regions",regions)
func bind_route_segments(segments:Array):
 assert(segments.size()<=3,"Only adjacent route segments belong in the visible ground budget")
 var frames:=PackedVector4Array();var shapes:=PackedVector4Array()
 for segment in segments:
  frames.append(Vector4(segment.origin.x,segment.origin.y,segment.heading,segment.start_s))
  shapes.append(Vector4(segment.junction_s,segment.turn_length,segment.end_s,segment.exits))
 floor_material.set_shader_parameter("segment_count",segments.size())
 frames.resize(3);shapes.resize(3)
 floor_material.set_shader_parameter("segment_frames",frames);floor_material.set_shader_parameter("segment_shapes",shapes)
func create_ground(world:SegmentWorld):
 floor_material=ShaderMaterial.new();floor_material.shader=preload("res://scripts/world3d/ground.gdshader")
 floor_material.set_shader_parameter("ecology",true);floor_material.set_shader_parameter("terrain_amplitude",ForestSettings.values.height)
 floor_material.set_shader_parameter("straight_route",world.plan.straight);floor_material.set_shader_parameter("three_way",world.plan.exits==3)
 floor_material.set_shader_parameter("junction",ForestRoute.JUNCTION);floor_material.set_shader_parameter("turn_length",ForestRoute.TURN_LENGTH)
 var types:Array=[];var regions:=PackedVector4Array();var blends:=PackedFloat32Array()
 for region in world.plan.regions:
  if region.space not in types:types.append(region.space)
  regions.append(Vector4(region.start,region.end,region.branch,types.find(region.space)));blends.append(region.blend_length)
 floor_types=types.duplicate()
 floor_material.set_shader_parameter("region_count",regions.size());regions.resize(12);blends.resize(12)
 floor_material.set_shader_parameter("regions",regions);floor_material.set_shader_parameter("blend_lengths",blends)
 var tints:=PackedColorArray();var colors:=PackedColorArray();var textured:Array[bool]=[];var mirrored:Array[bool]=[]
 for i in 3:
  var type=types[mini(i,types.size()-1)];tints.append(type.ground_tint);colors.append(type.atmosphere.depth_color);textured.append(type.ground_texture!=null)
  mirrored.append(FairytaleCatalog.has_scene(type.key))
  floor_material.set_shader_parameter("floor%d"%i,type.ground_texture if type.ground_texture else StyleLibrary.texture("ground"))
 floor_material.set_shader_parameter("floor_tints",tints);floor_material.set_shader_parameter("depth_colors",colors);floor_material.set_shader_parameter("textured",textured)
 floor_material.set_shader_parameter("seam_blend_floor",mirrored)
 var plane:=preload("res://scripts/world3d/ground_grid.gd").mesh()
 var node:=MeshInstance3D.new();floor_node=node;node.mesh=plane;node.position.z=-100;node.material_override=floor_material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
static func order_mist(patches:Array,view_heading:float):
 var axis:=Vector2(sin(view_heading),cos(view_heading))
 patches.sort_custom(func(a,b):return a.position.dot(axis)>b.position.dot(axis))
func update_view(renderer:SegmentRenderer):
 floor_node.position=preload("res://scripts/world3d/ground_grid.gd").patch_origin(renderer.camera_world)
 var mist:Array=mist_source.world_mist(renderer)
 order_mist(mist,renderer.heading)
 mist_batch.visible_instance_count=mini(mist.size(),mist_batch.instance_count)
 for i in mist_batch.visible_instance_count:
  var patch=mist[i];var pos:=P.point(patch.position,ForestEcology.height_at(patch.position)+patch.altitude)
  mist_batch.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(patch.w/20,patch.h/20,1)),pos))
  var anchor:Vector2=patch.get("ground_anchor",Vector2(.5,1))
  mist_batch.set_instance_custom_data(i,Color(anchor.x,anchor.y,1,2 if patch.get("firefly",false) else 4 if patch.get("drip",false) else 1));mist_batch.set_instance_color(i,patch.ecology_tint)
 var size:Vector2=renderer.view_size
 var lens:float=renderer.runtime_camera.get("lens",1.0)
 var pose:=Vector4(renderer.camera_world.x,renderer.camera_world.y,renderer.heading,lens)
 if pose!=last_cull_pose or size!=last_cull_size:
  cull_updates+=1
  last_cull_pose=pose;last_cull_size=size;visible_chunks=0
  var used:Dictionary={}
  var half_width_over_focal:=size.x*.5/(minf(size.y*.86,size.x*.72)*lens)
  for chunk in chunks:
   chunk.visible=BOUNDS.visible(chunk.multimesh.custom_aabb,renderer.camera_world,renderer.heading,half_width_over_focal)
   if chunk.visible and chunk.has_meta("contact_fine"):
    var far:bool=contact_lod_enabled and preload("res://scripts/world3d/contact_mesh_lod.gd").distant(chunk.multimesh.custom_aabb,renderer.camera_world,renderer.heading,chunk.get_meta("contact_is_far",false))
    if far!=bool(chunk.get_meta("contact_is_far",false)):
     chunk.multimesh.mesh=chunk.get_meta("contact_far" if far else "contact_fine");chunk.set_meta("contact_is_far",far)
   if chunk.visible:
    visible_chunks+=1
    used[chunk.multimesh.mesh.surface_get_material(0)]=true
  used[mist_batch.mesh.surface_get_material(0)]=true
  used[floor_material]=true
  visible_materials=used.keys()
 var targets:Array=materials+[floor_material] if update_all_materials else visible_materials
 material_updates=targets.size()
 var parameters:Dictionary=renderer.combat_light_parameters()
 parameters.merge(renderer.biome_parameters())
 var lantern:Vector3=renderer.lantern_position()
 for mat in targets:
  mat.set_shader_parameter("terrain_amplitude",ForestSettings.values.height)
  mat.set_shader_parameter("heading",renderer.heading);mat.set_shader_parameter("fog_color",renderer.world.camera_region.space.atmosphere.depth_color)
  mat.set_shader_parameter("fog_range",Vector2(renderer.world.camera_region.space.depth_start,renderer.world.camera_region.space.depth_end))
  mat.set_shader_parameter("lantern_enabled",renderer.lantern_enabled);mat.set_shader_parameter("lantern_position",lantern);mat.set_shader_parameter("lantern_forward",Vector2(sin(renderer.heading),cos(renderer.heading)))
  mat.set_shader_parameter("atmosphere_time",renderer.elapsed)
  for key in parameters:mat.set_shader_parameter(key,parameters[key])

func trim_after(s:float):
 if trunk_placement!=null:trunk_placement.trim_after(s)
 # Remove only future instances; keep crossing groups and all near geometry intact.
 for node in chunks:
  var samples:Array=node.get_meta("route_samples",[])
  var remaining_end:float=-INF
  for i in samples.size():
   if samples[i]>=s:
    var transform:Transform3D=node.multimesh.get_instance_transform(i)
    transform.basis=Basis.from_scale(Vector3.ZERO);node.multimesh.set_instance_transform(i,transform)
   else:remaining_end=maxf(remaining_end,samples[i])
  node.set_meta("end_s",remaining_end)
 retire_before(retired_distance)

func contact_mesh()->ArrayMesh:
 return preload("res://scripts/world3d/contact_geometry.gd").contact_mesh()
func base_contact_mesh(profile:PackedFloat32Array=PackedFloat32Array())->ArrayMesh:
 return preload("res://scripts/world3d/contact_geometry.gd").base_contact_mesh(profile)




