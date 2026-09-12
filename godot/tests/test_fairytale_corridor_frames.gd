extends SceneTree
const Layout=preload("res://scripts/spaces/layouts/fairytale_corridor.gd")

func _initialize()->void:
	var layouts:=0
	for scene in FairytaleCatalog.scenes:
		for exits in [1,2,3]:
			for branch in ([0] if exits==1 else [0,-1,1,2] if exits==3 else [0,-1,1]):
				ForestRoute.reset_frame()
				var region:=RouteRegion.new()
				region.space=SpaceType.new();region.space.key=scene.id
				region.branch=branch;region.start=-150 if branch==0 else ForestRoute.JUNCTION
				region.end=ForestRoute.JUNCTION if branch==0 and exits>1 else 2100
				var first:Dictionary=make_world(exits)
				Layout.new().populate(first,region)
				assert(not first.sprites.is_empty(),scene.id)
				ForestRoute.origin=Vector2(830,-440)
				ForestRoute.origin_heading=.83
				var rotated:Dictionary=make_world(exits)
				Layout.new().populate(rotated,region)
				assert(first.sprites.size()==rotated.sprites.size(),"Frame changed placement count: "+scene.id)
				for i in first.sprites.size():
					var a:Dictionary=first.sprites[i]
					var b:Dictionary=rotated.sprites[i]
					assert(a.position.distance_to(ForestRoute.local_point(b.position))<.01,"Frame changed placement: "+scene.id)
					assert(region.contains(a.route_s,a.route_branch),"Sprite escaped region: "+scene.id)
					assert(a.altitude==0 and a.terrain_unit==0)
					assert(absf(a.w/a.h-float(a.texture.get_width())/a.texture.get_height())<.001)
				layouts+=1
	ForestRoute.reset_frame()
	print("CORRIDOR_FRAME_PASS layouts=",layouts)
	quit()

func make_world(exits:int)->Dictionary:
	return {"seed_value":1842,"plan":{"straight":exits==1,"exits":exits},"sprites":[]}
