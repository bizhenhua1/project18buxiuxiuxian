extends SceneTree
# Offline route/opaque-art intersection audit. No runtime collision queries.
# Samples standing torso heights, not roots affected by contact deformation.
func _initialize():call_deferred("run")
func run():
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
 while not app.stage or not app.stage.ready_stage:await process_frame
 var stage=app.stage;stage.set_process(false)
 var route=stage.route_segment
 var audit_world=stage.world
 var fixture_seed:=-1
 var three_way:bool="--three-way" in OS.get_cmdline_user_args()
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--layout-seed="):fixture_seed=int(argument.get_slice("=",1))
 if three_way or fixture_seed>=0:
  # Generate an alternate source fixture; this is not a rendered stage override.
  var plan:RoutePlan=preload("res://scripts/world3d/themes.gd").plan(stage.theme_key)
  if three_way:
   plan.exits=3
   for original in plan.regions.duplicate():
    if original.branch==-1:
     var middle:RouteRegion=original.duplicate();middle.branch=2;middle.key=StringName(str(original.key)+"_middle");plan.regions.append(middle)
  if fixture_seed>=0:plan.layout_seed=fixture_seed
  audit_world=SegmentWorld.new(ForestArt.new(),plan)
  route=preload("res://scripts/world3d/route_segment.gd").new(0,Vector2.ZERO,0,700,420,2200,plan.exits,plan.layout_seed,stage.theme_key)
 var view_heading:=INF
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--shell-heading="):view_heading=float(argument.get_slice("=",1))
 var images:Dictionary={};var violations:Array=[];var crossings:=0;var shells:=0;var planes:Array=[]
 for sprite in stage.scenery.route_shells(audit_world.sprites,route):
  if not sprite.get("shell",false):continue
  shells+=1
  var tex:Texture2D=sprite.texture
  if not images.has(tex):images[tex]=tex.get_image()
  var image:Image=images[tex]
  var heading:float=float(sprite.get("plane_heading",route.pose(sprite.route_s,sprite.get("route_branch",0)).heading))
  if is_finite(view_heading) and not sprite.has("plane_heading"):heading=view_heading
  var forward:=Vector2(sin(heading),cos(heading));var right:=Vector2(cos(heading),-sin(heading))
  var origin:Vector2=sprite.position
  planes.append({"sprite":sprite,"right":right,"image":image})
  # Sample every connected branch; a shell may block a neighbouring exit.
  for branch in ([-1,2,1] if route.exits==3 else [-1,1]):
   var before_s:float=route.start_s
   var before:float=(route.pose(before_s,branch).position-origin).dot(forward)
   var scan_s:float=before_s+20
   while scan_s<=route.end_s+20:
    var after_s:float=minf(scan_s,route.end_s)
    var after:float=(route.pose(after_s,branch).position-origin).dot(forward)
    if before<0 and after>=0:
     var lo:=before_s;var hi:=after_s
     for iteration in 18:
      var mid:float=(lo+hi)*.5
      if (route.pose(mid,branch).position-origin).dot(forward)<0:lo=mid
      else:hi=mid
     var at:float=(lo+hi)*.5
     # Shared approach counted once, rather than once per eventual branch.
     if at>route.junction_s or branch==-1:
      crossings+=1
      var point:Vector2=route.pose(at,branch).position
      var anchor:Vector2=sprite.get("ground_anchor",Vector2(.5,1))
      var blocked:=0;var tested:=0
      for lateral in [-20.0,-10.0,0.0,10.0,20.0]:
       var u:float=anchor.x+((point-origin).dot(right)+lateral)/float(sprite.w)
       if sprite.flip:u=1-u
       for high in [20.0,40.0,60.0]:
        var v:float=anchor.y-high/float(sprite.h)
        tested+=1
        if u>=0 and u<1 and v>=0 and v<1:
         if image.get_pixel(mini(image.get_width()-1,int(u*image.get_width())),mini(image.get_height()-1,int(v*image.get_height()))).a>.5:blocked+=1
      if blocked>0:violations.append({"shell_s":sprite.route_s,"shell_branch":sprite.get("route_branch",0),"crossing_s":at,"path_branch":branch,"width":sprite.w,"height":sprite.h,"blocked":blocked,"samples":tested,"asset":tex.resource_path})
    if after_s>=route.end_s:break
    before_s=after_s;before=after;scan_s+=20
 violations.sort_custom(func(a,b):return a.crossing_s<b.crossing_s)
 var intersections:Array=[]
 for a_index in planes.size():
  var a:Dictionary=planes[a_index]
  for b_index in range(a_index+1,planes.size()):
   var b:Dictionary=planes[b_index]
   var determinant:float=a.right.cross(b.right)
   if absf(determinant)<.00001:continue
   var delta:Vector2=b.sprite.position-a.sprite.position
   var along_a:float=delta.cross(b.right)/determinant
   var along_b:float=delta.cross(a.right)/determinant
   var anchor_a:Vector2=a.sprite.get("ground_anchor",Vector2(.5,1))
   var anchor_b:Vector2=b.sprite.get("ground_anchor",Vector2(.5,1))
   var u_a:float=anchor_a.x+along_a/float(a.sprite.w)
   var u_b:float=anchor_b.x+along_b/float(b.sprite.w)
   if u_a<0 or u_a>=1 or u_b<0 or u_b>=1:continue
   if a.sprite.flip:u_a=1-u_a
   if b.sprite.flip:u_b=1-u_b
   var hits:=0
   for high in [20.0,40.0,60.0,100.0,150.0,200.0,250.0]:
    var v_a:float=anchor_a.y-high/float(a.sprite.h)
    var v_b:float=anchor_b.y-high/float(b.sprite.h)
    if v_a<0 or v_a>=1 or v_b<0 or v_b>=1:continue
    if a.image.get_pixel(mini(a.image.get_width()-1,int(u_a*a.image.get_width())),int(v_a*a.image.get_height())).a>.5 and b.image.get_pixel(mini(b.image.get_width()-1,int(u_b*b.image.get_width())),int(v_b*b.image.get_height())).a>.5:hits+=1
   if hits>0:intersections.append({"a_s":a.sprite.route_s,"b_s":b.sprite.route_s,"a_branch":a.sprite.get("route_branch",0),"b_branch":b.sprite.get("route_branch",0),"opaque_height_samples":hits})
 var result:Dictionary={"theme":stage.theme_key,"route":route.snapshot(),"shells":shells,"crossings":crossings,"blocked_crossings":violations.size(),"scope":"Fixed owning-route shell planes; alpha>0.5, 40 old-unit-wide cross-section at 20/40/60 old-unit heights. Ignores contact deformation and ground slope; candidate evidence, not full rendered collision proof.","violations":violations}
 result.heading_mode="fixed owning route" if not is_finite(view_heading) else "camera-facing at "+str(view_heading)
 result.opaque_plane_intersections=intersections
 var suffix:="-fixed" if not is_finite(view_heading) else "-heading-"+str(view_heading)
 if stage.scenery.shared_shell_heading:suffix+="-shared"
 if stage.scenery.shared_shell_chambers:suffix+="-chamber"
 if three_way:suffix+="-three-way"
 if fixture_seed>=0:suffix+="-seed-"+str(fixture_seed)
 result.alternate_source_fixture=three_way or fixture_seed>=0
 FileAccess.open("res://../tempassets/work/world3d-shell-passages-"+stage.theme_key+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("SHELL_PASSAGES theme=",stage.theme_key," shells=",shells," crossings=",crossings," blocked=",violations.size())
 print("SHELL_OPAQUE_PLANE_INTERSECTIONS ",intersections.size())
 for i in mini(6,intersections.size()):print(JSON.stringify(intersections[i]))
 for i in mini(6,violations.size()):print(JSON.stringify(violations[i]))
 quit()
