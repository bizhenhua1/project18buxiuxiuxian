extends RefCounted
const Catalog=preload("res://scripts/spaces/fairytale_catalog.gd")

## Scene-by-scene handcrafted layout to avoid repetitive, sparse, floating placements.
func populate(world,region:RouteRegion)->void:
	var key:=str(region.space.key)
	if FileAccess.file_exists(Catalog.asset(key,"corridor.json")):
		preload("res://scripts/spaces/layouts/fairytale_corridor.gd").new().populate(world,region)
		return
	var cfg:=_scene_profile(key)
	var structure:Texture2D=load(Catalog.asset(key,"structure.png"))
	var props:Array[Texture2D]=[]
	for i in 4:
		props.append(load(Catalog.asset(key,"prop-%d.png"%i)))
	var rng:=RandomNumberGenerator.new()
	rng.seed=world.seed_value+hash(key)+region.branch*91
	var structure_cfg:Dictionary=cfg.get("structure",{})
	var cluster_cfg:Dictionary=cfg.get("props",{})
	var wander_cfg:Dictionary=cfg.get("wander",{})
	var deco_cfg:Dictionary=cfg.get("deco",{})

	var s:float=region.start+float(structure_cfg.get("start_offset",42))
	if not world.plan.straight and region.branch!=0:
		s=ForestRoute.JUNCTION+440.0

	# Main structure rhythm and silhouettes.
	while s<region.end:
		var h:=rng.randf_range(float(structure_cfg.get("h_min",285.0)),float(structure_cfg.get("h_max",330.0)))
		var scale:=rng.randf_range(float(structure_cfg.get("scale_min",0.9)),float(structure_cfg.get("scale_max",1.08)))
		h*=scale
		for side in structure_cfg.get("sides",[-1,1]):
			var at:=s+rng.randf_range(-float(structure_cfg.get("start_jitter",24)),float(structure_cfg.get("start_jitter",24)))
			var w:=h*structure.get_width()/float(structure.get_height())
			var lateral:float=0.0
			if side!=0:
				lateral=float(side)*(float(structure_cfg.get("lateral",105))+w*float(structure_cfg.get("lateral_mult",0.45)))
			put(world,region,at,lateral,structure,h,side>0,0.0,float(structure_cfg.get("terrain_unit",0.0)),Vector2(.5,1.0))
		s += rng.randf_range(float(structure_cfg.get("gap_min",145.0)),float(structure_cfg.get("gap_max",170.0)))

	# Props around every structural beat.
	var cluster_count:=int(float(cluster_cfg.get("repeat",10)))
	for i in range(cluster_count):
		var pass_s:float=region.start+float(cluster_cfg.get("start_offset",25)) + i*max(1.0,(region.end-region.start)/max(1.0,float(cluster_count)))
		var count:=rng.randi_range(int(cluster_cfg.get("count_min",2)),int(cluster_cfg.get("count_max",3)))
		for j in range(count):
			var side:= -1 if (i+j)%2==0 else 1
			var i_prop:=_pick_prop_index(cluster_cfg, rng, i+j, props.size())
			var ph:=rng.randf_range(float(cluster_cfg.get("h_min",14.0)),float(cluster_cfg.get("h_max",30.0)))
			var local_x:=float(cluster_cfg.get("lateral_base",80.0))+rng.randf_range(0.0,float(cluster_cfg.get("lateral_span",80.0)))
			put(world,region,pass_s+rng.randf_range(-24.0,24.0),side*local_x,props[i_prop],ph,side>0,0.0,float(cluster_cfg.get("terrain_unit",0.0)),Vector2(.5,1.0))

	# Road ambience and litter.
	var t:=region.start+float(wander_cfg.get("start",50))
	while t<region.end:
		t+=rng.randf_range(float(wander_cfg.get("step_min",58)),float(wander_cfg.get("step_max",96)))
		for _k in range(rng.randi_range(int(wander_cfg.get("batch_min",1)),int(wander_cfg.get("batch_max",2)))):
			var side:= -1 if rng.randf()<0.5 else 1
			var i_prop:=_pick_prop_index(wander_cfg,rng,int(t),props.size())
			var ph:=rng.randf_range(float(wander_cfg.get("h_min",9.0)),float(wander_cfg.get("h_max",33.0)))
			var local_x:=rng.randf_range(float(wander_cfg.get("lateral_min",90.0)),float(wander_cfg.get("lateral_max",185.0)))
			put(world,region,t+rng.randf_range(-16,16),side*local_x,props[i_prop],ph,side>0,rng.randf_range(-1.5,1.5),float(wander_cfg.get("terrain_unit",0.0)),Vector2(.5,1.0))

	# Optional high-layer set pieces for each scene's signature.
	if bool(deco_cfg.get("enabled",false)):
		t=region.start+float(deco_cfg.get("start",220.0))
		while t<region.end:
			var side:= -1.0 if rng.randf()<0.5 else 1.0
			var i_prop:=_pick_prop_index(deco_cfg,rng,int(t),props.size())
			var ph:=rng.randf_range(float(deco_cfg.get("h_min",40.0)),float(deco_cfg.get("h_max",68.0)))
			var local_x:=side*rng.randf_range(float(deco_cfg.get("lateral_min",95.0)),float(deco_cfg.get("lateral_max",130.0)))
			put(world,region,t+rng.randf_range(-10,18),local_x,props[i_prop],ph,side>0,0.0,float(deco_cfg.get("terrain_unit",0.0)),Vector2(.5,1.0))
			t+=rng.randf_range(float(deco_cfg.get("step_min",300.0)),float(deco_cfg.get("step_max",620.0)))

func _pick_prop_index(cfg:Dictionary, rng:RandomNumberGenerator, seed:int, count:int)->int:
	var weights:Array=cfg.get("weights",[])
	if weights.is_empty():
		rng.seed += seed*17
		return rng.randi_range(0,count-1)
	var total:=0.0
	for w in weights:
		total += float(w)
	if total<=0.0:
		return 0
	var roll:=rng.randf_range(0.0,total)
	var acc:=0.0
	for i in range(weights.size()):
		acc += float(weights[i])
		if roll <= acc:
			return min(i,count-1)
	return min(weights.size()-1,count-1)

func _scene_profile(key:String)->Dictionary:
	var p:Dictionary={
		"structure":{"sides":[-1,1],"start_offset":45.0,"start_jitter":24.0,"h_min":285.0,"h_max":330.0,"scale_min":0.9,"scale_max":1.08,"lateral":105.0,"lateral_mult":0.45,"gap_min":145.0,"gap_max":170.0,"terrain_unit":0.0},
		"props":{"repeat":10,"start_offset":20.0,"count_min":2,"count_max":3,"h_min":14.0,"h_max":27.0,"lateral_base":88.0,"lateral_span":78.0,"weights":[2,1,1,1],"terrain_unit":0.0},
		"wander":{"start":48.0,"step_min":58.0,"step_max":96.0,"batch_min":1,"batch_max":2,"h_min":8.0,"h_max":33.0,"lateral_min":92.0,"lateral_max":186.0,"weights":[2,1,1,1],"terrain_unit":0.0},
		"deco":{"enabled":true,"start":220.0,"step_min":300.0,"step_max":620.0,"h_min":40.0,"h_max":68.0,"lateral_min":96.0,"lateral_max":130.0,"weights":[1,1,1,1],"terrain_unit":0.0}
	}
	match key:
		"red_village":
			p.structure.sides=[-1,1]
			p.structure.scale_max=1.12
			p.structure.gap_min=120.0
			p.structure.gap_max=160.0
			p.props.repeat=11
			p.wander.batch_max=3
		"red_cottage":
			p.structure.sides=[0]
			p.structure.h_min=250.0
			p.structure.h_max=280.0
			p.structure.gap_min=122.0
			p.structure.gap_max=160.0
			p.props.repeat=12
			p.props.count_max=3
			p.wander.step_min=44.0
			p.wander.step_max=78.0
			p.deco.enabled=false
		"red_workshop":
			p.structure.sides=[0]
			p.structure.h_min=220.0
			p.structure.h_max=250.0
			p.structure.gap_min=130.0
			p.structure.gap_max=170.0
			p.props.repeat=14
			p.wander.lateral_max=170.0
			p.deco.enabled=false
		"snow_mirror":
			p.structure.sides=[0,-1,1]
			p.structure.h_min=305.0
			p.structure.h_max=350.0
			p.structure.scale_min=0.88
			p.structure.scale_max=1.06
			p.props.repeat=9
			p.props.lateral_base=72.0
			p.props.lateral_span=62.0
		"snow_orchard":
			p.structure.h_min=198.0
			p.structure.h_max=235.0
			p.structure.gap_min=118.0
			p.structure.gap_max=163.0
			p.props.repeat=14
			p.props.lateral_base=84.0
			p.props.lateral_span=94.0
		"snow_house":
			p.structure.sides=[0]
			p.structure.h_min=230.0
			p.structure.h_max=265.0
			p.structure.gap_min=132.0
			p.structure.gap_max=166.0
			p.props.count_min=1
			p.props.count_max=2
			p.wander.batch_max=3
			p.wander.step_min=50.0
			p.wander.step_max=82.0
		"alice_tea":
			p.structure.h_min=170.0
			p.structure.h_max=205.0
			p.structure.lateral=120.0
			p.structure.gap_min=175.0
			p.structure.gap_max=206.0
			p.props.repeat=12
			p.props.h_min=16.0
			p.props.h_max=30.0
		"alice_roses":
			p.structure.h_min=165.0
			p.structure.h_max=190.0
			p.structure.gap_min=134.0
			p.structure.gap_max=172.0
			p.props.count_min=2
			p.props.count_max=4
			p.deco.h_min=46.0
			p.deco.h_max=64.0
		"alice_hall":
			p.structure.sides=[0]
			p.structure.h_min=250.0
			p.structure.h_max=300.0
			p.structure.scale_max=1.14
			p.props.repeat=12
			p.props.h_min=12.0
			p.props.h_max=24.0
			p.wander.batch_max=3
			p.deco.enabled=false
		"piper_market":
			p.structure.h_min=190.0
			p.structure.h_max=230.0
			p.structure.gap_min=136.0
			p.structure.gap_max=165.0
			p.props.repeat=11
		"piper_bridge":
			p.structure.h_min=92.0
			p.structure.h_max=116.0
			p.structure.gap_min=148.0
			p.structure.gap_max=176.0
			p.props.h_min=16.0
			p.props.h_max=34.0
			p.props.count_max=4
			p.deco.enabled=true
			p.deco.h_min=34.0
			p.deco.h_max=52.0
		"piper_mountain":
			p.structure.sides=[0]
			p.structure.h_min=145.0
			p.structure.h_max=185.0
			p.structure.gap_min=188.0
			p.structure.gap_max=230.0
			p.deco.enabled=true
			p.deco.h_min=30.0
			p.deco.h_max=56.0
		"puppet_workshop":
			p.structure.sides=[0]
			p.structure.h_min=235.0
			p.structure.h_max=300.0
			p.structure.gap_min=130.0
			p.structure.gap_max=165.0
			p.props.repeat=13
		"puppet_theatre":
			p.structure.sides=[0,-1,1]
			p.structure.h_min=320.0
			p.structure.h_max=365.0
			p.structure.gap_min=196.0
			p.structure.gap_max=235.0
			p.props.repeat=8
			p.deco.enabled=true
		"puppet_fair":
			p.structure.h_min=180.0
			p.structure.h_max=220.0
			p.props.count_max=4
		"cinder_kitchen":
			p.structure.sides=[0]
			p.structure.h_min=265.0
			p.structure.h_max=300.0
			p.structure.gap_min=124.0
			p.structure.gap_max=166.0
			p.deco.enabled=false
		"cinder_garden":
			p.structure.h_min=190.0
			p.structure.h_max=220.0
			p.structure.gap_min=126.0
			p.structure.gap_max=168.0
			p.props.repeat=12
			p.props.lateral_span=94.0
			p.deco.enabled=true
		"cinder_clock":
			p.structure.sides=[0]
			p.structure.h_min=390.0
			p.structure.h_max=438.0
			p.structure.gap_min=168.0
			p.structure.gap_max=205.0
			p.props.count_min=1
			p.props.count_max=3
			p.deco.h_min=46.0
			p.deco.h_max=64.0
	return p

func put(world,region:RouteRegion,s:float,x:float,tex:Texture2D,h:float,flip:bool,altitude:=0.0,terrain_unit:=0.0,ground_anchor:Vector2=Vector2(.5,1.0))->void:
	var point:=ForestRoute.point_at(s,region.branch,x)
	var w:=h*tex.get_width()/float(tex.get_height())
	var clearance:float=absf(point.x) if world.plan.straight else ForestRoute.road_distance(point,world.plan.exits==3)
	var clearance_mult:=0.40 if absf(x)<=1.5 else 0.50
	if clearance < 76.0+w*clearance_mult:
		return
	world.sprites.append({
		"position":point,
		"texture":tex,
		"w":w,
		"h":h,
		"flip":flip,
		"kind":0,
		"id":world.sprites.size(),
		"region":region,
		"route_s":s,
		"route_branch":region.branch,
		"altitude":altitude,
		"terrain_unit":terrain_unit,
		"motion":"static",
		"biome_prop":true,
		"ground_anchor":Vector2(clampf(ground_anchor.x,0.0,1.0),clampf(ground_anchor.y,0.90,1.0))
	})
