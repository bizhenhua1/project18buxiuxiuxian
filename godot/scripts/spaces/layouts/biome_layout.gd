extends RefCounted
const Catalog=preload("res://scripts/spaces/biome_catalog.gd")
static var rock_marks:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/biomes/crystal/spatial-marks.json"))
## Habitat clusters are seeded once; render-time animation never re-scatters assets.
func populate(world,region:RouteRegion) -> void:
 var key:=str(region.space.key);var c:Dictionary=Catalog.CONFIG[key]
 var rng:=RandomNumberGenerator.new();rng.seed=world.seed_value+hash(key)+region.branch*91
 var textures:Array[Texture2D]=[]
 for i in range(9):textures.append(load("res://assets/biomes/%s/prop-%d.png"%[key,i]))
 var shell:Texture2D=load("res://assets/biomes/%s/shell.png"%key)
 var s:float=region.start
 var last_shell_s:float=-INF
 var mouth:float=ForestRoute.JUNCTION+380.0
 if not world.plan.straight and region.branch!=0:s=ForestRoute.JUNCTION+120.0 if key=="crystal" else mouth
 if key=="crystal" and not world.plan.straight:
  populate_crystal_fork_shells(world,region,shell,c,rng)
  s=region.end # The specialized arch sequence replaces the old overlapping bridge.
 # Original six-theme shells remain the only structural asset source here.
 # A fork is joined below with intact crystal arches, never a stretched roof.
 while s<region.end:
  var wobble:=sin(s*.013)*12 if key not in ["sewer","palace"] else 0.0
  var width:float=c.width*rng.randf_range(.97,1.06)
  var height:float=c.height*rng.randf_range(.96,1.07)
  if not world.plan.straight:
   if region.branch==0 and key!="crystal":
    # A shared chamber opens before the split; never stack full-width branch walls.
    width*=lerpf(1.0,1.8,smoothstep(ForestRoute.JUNCTION-200.0,ForestRoute.JUNCTION,s))
   elif region.branch!=0:
    if key!="crystal":
     var separation:float=absf(ForestRoute.point_at(s,1).x)
     width=minf(width,separation*(1.35 if world.plan.exits==3 else 2.5))
     height*=lerpf(.66,1.0,smoothstep(mouth,mouth+600.0,s))
    # Crystal retains the original full arch cross-section; scaling it down
    # exposed sky and the neighbouring route during the curved handoff.
  var flip_shell:bool=rng.randf()<.5
  if include_shell(region,s):
   put(world,region,s,wobble,shell,width,height,flip_shell,0)
   world.sprites.back()["shell"]=true
   if key=="crystal" and not world.plan.straight and region.branch!=0 and s<mouth:
    world.sprites.back()["junction_entry"]=true
   last_shell_s=s
  if key=="sewer" and rng.randf()<.65:
   var side:float=-1 if rng.randf()<.5 else 1
   if include_shell(region,s):
    put(world,region,s-1,side*width*.245,shell,7,height*.18,false,0)
    world.sprites.back()["outflow"]=true
  s+=c.spacing*rng.randf_range(.83,1.18)
 if not world.plan.straight and region.branch==0:
  if key!="crystal" and key!="swamp":
   # Whole silhouettes keep natural arch edges; cropped roof bands leave hard seams.
   for roof_s in [ForestRoute.JUNCTION+40.0,ForestRoute.JUNCTION+170.0,ForestRoute.JUNCTION+300.0]:
    put(world,region,roof_s,0,shell,1250,c.height,false,0)
    world.sprites.back()["shell"]=true
  # Crystal's common-to-branch handoff is already framed by full arches.
  # A central divider here sits inside the turning route and blocks the view.
  if key!="crystal":
   var landmark_index:int={"swamp":0,"sewer":3,"whale":2,"palace":3}[key]
   for side in ([-1,1] if world.plan.exits==3 else [0]):
    var at:float=mouth+120.0
    var lateral:float=side*absf(ForestRoute.point_at(at,1).x)*.5
    var tex:Texture2D=textures[landmark_index]
    var high:float=100.0 if key=="swamp" else 120.0
    put(world,region,at,lateral,tex,high*tex.get_width()/float(tex.get_height()),high,side<0,0)
 # Large anchors live outside the sightline; micro-debris may enter it.
 s=region.start
 while s<region.end:
  s+=rng.randf_range(18,48)/(float(c.density)*Catalog.density_scale)
  if key=="crystal" and not world.plan.straight and s>ForestRoute.JUNCTION-25.0 and s<ForestRoute.JUNCTION+ForestRoute.TURN_LENGTH+90.0:continue
  var side:float=-1 if rng.randf()<.5 else 1
  var lateral:float=side*rng.randf_range(90,235)
  if key=="crystal":lateral=side*rng.randf_range(92,160)
  var species:int=rng.randi_range(0,8)
  var landmark:bool=rng.randf()<.18
  if key=="crystal" and rng.randf()<.62:species=2 if rng.randf()<.55 else 3
  if key=="sewer":lateral=side*rng.randf_range(98,140)
  if landmark:
   var high:float=rng.randf_range(80,165) if key=="swamp" else rng.randf_range(45,100)
   var big:int=0 if key=="swamp" else 2 if key=="crystal" else 3
   add_prop(world,region,s,lateral,textures[big],high,rng,big,c)
  for j in range(rng.randi_range(3,8)):
   var at:float=s+rng.randf_range(-20,20)
   var x:float=lateral+rng.randf_range(-32,32)
   var member:int=species if rng.randf()<.58 else rng.randi_range(0,8)
   var high:float=rng.randf_range(7,25)
   if key=="swamp":high*=rng.randf_range(.8,2.4)
   if member in c.glow and rng.randf()>.22:member=7
   add_prop(world,region,at,x,textures[member],high,rng,member,c)
  # Low litter is independent of the wall clusters; do not block the travel belt.
  if rng.randf()<.8:
   var litter:int=6 if key=="crystal" else 7
   add_prop(world,region,s+rng.randf_range(-8,8),rng.randf_range(-75,75),textures[litter],rng.randf_range(2,6),rng,litter,c)
 # Recognizable encounter-independent set pieces, with large quiet intervals.
 s=region.start+560
 while s<region.end:
  if key=="crystal" and not world.plan.straight and s>ForestRoute.JUNCTION-25.0 and s<ForestRoute.JUNCTION+ForestRoute.TURN_LENGTH+90.0:
   s=ForestRoute.JUNCTION+ForestRoute.TURN_LENGTH+90.0
  var side:float=-1 if rng.randf()<.5 else 1
  var feature:int=0 if key=="crystal" else 4 if key in ["swamp","sewer"] else 2
  add_prop(world,region,s,side*112,textures[feature],rng.randf_range(30,44),rng,feature,c)
  for j in range(rng.randi_range(3,6)):
   var detail:int=[4,5,7][rng.randi_range(0,2)] if key=="crystal" else rng.randi_range(0,8)
   add_prop(world,region,s+rng.randf_range(-24,24),side*rng.randf_range(92,140),textures[detail],rng.randf_range(8,19),rng,detail,c)
  s+=rng.randf_range(430,780)

func populate_crystal_fork_shells(world,region:RouteRegion,shell:Texture2D,c:Dictionary,rng:RandomNumberGenerator)->void:
 var junction:float=ForestRoute.JUNCTION
 var transfer:float=ForestRoute.TURN_LENGTH
 if region.branch==0:
  var at:float=region.start
  while at<minf(region.end,junction):
   add_crystal_arch(world,region,at,shell,c,1.0,rng)
   at+=c.spacing*rng.randf_range(.88,1.1)
  if is_equal_approx(region.end,junction):
   add_crystal_arch(world,region,junction+95.0,shell,c,1.0,rng)
  return
 # The two small mouths are the only stand-ins for dedicated entrance art.
 # Every later cross-section is centred on the same sideways-transfer curve
 # followed by the character, then resumes the full-size parallel corridor.
 # The two series are phase-shifted in depth so their roofs never form a
 # perfectly repeated M-shaped pair in the choice camera.
 var stagger:float=34.0 if region.branch>0 else 0.0
 var mouth_texture:Texture2D=load("res://assets/biomes/crystal/opening-left-v1.png" if region.branch<0 else "res://assets/biomes/crystal/opening-right-v1.png")
 var mouth_s:float=junction+transfer*.50+stagger
 if mouth_s>=region.start and mouth_s<region.end:
  put(world,region,mouth_s,0,mouth_texture,240.0 if region.branch<0 else 270.0,240.0 if region.branch<0 else 180.0,false,0)
  world.sprites.back()["shell"]=true
  world.sprites.back()["cave_mouth"]=true
  world.sprites.back()["cross_section"]=true
  world.sprites.back()["ground_anchor"]=Vector2(.5,.876 if region.branch<0 else .959)
 for opening in [[.72,.72],[.86,.96]]:
  var at:float=junction+transfer*float(opening[0])+stagger
  if at>=region.start and at<region.end:add_crystal_arch(world,region,at,shell,c,float(opening[1]),rng)
 var at:float=maxf(region.start,junction+transfer+stagger)
 while at<region.end:
  add_crystal_arch(world,region,at,shell,c,1.0,rng)
  at+=c.spacing*rng.randf_range(.88,1.1)

func add_crystal_arch(world,region:RouteRegion,s:float,shell:Texture2D,c:Dictionary,scale:float,rng:RandomNumberGenerator)->void:
 var variation:float=rng.randf_range(.985,1.015)
 put(world,region,s,0,shell,c.width*scale*variation,c.height*scale*variation,rng.randf()<.5,0)
 world.sprites.back()["shell"]=true
 world.sprites.back()["ground_anchor"]=Vector2(.5,.92)
 world.sprites.back()["cross_section"]=true
func include_shell(_region:RouteRegion,_s:float)->bool:
 return true
func add_prop(world,region:RouteRegion,s:float,x:float,tex:Texture2D,h:float,rng:RandomNumberGenerator,species:int,c:Dictionary) -> void:
 # Protect every branch, including where paths split.
 var p:=ForestRoute.point_at(s,region.branch,x)
 if h>8 and (absf(p.x) if world.plan.straight else ForestRoute.road_distance(p,world.plan.exits==3))<70+h*.2:return
 put(world,region,s,x,tex,h*tex.get_width()/float(tex.get_height()),h,rng.randf()<.5,0)
 world.sprites.back()["biome_prop"]=true
 if str(region.space.key)=="crystal":
  var anchor:Array=rock_marks["prop-%d.png"%species].ground_anchor
  world.sprites.back().ground_anchor=Vector2(anchor[0],anchor[1])
  world.sprites.back()["plane_heading"]=ForestRoute.pose(s,region.branch).heading
 if species in c.glow:
  world.sprites.back()["emissive"]=true
  world.biome_lights.append(Vector4(p.x,h*.65,p.y,80.0 if species!=4 else 65.0))
func put(world,region:RouteRegion,s:float,x:float,tex:Texture2D,w:float,h:float,flip:bool,altitude:float) -> void:
 world.sprites.append({"position":ForestRoute.point_at(s,region.branch,x),"texture":tex,"w":w,"h":h,"flip":flip,"kind":0,"id":world.sprites.size(),"region":region,"route_s":s,"route_branch":region.branch,"altitude":altitude,"motion":"static","ground_anchor":Vector2(.5,1)})
