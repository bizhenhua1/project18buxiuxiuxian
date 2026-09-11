class_name StyleLibrary
extends RefCounted
## Opt-in presentation family. Original rules/IDs and Style 1 files remain intact.
static var active := "--style2" in OS.get_cmdline_user_args()
static var cache := {}
const ROOT := "res://assets/style2/"
const CARDS := {
	"daotong":["agent","提灯调查员"], "masuo":["medium","缄默灵媒"],
	"qingfeng-jian":["warden","巡夜守卫"], "taomu-jian":["book","封缄之书"],
	"waci-yin":["watch","窥时怀表"], "tongjing":["mask","无面假面"],
	"xiaohulu":["lantern","引魂提灯"], "lihuo-shu":["book","赤印敕令"],
	"bingfu-jue":["mask","静默契约"], "tianlei-yin":["watch","断刻裁决"],
	"huichun-shu":["lantern","余烬复苏"], "juhun-fan":["book","收容记录"],
	"xuantie-jian":["watch","停摆之钟"], "kaishan-fu":["mask","破誓假面"],
	"huoli":["hound","面骸猎犬"], "caoshe":["bell","丧钟行者"],
	"yewu":["moth","窥梦蛾"], "jinchan":["moth","灰翼眷属"],
	"shujing":["bell","林中送葬者"], "yezhu":["hound","失控猎犬"],
	"xiaoqiao":["moth","夜翼"], "shanyang":["hound","骨面徘徊者"],
	"huangfeng":["moth","裂梦飞蛾"], "shitoujing":["bell","钟骸守门人"]}
static func texture(id: String) -> Texture2D:
	if not cache.has(id): cache[id] = load(ROOT+id+".png")
	return cache[id]
static func path(source: String) -> String:
	if not active or "style2/" in source: return source
	var file := source.get_file().get_basename()
	if file == "style-e-char-daotong": return ROOT+"agent.png"
	for prefix in ["style-e-monster-","style-e-artifact-"]:
		if file.begins_with(prefix):
			var id := file.trim_prefix(prefix)
			if CARDS.has(id): return ROOT+CARDS[id][0]+".png"
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
	if not active: return value
	for pair in [["灵石","秘银"],["道童","调查员"],["法宝","封印物"],["妖物","异变体"],["妖息","异常气息"],["妖势","敌势"],["机缘","线索"],["识海","术式"],["御兽","使役"],["采药人","档案员"],["有缘人","同行者"],["寻宝符","勘探许可"]]: value = value.replace(pair[0],pair[1])
	return value
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
