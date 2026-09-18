extends RefCounted
## Static, seeded dressing. Artwork keeps its aspect ratio and measured feet.
const Catalog=preload("res://scripts/spaces/fairytale_catalog.gd")

func populate(world, region:RouteRegion)->void:
	var key:String=str(region.space.key)
	var original_anchors:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Catalog.asset(key,"anchors.json")))
	var spec:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(Catalog.asset(key,"corridor.json")))
	var rng:=RandomNumberGenerator.new()
	rng.seed=world.seed_value+hash(key)+region.branch*91
	var tex:Texture2D=load(Catalog.asset(key,spec.file))
	var h:float=spec.suggested_canvas_height
	var w:float=h*tex.get_width()/float(tex.get_height())
	var anchor:=Vector2(spec.ground_anchor[0],spec.ground_anchor[1])
	var branch_side:Dictionary={}
	var side_path:=Catalog.asset(key,"branch-side.json")
	if FileAccess.file_exists(side_path):
		branch_side=JSON.parse_string(FileAccess.get_file_as_string(side_path))
		branch_side["loaded"]=load(Catalog.asset(key,branch_side.file))
	var s:float=region.start+30.0
	while s<region.end:
		if spec.role=="shell":
			# A whole open silhouette is safe only if both supports clear every lane.
			var opening:float=w*float(spec.lower_passage_min_width_fraction)
			var offset:float=(w+opening)*.25
			var support_radius:float=(w-opening)*.25
			var safe:=true
			# Some interiors need separate piers through the junction: full
			# overhead room frames otherwise overlap across diverging roads.
			if not world.plan.straight and not branch_side.is_empty() and absf(s-ForestRoute.JUNCTION)<float(branch_side.get("junction_side_radius",0)):safe=false
			for side in [-1,1]:
				var p:=ForestRoute.point_at(s,region.branch,side*offset)
				if road_distance(world,p)<support_radius+76.0:safe=false
			if safe:
				append(world,region,s,0,tex,h,anchor,false,true)
			elif not branch_side.is_empty():
				place_branch_sides(world,region,s,branch_side)
		else:
			for side in [-1,1]:
				var lateral:float=side*(96.0+w*.5)
				if road_distance(world,ForestRoute.point_at(s,region.branch,lateral))>76.0+w*.5:
					append(world,region,s,lateral,tex,h,Vector2(.5,anchor.y),side>0,false)
		s+=rng.randf_range(spec.repeat_distance_range[0],spec.repeat_distance_range[1])
	# Original signature furniture remains sparse and outside the travel belt.
	var furniture:Texture2D=load(Catalog.asset(key,"structure.png"))
	var furniture_h:float={"alice_tea":100.0,"red_cottage":160.0,"red_workshop":135.0,"snow_house":145.0,"puppet_workshop":145.0,"piper_bridge":70.0}.get(key,180.0)
	s=region.start+150.0
	while s<region.end:
		var side:float=-1 if rng.randf()<.5 else 1
		var fw:float=furniture_h*furniture.get_width()/float(furniture.get_height())
		var x:float=side*(115.0+fw*.5)
		if road_distance(world,ForestRoute.point_at(s,region.branch,x))>fw*.5+76:
			var feet:Array=original_anchors.get("structure.png",{}).get("anchor",[.5,.99])
			append(world,region,s,x,furniture,furniture_h,Vector2(feet[0],feet[1]),side>0,false)
		s+=rng.randf_range(420,650)
	var entries:Array=[]
	var dressing_path:=Catalog.asset(key,"dressing.json")
	if FileAccess.file_exists(dressing_path):
		entries=JSON.parse_string(FileAccess.get_file_as_string(dressing_path)).assets
	else:
		for i in 4:
			var file:String="prop-%d.png"%i
			entries.append({"texture":file,"role":"prop","height_min":12.0,"height_max":24.0,"ground_anchor":original_anchors.get(file,{}).get("anchor",[.5,.99]),"alpha_height_fraction":1.0})
	var cached:Array=[]
	for entry in entries:
		var e:Dictionary=entry.duplicate()
		e["loaded"]=load(Catalog.asset(key,e.texture))
		cached.append(e)
	s=region.start
	while s<region.end:
		s+=rng.randf_range(24,42)
		var side:float=-1 if rng.randf()<.5 else 1
		var cluster_x:float=side*rng.randf_range(110,225)
		for j in rng.randi_range(3,6):
			var e:Dictionary=cached[rng.randi_range(0,cached.size()-1)]
			# Large accents are occasional; cover and litter provide continuity.
			if e.role=="anchor" and rng.randf()>.16:continue
			if cached.size()>4 and e.role=="prop" and rng.randf()>.55:continue
			var eh:float=rng.randf_range(e.height_min,e.height_max)/float(e.get("alpha_height_fraction",1.0))
			var at:float=s+rng.randf_range(-18,18)
			var x:float=cluster_x+rng.randf_range(-26,26)
			if e.role=="litter":x=rng.randf_range(-160,160)
			var ew:float=eh*e.loaded.get_width()/float(e.loaded.get_height())
			if e.role!="litter" and road_distance(world,ForestRoute.point_at(at,region.branch,x))<76+ew*.5:continue
			append(world,region,at,x,e.loaded,eh,Vector2(e.ground_anchor[0],e.ground_anchor[1]),rng.randf()<.5,false)
	place_furnishings(world,region,key)

func place_furnishings(world,region:RouteRegion,key:String)->void:
	var path:=Catalog.asset(key,"furnishings.json")
	if not FileAccess.file_exists(path):return
	var config:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var rng:=RandomNumberGenerator.new();rng.seed=world.seed_value+hash(key)+region.branch*91+7823
	var at:float=region.start+100
	var index:=0
	while at<region.end:
		var entry:Dictionary=config.assets[index%config.assets.size()]
		var texture:Texture2D=load(Catalog.asset(key,entry.file))
		var height:float=entry.height;var width:float=height*texture.get_width()/float(texture.get_height())
		var side:float=-1 if index%2==0 else 1
		for extra in [0.0,40.0,80.0]:
			var x:float=side*(84+width*.5+extra)
			if road_distance(world,ForestRoute.point_at(at,region.branch,x))<76+width*.5:continue
			append(world,region,at,x,texture,height,Vector2(entry.ground_anchor[0],entry.ground_anchor[1]),side>0,false)
			break
		at+=rng.randf_range(config.repeat_distance[0],config.repeat_distance[1]);index+=1

func place_branch_sides(world,region:RouteRegion,s:float,spec:Dictionary)->void:
	# Only replace unsafe spanning arches. The complete independent prop stays
	# outside every active road; no clipped arch or per-frame repositioning.
	var texture:Texture2D=spec.loaded
	var height:float=spec.suggested_canvas_height
	var width:float=height*texture.get_width()/float(texture.get_height())
	for side in [-1,1]:
		for extra in [0.0,40.0,80.0,120.0,160.0]:
			var lateral:float=side*(100.0+width*.5+extra)
			if road_distance(world,ForestRoute.point_at(s,region.branch,lateral))<76+width*.5:continue
			append(world,region,s,lateral,texture,height,Vector2(spec.ground_anchor[0],spec.ground_anchor[1]),side>0,false)
			break

func road_distance(world,p:Vector2)->float:
	return absf(ForestRoute.local_point(p).x) if world.plan.straight else ForestRoute.road_distance(p,world.plan.exits==3)

func append(world,region:RouteRegion,s:float,x:float,tex:Texture2D,h:float,anchor:Vector2,flip:bool,shell:bool)->void:
	if not region.contains(s,region.branch):return
	world.sprites.append({"position":ForestRoute.point_at(s,region.branch,x),"texture":tex,"w":h*tex.get_width()/float(tex.get_height()),"h":h,"flip":flip,"kind":0,"id":world.sprites.size(),"region":region,"route_s":s,"route_branch":region.branch,"altitude":0.0,"terrain_unit":0.0,"motion":"static","ground_anchor":anchor,"biome_prop":not shell,"shell":shell,"plane_heading":ForestRoute.pose(s,region.branch).heading})
