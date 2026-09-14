extends RefCounted
const CATALOG=preload("res://scripts/spaces/biome_catalog.gd")
const KEYS=["connected","forest","crystal","swamp","sewer","whale","palace"]
const LABELS=["森林 · 主题岔路","森林","水晶矿洞","菌菇沼泽","城市下水道","巨鲸体内","地下宫殿"]
static func plan(key:String,exits:int=2,layout_seed:int=1842)->RoutePlan:
 assert(exits in [2,3])
 var result:RoutePlan=load("res://spaces/routes/connected.tres").duplicate(true)
 result.layout_seed=layout_seed;result.exits=exits
 if exits==3:
  for original in result.regions.duplicate():
   if original.branch==-1:
    var middle:RouteRegion=original.duplicate();middle.branch=2;middle.key=StringName(str(original.key)+"_middle");result.regions.append(middle)
 if key=="connected":
  var replacements={"forest":StyleLibrary.space(load("res://spaces/types/forest.tres")),"cave":CATALOG.make_space("crystal"),"cloudsea":CATALOG.make_space("swamp")}
  for region in result.regions:
   if str(region.space.key) in replacements:region.space=replacements[str(region.space.key)]
 else:
  assert(key in KEYS)
  var space:SpaceType=StyleLibrary.space(load("res://spaces/types/forest.tres")) if key=="forest" else CATALOG.make_space(key)
  for region in result.regions:region.space=space
 # Duplicate each shared SpaceType once; never mutate the legacy resource cache.
 var native_spaces:Dictionary={}
 for region in result.regions:
  if region.space.layout==load("res://scripts/spaces/layouts/biome_layout.gd"):
   if not native_spaces.has(region.space):
    var native:SpaceType=region.space.duplicate()
    native.layout=preload("res://scripts/world3d/biome_layout.gd")
    native_spaces[region.space]=native
   region.space=native_spaces[region.space]
 result.title=LABELS[KEYS.find(key)]
 return result
