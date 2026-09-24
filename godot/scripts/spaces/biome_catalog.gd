extends RefCounted
static var TITLES={"crystal":"水晶矿洞","swamp":"菌菇沼泽","sewer":"城市下水道","whale":"巨鲸体内","palace":"地下宫殿"}
static var CONFIG={
 "crystal":{"tint":Color("536978"),"fog":Color("182735"),"backdrop":Color("000000"),"spacing":96.0,"width":420.0,"height":245.0,"density":1.3,"glow":[0],"color":Color(.16,.75,1)},
 "swamp":{"tint":Color("66745a"),"fog":Color("24332e"),"spacing":230.0,"width":830.0,"height":360.0,"density":1.7,"glow":[4,5],"color":Color(.35,1,.58)},
 "sewer":{"tint":Color("676e68"),"fog":Color("202b2a"),"spacing":100.0,"width":530.0,"height":285.0,"density":.8,"glow":[4],"color":Color(1,.61,.22)},
 "palace":{"tint":Color("676e68"),"fog":Color("202b2a"),"spacing":140.0,"width":720.0,"height":355.0,"density":.65,"glow":[4],"color":Color(1,.61,.22)},
 "whale":{"tint":Color("796773"),"fog":Color("312733"),"backdrop":Color("15080d"),"spacing":130.0,"width":760.0,"height":370.0,"density":1.25,"glow":[2,4],"color":Color(.5,.7,1)}
}
static var tales_loaded:=_load_tales()
static func _load_tales()->bool:
 for scene in FairytaleCatalog.scenes:
  TITLES[scene.id]=scene.name
  CONFIG[scene.id]={"tint":Color(scene.fog),"fog":Color(scene.fog),"spacing":180.0,"width":700.0,"height":300.0,"density":.7,"glow":[],"color":Color(scene.accent)}
 return true
static var seed_value:=1842
static var density_scale:=1.0
static func make_space(key:String) -> SpaceType:
 var c:Dictionary=CONFIG[key]
 var space:=SpaceType.new();space.key=key;space.title=TITLES[key]
 space.layout=load("res://scripts/spaces/layouts/fairytale_layout.gd" if FairytaleCatalog.has_scene(key) else "res://scripts/spaces/layouts/biome_layout.gd")
 space.atmosphere=AtmosphereProfile.new();space.atmosphere.depth_color=c.fog.darkened(.65)
 space.atmosphere.haze_color=c.fog;space.atmosphere.cloud_layers=[]
 space.sky_enabled=false;space.ceiling_enabled=false;space.far_ridge_enabled=false
 space.top_color=c.get("backdrop",c.fog.darkened(.7));space.ground_texture=load(FairytaleCatalog.asset(key,"ground.png") if FairytaleCatalog.has_scene(key) else "res://assets/biomes/%s/ground.png"%key)
 space.ground_tint=Color(1.15,1.15,1.15);space.ambient=Color(1.3,1.3,1.3)
 space.depth_start=400;space.depth_end=1400
 return space

# Multipliers retain the established forest light while matching each mist palette.
static func environment_light_tint(key:String,amount:float=.25) -> Color:
 if FairytaleCatalog.has_scene(key):return Color.WHITE.lerp(Color(FairytaleCatalog.entry(key).accent),amount*.6)
 var palette:Color={"crystal":Color(.65,.95,1.15),"swamp":Color(.5,.75,1.2),"sewer":Color(.45,1,.45),"palace":Color(.55,.9,.65),"whale":Color(1.4,.24,.20)}.get(key,Color.WHITE)
 return Color.WHITE.lerp(palette,amount)

static func enemy_light_tint(key:String) -> Color:
 return environment_light_tint(key,.25)
