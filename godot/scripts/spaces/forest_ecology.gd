class_name ForestEcology
extends RefCounted
static var textures := {}
static var asset_anchors:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/forest_asset_anchors.json"))
## World-anchored habitat fields. Keep height formula identical to space_ground shader.
static func height_at(p: Vector2) -> float:
	return (2.2*sin(p.y*.009)+1.3*sin(p.x*.017+p.y*.004))*float(ForestSettings.values.height)

static func center(s: float) -> float:
	return float(ForestSettings.values.bend)*(sin(s*.006)+.5*sin(s*.013+.6))

static func half_width(s: float) -> float:
	return maxf(18,float(ForestSettings.values.width)+float(ForestSettings.values.variation)*(sin(s*.008+.9)+.5*sin(s*.019)))

static func populate(world: ForestWorld, straight: bool) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world.seed_value
	for branch in ([0] if straight else [0,-1,1]):
		var begin := -400.0 if branch == 0 else ForestRoute.JUNCTION
		var end := ForestRoute.JUNCTION if branch == 0 and not straight else ForestRoute.END_AT+1800.0
		# Irregular tree groves, never fixed parallel lanes or mirrored pairs.
		var s := begin
		# Sample an area, not parallel lanes. Small trees mix among old trees.
		for i in range(int((end-begin)*.23*float(ForestSettings.values.density))):
			s=rng.randf_range(begin,end)
			var side:float=-1 if rng.randf()<.5 else 1
			var extent:=rng.randf_range(95,185) if rng.randf()<.3 else rng.randf_range(205,355)
			extent*=float(ForestSettings.values.size)
			var offset:=center(s)+side*(half_width(s)+extent*.12+rng.randf_range(5,300))
			place(world,s,branch,offset,"tree-a" if rng.randf()<.5 else "tree-b",extent,0,straight)
		# Cluster centers use independently varying gaps; local members share habitat.
		s = begin
		while s < end:
			s += rng.randf_range(13,34)/float(ForestSettings.values.cover)
			var side := -1.0 if rng.randf()<.5 else 1.0
			var at_center := center(s)+side*rng.randf_range(half_width(s)*.72,265)
			var fern_grove := rng.randf()<.48
			for j in range(rng.randi_range(4,11)):
				var at := s+rng.randf_range(-24,24)
				var offset := at_center+rng.randf_range(-32,32)
				var road := absf(offset-center(at))/half_width(at)
				var mixed := ["fern","clover","shrub","short-grass","reeds"]
				var key: String = "short-grass" if road<.7 else ("fern" if fern_grove and rng.randf()<.5 else mixed[rng.randi_range(0,4)])
				place(world,at,branch,offset,key,rng.randf_range(5,11) if road<1.05 else rng.randf_range(12,27),1)
			if rng.randf()<.2:
				place(world,s,branch,at_center,"stump" if fern_grove else "rocks",rng.randf_range(12,22),1,straight)
		# Trampled plants and litter still exist within the walkable corridor.
		s = begin
		while s < end:
			s += rng.randf_range(14,31)/float(ForestSettings.values.cover)
			var offset := center(s)+rng.randf_range(-1.9,1.9)*half_width(s)
			for j in range(rng.randi_range(5,9)):
				var at := s+rng.randf_range(-15,15)
				var x := offset+rng.randf_range(-24,24)
				place(world,at,branch,x,"short-grass" if rng.randf()<.65 else "clover",rng.randf_range(7,14),1)
			if rng.randf()<.6:
				# This art is already three-quarter view, not an overhead ground decal.
				place(world,s+rng.randf_range(-8,8),branch,offset+rng.randf_range(-25,25),"litter",rng.randf_range(5,9),3)
				world.sprites.back()["ground_anchor"]=Vector2(.5,.82)
	_filter_root_backscatter(world)

static func _filter_root_backscatter(world: ForestWorld) -> void:
	var buckets: Dictionary={}
	for tree in world.sprites:
		if tree.kind!=0:continue
		var cell:=Vector2i(floor(tree.position.x/128),floor(tree.position.y/128))
		if not buckets.has(cell):buckets[cell]=[]
		buckets[cell].append(tree)
	var kept: Array[Dictionary]=[]
	for sprite in world.sprites:
		var blocked:=false
		if sprite.kind==1:
			var cell:=Vector2i(floor(sprite.position.x/128),floor(sprite.position.y/128))
			for dx in range(-2,3):
				for dz in range(-2,3):
					for tree in buckets.get(cell+Vector2i(dx,dz),[]):
						var delta:=ForestRoute.to_camera(sprite.position,tree.position,float(ForestRoute.pose(tree.route_s,tree.route_branch).heading))
						if absf(delta.x)<float(tree.trunk_radius)+8 and delta.y>=-3 and delta.y<18:
							blocked=true
		if not blocked:kept.append(sprite)
	world.sprites=kept

static func root_texture(key: String) -> Texture2D:
	if not textures.has(key):
		var image:=StyleLibrary.texture(key).get_image()
		image.generate_mipmaps()
		textures[key]=ImageTexture.create_from_image(image)
	return textures[key]

static func place(world: ForestWorld, s: float, branch: int, offset: float, key: String, extent: float, kind: int, straight:=true) -> void:
	if not textures.has(key):
		var image := StyleLibrary.texture(key).get_image()
		image.generate_mipmaps()
		textures[key] = ImageTexture.create_from_image(image)
	var tex: Texture2D = textures[key]
	var position := ForestRoute.point_at(s,branch,offset)
	var w := extent*float(tex.get_width())/tex.get_height()
	if kind==0 or key in ["stump","rocks"]:
		# Protect ALL possible paths, not only the branch that spawned this object.
		# Reserve trunk/body space, not the entire canopy rectangle: foliage can overhang.
		var clearance:=maxf(26,half_width(s))+w*(float(asset_anchors[key].trunk_half_width) if kind==0 else .5)+8
		var distance:=absf(position.x) if straight else ForestRoute.road_distance(position)
		if distance<clearance: return
	var variation:=fposmod(sin(s*12.9898+offset*78.233)*43758.5453,1)
	world._add(position,tex,w,extent,variation<.5,kind)
	var sprite: Dictionary = world.sprites.back()
	sprite.route_s=s
	sprite.route_branch=branch
	sprite.ground_extent=extent
	sprite.ecology_tint=Color(1,1,1).darkened(variation*.13)
	if kind==0:
		sprite.trunk_radius=w*float(asset_anchors[key].trunk_half_width)
		var anchor:Array=asset_anchors[key].ground_anchor
		sprite.ground_anchor=Vector2(anchor[0],anchor[1])
		# Local children share the tree's depth and mirror, always painted after its roots.
		var rng:=RandomNumberGenerator.new()
		rng.seed=int(absf(s*813+offset*319))
		sprite.root_cover=[]
		for i in range(5):
			var key_value:String=["short-grass","clover","fern"][rng.randi_range(0,2)]
			var x:=float(anchor[0])+(i-2)*.045+rng.randf_range(-.012,.012)
			sprite.root_cover.append({"texture":root_texture(key_value),"x":x,"height":rng.randf_range(.035,.055),"foot_y":float(anchor[1])})
