extends RefCounted
const TITLES={"crystal":"水晶矿洞","swamp":"菌菇沼泽","sewer":"城市下水道","whale":"巨鲸体内","palace":"地下宫殿"}
const CONFIG={
 "crystal":{"tint":Color("536978"),"fog":Color("182735"),"spacing":96.0,"width":510.0,"height":300.0,"density":1.3,"glow":[0],"color":Color(.16,.75,1)},
 "swamp":{"tint":Color("66745a"),"fog":Color("24332e"),"spacing":230.0,"width":830.0,"height":360.0,"density":1.7,"glow":[4,5],"color":Color(.35,1,.58)},
 "sewer":{"tint":Color("676e68"),"fog":Color("202b2a"),"spacing":100.0,"width":530.0,"height":285.0,"density":.8,"glow":[4],"color":Color(1,.61,.22)},
 "palace":{"tint":Color("676e68"),"fog":Color("202b2a"),"spacing":140.0,"width":720.0,"height":355.0,"density":.65,"glow":[4],"color":Color(1,.61,.22)},
 "whale":{"tint":Color("796773"),"fog":Color("312733"),"spacing":130.0,"width":760.0,"height":370.0,"density":1.25,"glow":[2,4],"color":Color(.5,.7,1)}
}
static var seed_value:=1842
static var density_scale:=1.0
static func make_space(key:String) -> SpaceType:
 var c:Dictionary=CONFIG[key]
 var space:=SpaceType.new();space.key=key;space.title=TITLES[key]
 space.layout=load("res://scripts/spaces/layouts/biome_layout.gd")
 space.atmosphere=AtmosphereProfile.new();space.atmosphere.depth_color=c.fog.darkened(.65)
 space.atmosphere.haze_color=c.fog;space.atmosphere.cloud_layers=[]
 space.sky_enabled=false;space.ceiling_enabled=false;space.far_ridge_enabled=false
 space.top_color=c.fog.darkened(.7);space.ground_texture=load("res://assets/biomes/%s/ground.png"%key)
 space.ground_tint=Color(1.15,1.15,1.15);space.ambient=Color(1.3,1.3,1.3)
 space.depth_start=400;space.depth_end=1400
 return space
