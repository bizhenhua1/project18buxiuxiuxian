class_name StyleLibrary
extends RefCounted
## Native dark-fairytale presentation; no alternate cultivation content.
static var active := true
static var cache := {}
const ROOT := "res://assets/style2/"
const CARDS := {
	"investigator":["agent","提灯调查员"], "silent-medium":["medium","缄默灵媒"],
	"night-warden":["warden","巡夜守卫"], "sealed-book":["book","封缄之书"],
	"watchful-clock":["watch","窥时怀表"], "faceless-mask":["mask","无面假面"],
	"soul-lantern":["lantern","引魂提灯"], "scarlet-edict":["book","赤印敕令"],
	"silence-contract":["mask","静默契约"], "severed-moment":["watch","断刻裁决"],
	"ember-renewal":["lantern","余烬复苏"], "containment-record":["book","收容记录"],
	"stopped-clock":["watch","停摆之钟"], "oathbreaker-mask":["mask","破誓假面"],
	"bone-hound":["hound","面骸猎犬"], "bell-walker":["bell","丧钟行者"],
	"dream-moth":["moth","窥梦蛾"], "ashwing":["moth","灰翼眷属"],
	"forest-mourner":["bell","林中送葬者"], "rabid-hound":["hound","失控猎犬"],
	"nightwing":["moth","夜翼"], "bone-wanderer":["hound","骨面徘徊者"],
	"rift-moth":["moth","裂梦飞蛾"], "bell-guardian":["bell","钟骸守门人"]}
static func texture(id: String) -> Texture2D:
	if not cache.has(id): cache[id] = load(ROOT+id+".png")
	return cache[id]
static func path(source: String) -> String:
	if not active or "style2/" in source: return source
	var file := source.get_file().get_basename()
	if "ground-tile" in file: return ROOT+("cliff.png" if "cave/" in source else "ground.png")
	if "/base/" in source: return ROOT+("cliff.png" if "rock" in file else "ground.png")
	if "/link/" in source: return ROOT+"tower.png"
	if "/feature/" in source:
		return ROOT+("tree-a" if ("tree" in file or "grove" in file) else "rocks" if "rock" in file else "tower" if "house" in file or "mountain" in file or "cave" in file else "fern" if "flower" in file or "grass" in file else "shrub")+".png"
	if "puff-" in file or "shroud" in file: return ROOT+"mist.png"
	return source
static func apply_cards(cards: Array) -> void:
	if not active: return
	for card in cards:
		if not CARDS.has(card.id): continue
		var spec: Array = CARDS[card.id]
		card.art = "assets/style2/"+spec[0]+".png"
		card.name = spec[1]
		card.portrait_kind = "person" if spec[0] in ["agent","medium","warden"] else "object"
		if spec[0] in ["medium","warden"]: card.cardType = "beast"
		card.skillText = words(card.skillText)
static func words(value: String) -> String:
	return value
static func card_path(id:String)->String:
	return ROOT+str(CARDS.get(id,["book"])[0])+".png"
static func projectile_path(kind:String)->String:
	return ROOT+str({"sword":"book","seal":"watch","rope":"medium","mirror":"mask","gourd":"lantern"}.get(kind,"book"))+".png"
static func space(original: SpaceType) -> SpaceType:
	if not active: return original
	var copy := original.duplicate(true) as SpaceType
	copy.ground_texture = texture("ground")
	copy.ground_tint = Color(.95,.98,1)
	copy.top_color = Color("202d39")
	copy.atmosphere = original.atmosphere.duplicate(true)
	copy.atmosphere.haze_color = Color("657b85")
	copy.atmosphere.depth_color = Color("101923")
	for layer in copy.atmosphere.cloud_layers: layer.opacity *= .45
	copy.ambient = Color(1.1,1.1,1.1)
	return copy
static func decorate_world(world: IslandModel) -> void:
	preload("res://scripts/world/island_theme_assets.gd").apply(world.cells,world.map_index)
