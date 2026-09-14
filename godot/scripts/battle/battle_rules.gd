class_name BattleRules
extends RefCounted
## Native rules port. The JSON catalog and reference fixtures are exported from the original JS.
const ACTIVE := ["heal", "shield", "haste"]
var cards: Array = []
var balance: Dictionary
var next_uid := 1

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_cards.json"))
	cards = data.cards
	StyleLibrary.apply_cards(cards)
	FairytaleCatalog.append_cards(cards)
	balance = data.balance
	var roster:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/character_roster.json"))
	for i in range(roster.size()):
		var entry:Dictionary=card("investigator").duplicate(true)
		entry.id="character_"+str(i);entry.name=roster[i].name;entry.model_file=roster[i].file
		entry.portrait_kind="person";entry.skillText="角色 · 装备决定动作；长按打开装配"
		cards.append(entry)

func card(id: String) -> Dictionary:
	for value in cards:
		if value.id == id: return value
	return {}

static func js_round(value: float) -> int: return int(floor(value + 0.5))
static func alive(unit: Dictionary) -> bool: return unit.status == "alive" and unit.hp > 0
static func targetable(unit: Dictionary) -> bool: return unit.cardType != "spell" and not (unit.cardType == "relic" and unit.mode == "held")
static func living(queue: Array) -> Array:
	return queue.filter(func(u): return alive(u))
static func target(queue: Array) -> Dictionary:
	for unit in queue:
		if alive(unit) and targetable(unit): return unit
	return {}
static func corpse(unit: Dictionary) -> void:
	unit.hp = 0
	unit.shield = 0
	unit.status = "corpse"
	unit.cdLeft = unit.cd
	unit.lastTargetUid = -1

func create_unit(id: String, side: String, index := 0, stage := 0, mode := "station") -> Dictionary:
	var spec := card(id)
	assert(not spec.is_empty(), "Unknown card: " + id)
	var unit := spec.duplicate(true)
	unit.uid = next_uid
	next_uid += 1
	unit.cardId = id
	unit.cardType = "beast" if side == "player" and spec.pool == "enemy" else spec.cardType
	unit.mode = ("held" if mode == "held" else "station") if unit.cardType == "relic" else ""
	unit.side = side
	unit.index = index
	unit.baseAtk = spec.atk
	unit.baseHp = spec.hp
	unit.baseCd = spec.cd
	unit.basePhysDef = spec.physDef
	unit.baseSpellDef = spec.spellDef
	unit.baseReviveMs = spec.reviveMs
	unit.spellKind = spec.get("spellKind", "")
	unit.art = spec.get("art", "")
	for key in ["critChance","soulStacks","thorns","dmgReduce","healBoost","shieldBoost","swordEcho","damageDealt","healDone","reviveLeft"]: unit[key] = 0.0
	unit.critDmg = 1.5
	unit.splashN = 2
	unit.splashMult = 0.5
	unit.fanPerStack = 0.08
	stats(unit, stage)
	reset(unit)
	return unit

func stats(unit: Dictionary, stage: int) -> void:
	stage = maxi(0,stage)
	var is_enemy: bool = unit.side == "enemy"
	var boss := stage % 8 == 7
	var core := pow(balance.stageGrowth,stage) * pow(balance.regionGrowth,floor(stage/8.0))
	var hp := core * pow(balance.monsterHpDrift if is_enemy else balance.playerHpDrift,stage)
	var atk := core * (pow(balance.monsterAtkDrift,stage) if is_enemy else 1.0)
	if is_enemy and boss:
		hp *= balance.bossHp
		atk *= balance.bossAtk
	var cd: float = balance.cdMin + (1.0-balance.cdMin)/(1.0+stage*balance.cdHaste)
	unit.atk = maxi(1,js_round(unit.baseAtk*atk))
	unit.maxHp = maxi(1,js_round(unit.baseHp*hp))
	unit.hp = unit.maxHp
	unit.cd = maxi(int(balance.cdHardMinMs),js_round(unit.baseCd*cd))
	unit.cdLeft = unit.cd
	unit.stageSnap = stage
	var def_add := js_round(stage*balance.defGrowthPerStage) if is_enemy else 0
	unit.physDef = unit.basePhysDef + def_add
	unit.spellDef = unit.baseSpellDef + def_add
	if is_enemy:
		unit.atk = maxi(1,js_round(unit.atk*(1.0+minf(balance.dmgGrowthCap,stage*balance.dmgGrowthPerStage))))
		unit.critChance = balance.bossCritChance if stage >= balance.critBossStage and boss else 0.0

static func reset(unit: Dictionary) -> void:
	unit.hp = unit.maxHp
	unit.cdLeft = unit.cd
	unit.status = "alive"
	unit.lastTargetUid = -1
	for key in ["shield","actingUntil","damageDealt","healDone","soulStacks","reviveLeft"]: unit[key] = 0.0

func player_mods(unit: Dictionary, mods: Dictionary) -> void:
	var atk_pct: float = mods.get("atkPct",0)
	var hp_pct: float = mods.get("hpPct",0)
	if unit.cardType in ["relic","beast"]:
		atk_pct += mods.get(unit.cardType+"AtkPct",0)
		hp_pct += mods.get(unit.cardType+"HpPct",0)
	atk_pct += mods.get("spellPct" if unit.dmgType == "spell" else "physPct",0)
	unit.atk = maxi(1,js_round(unit.atk*(1+atk_pct/100)))
	var held: bool = unit.cardType == "relic" and unit.mode == "held"
	if held: unit.atk = maxi(1,js_round(unit.atk*(1+unit.weight*0.06)))
	unit.maxHp = maxi(1,js_round(unit.maxHp*(1+hp_pct/100)))
	unit.hp = unit.maxHp
	unit.cd = maxi(400,js_round(unit.cd*maxf(0.5,1-mods.get("cdPct",0)/100.0)))
	if unit.cardType == "char" or held: unit.cd = maxi(400,js_round(unit.cd/(1+mods.get("atkSpeedPct",0)/100.0)))
	if unit.cardType == "spell" or unit.skill in ACTIVE and not held: unit.cd = maxi(400,js_round(unit.cd/(1+mods.get("skillCdrPct",0)/100.0)))
	unit.cdLeft = minf(unit.cdLeft,unit.cd)
	unit.critChance = clampf(mods.get("critPct",0)/100.0,0,1)
	unit.critDmg = 1.5+maxf(0,mods.get("critDmgPct",0))/100.0
	unit.physDef = unit.basePhysDef + maxf(0,mods.get("physDef",0))
	unit.spellDef = unit.baseSpellDef + maxf(0,mods.get("spellDef",0))
	if unit.cardType == "relic": unit.reviveMs = maxi(1000,js_round(unit.baseReviveMs*(1-clampf(mods.get("reviveCdrPct",0),0,80)/100)))
	unit.dmgReduce = minf(0.6,mods.get("dmgReducePct",0)/100.0)
	unit.thorns = maxf(0,mods.get("thornsPct",0)/100.0)
	unit.splashMult = 0.5*(1+mods.get("splashDmgPct",0)/100.0)
	unit.splashN = 2+mods.get("splashN",0)
	unit.healBoost = mods.get("healPct",0)/100.0+(mods.get("spellPct",0)/100.0 if unit.cardType == "spell" else 0)
	unit.shieldBoost = mods.get("shieldPct",0)/100.0
	unit.swordEcho = maxf(0,mods.get("swordEchoPct",0)/100.0)
	unit.fanPerStack = mods.get("fanPerStackPct",8)/100.0 if mods.get("fanPerStackPct",8) > 0 else 0.08

func queue_effects(queue: Array, mods: Dictionary) -> void:
	var beasts := {}
	var hero: Dictionary = {}
	var pool := 0.0
	for unit in queue:
		if unit.cardType == "beast": beasts[unit.cardId] = true
		if unit.cardType == "char": hero = unit
		if unit.cardType == "relic" and unit.mode == "held": pool += unit.maxHp
	if mods.get("beastResonance",false):
		for unit in queue: unit.atk = maxi(1,js_round(unit.atk*(1+beasts.size()*0.02)))
	if not hero.is_empty():
		hero.maxHp += js_round(pool*(30+maxf(0,mods.get("mergeHeldHpPct",0)))/100)
		hero.hp = hero.maxHp

func damage(target_unit: Dictionary, amount: float, type = null) -> Array:
	if target_unit.is_empty() or not alive(target_unit): return []
	var defense: float = target_unit.get("spellDef",0) if type == "spell" else target_unit.get("physDef",0) if type == "phys" else 0.0
	var reduction := minf(balance.defCap,defense/(defense+balance.defBase+balance.defPerStage*target_unit.get("stageSnap",0)))
	var rest := maxi(0,js_round(amount*(1-reduction)*(1-target_unit.get("dmgReduce",0))))
	if rest <= 0: return []
	var absorbed := minf(target_unit.shield,rest)
	target_unit.shield -= absorbed
	rest -= absorbed
	var dealt := absorbed + minf(target_unit.hp,rest)
	target_unit.hp -= rest
	var events: Array = [{"type":"damage","unit":target_unit,"amount":js_round(amount),"dealt":dealt,"dmgType":type}]
	if target_unit.hp <= 0:
		corpse(target_unit)
		events.append({"type":"death","unit":target_unit})
	return events

static func heal(unit: Dictionary, amount: float) -> Array:
	if unit.is_empty() or unit.status == "corpse": return []
	var before: float = unit.hp
	unit.hp = minf(unit.maxHp,unit.hp+maxi(0,js_round(amount)))
	return [{"type":"heal","unit":unit,"amount":unit.hp-before}] if unit.hp > before else []
