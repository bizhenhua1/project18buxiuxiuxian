class_name BattleModel
extends RefCounted
signal emitted(event: Dictionary)
signal finished(result: String)
var rules := BattleRules.new()
var player: Array = []
var enemy: Array = []
var shots: Array[Dictionary] = []
var mods: Dictionary = {}
var stage := 0
var phase := "prepare"
var paused := false
var elapsed := 0.0
var rng := RandomNumberGenerator.new()
var killed: Array[String] = []
var wins := 0
var result_generation := 0

func _init() -> void:
	rng.seed = 1842
	default_lineup()
	fill_enemies()

func cap() -> int: return mini(10,8+stage)
func can_edit() -> bool: return phase == "prepare"
func default_lineup() -> void:
	player.clear()
	for id in ["daotong","taomu-jian","waci-yin","masuo","tongjing","xiaohulu","juhun-fan","qingfeng-jian"]:
		player.append(rules.create_unit(id,"player",player.size(),stage))
	restat()
func fill_enemies(randomize := false) -> void:
	enemy.clear()
	var available := rules.cards.filter(func(c): return c.pool == "enemy")
	for i in range(mini(cap(),5+int(stage/2.0))):
		var spec: Dictionary = available[rng.randi_range(0,available.size()-1) if randomize else i%available.size()]
		enemy.append(rules.create_unit(spec.id,"enemy",i,stage))
func restat() -> void:
	for unit in player:
		rules.stats(unit,stage)
		rules.player_mods(unit,mods)
		BattleRules.reset(unit)
	rules.queue_effects(player,mods)
	for i in range(player.size()): player[i].index = i
func reset() -> void:
	phase = "prepare"
	paused = false
	elapsed = 0
	shots.clear()
	killed.clear()
	rng.seed = 1842
	restat()
	for unit in enemy:
		rules.stats(unit,stage)
		BattleRules.reset(unit)
func start() -> bool:
	if phase != "prepare" or player.is_empty() or enemy.is_empty(): return false
	reset()
	phase = "battle"
	result_generation += 1
	return true

func add_card(id: String, at := -1) -> String:
	if not can_edit(): return "战斗中不能调整阵容"
	if player.size() >= cap(): return "上阵位置已满"
	var card := rules.card(id)
	if card.is_empty(): return "未知卡牌"
	var type: String = "beast" if card.pool == "enemy" else card.cardType
	var count := player.filter(func(u):return u.cardType == type).size()
	if type == "char" and count > 0: return "道童只能上场一位"
	if type == "spell" and count >= 1+mods.get("mindSlots",0): return "识海法术位已满"
	if type == "beast" and count >= 1+mods.get("beastSlots",0): return "御兽位已满"
	var unit := rules.create_unit(id,"player",0,stage)
	var target_index := player.size() if at < 0 else clampi(at,0,player.size())
	player.insert(target_index,unit)
	# Original queue keeps mind spells at the right; all other units respect placement order.
	var spells := player.filter(func(u):return u.cardType == "spell")
	player = player.filter(func(u):return u.cardType != "spell") + spells
	restat()
	return ""
func remove_at(index: int) -> void:
	if can_edit() and index >= 0 and index < player.size():
		player.remove_at(index)
		restat()
func move(from: int, to: int) -> void:
	if not can_edit() or from < 0 or from >= player.size(): return
	var unit: Dictionary = player.pop_at(from)
	player.insert(clampi(to,0,player.size()),unit)
	var spells := player.filter(func(u):return u.cardType == "spell")
	player = player.filter(func(u):return u.cardType != "spell")+spells
	restat()
func toggle_mode(index: int) -> String:
	if not can_edit() or index < 0 or index >= player.size(): return ""
	var unit: Dictionary = player[index]
	if unit.cardType != "fabao": return "仅法宝有手持与操控两种模式"
	if unit.mode == "station" and player.filter(func(u):return u.cardType == "fabao" and u.mode == "held").size() >= 2+mods.get("handSlots",0): return "手持位置已满"
	unit.mode = "held" if unit.mode == "station" else "station"
	restat()
	return ""

func emit_events(events: Array) -> void:
	for event in events:
		event.time = elapsed
		emitted.emit(event)
		if event.type != "death": continue
		var unit: Dictionary = event.unit
		if unit.side == "player" and unit.cardType == "fabao" and unit.mode == "station" and unit.reviveMs > 0: unit.reviveLeft = unit.reviveMs
		for ally in player+enemy:
			if BattleRules.alive(ally) and "fan" in ally.tags:
				ally.soulStacks += 1
				emitted.emit({"type":"buff","unit":ally,"amount":ally.soulStacks,"time":elapsed})
		if unit.side == "enemy": killed.append(unit.cardId)
		if unit.side == "player" and unit.cardType == "beast" and mods.get("bloodPact",false):
			for hero in player:
				if hero.cardType == "char" and BattleRules.alive(hero): emit_events(BattleRules.heal(hero,unit.maxHp*0.2))

func power(unit: Dictionary) -> float:
	return unit.atk*(1+unit.soulStacks*unit.fanPerStack if "fan" in unit.tags else 1)
func crit(unit: Dictionary) -> bool: return unit.critChance > 0 and rng.randf() < unit.critChance
func shoot(from: Dictionary, to: Dictionary, amount: float, critical := false, secondary := false) -> void:
	var style: String = from.atkType
	# Original distance-based timing in a fixed reference layout: resizing must not alter combat.
	var flight_distance := Vector2((to.index-from.index)*90,0 if from.side == to.side else 500).length()
	var duration := .18 if style == "beam" else clampf((500+flight_distance*.55)/1000,.48,.72) if style == "ranged" else clampf((300+flight_distance*.38)/1000,.28,.45)
	var shot := {"type":"shot","from":from,"to":to,"amount":amount,"crit":critical,"secondary":secondary,"style":style,"age":0.0,"duration":duration,"time":elapsed}
	shots.append(shot)
	emitted.emit(shot)
func heal_from(from: Dictionary, to: Dictionary, amount: float) -> void:
	var events := BattleRules.heal(to,amount)
	for event in events: from.healDone += event.amount
	emitted.emit({"type":"cast","from":from,"to":to,"time":elapsed})
	emit_events(events)
func act(unit: Dictionary) -> void:
	if not BattleRules.alive(unit): return
	var foes := enemy if unit.side == "player" else player
	var allies := player if unit.side == "player" else enemy
	unit.cdLeft = unit.cd
	unit.actingUntil = elapsed+0.18
	var sealed: bool = unit.cardType == "fabao" and unit.mode == "held" and unit.skill in BattleRules.ACTIVE
	var wounded := BattleRules.living(allies).filter(func(u):return u.uid != unit.uid and u.hp < u.maxHp)
	if unit.cardType == "spell" and unit.spellKind == "mend" and not wounded.is_empty():
		for target in wounded: heal_from(unit,target,power(unit)*0.8*(1+unit.healBoost))
		return
	if not sealed and unit.skill == "heal" and not wounded.is_empty():
		wounded.sort_custom(func(a,b):return a.hp/float(a.maxHp) < b.hp/float(b.maxHp) if not is_equal_approx(a.hp/float(a.maxHp),b.hp/float(b.maxHp)) else a.index < b.index)
		unit.lastTargetUid = wounded[0].uid
		heal_from(unit,wounded[0],unit.atk*1.4*(1+unit.healBoost))
		return
	if not sealed and unit.skill == "shield":
		var gain := BattleRules.js_round(unit.maxHp*0.18*(1+unit.shieldBoost))
		unit.shield += gain
		emitted.emit({"type":"buff","unit":unit,"amount":gain,"time":elapsed})
	if not sealed and unit.skill == "haste":
		var affected := 0
		for i in [unit.index-1,unit.index+1]:
			if i >= 0 and i < allies.size() and BattleRules.alive(allies[i]):
				allies[i].cdLeft = maxf(80,allies[i].cdLeft-allies[i].cd*0.28)
				affected += 1
		emitted.emit({"type":"buff","unit":unit,"amount":affected,"time":elapsed})
	var target := BattleRules.target(foes)
	if target.is_empty(): return
	unit.lastTargetUid = target.uid
	var critical := crit(unit)
	var amount: float = power(unit)*(unit.critDmg if critical else 1.0)
	if unit.cardType == "spell":
		if unit.spellKind == "fireball":
			for foe in BattleRules.living(foes).filter(BattleRules.targetable): shoot(unit,foe,amount,critical,foe.uid != target.uid)
			return
		if unit.spellKind == "bind":
			target.cdLeft += 1400
			emitted.emit({"type":"buff","unit":target,"amount":0,"time":elapsed})
			amount *= 0.4
		elif unit.spellKind == "bolt": amount *= 2.2
	shoot(unit,target,amount,critical)
	if unit.skill == "splash":
		for foe in foes.slice(target.index+1,target.index+1+int(unit.splashN)):
			if BattleRules.alive(foe) and BattleRules.targetable(foe): shoot(unit,foe,amount*unit.splashMult,critical,true)
	if unit.swordEcho > 0 and "sword" in unit.tags:
		for ally in BattleRules.living(allies):
			if ally.uid == unit.uid or "sword" not in ally.tags: continue
			var echo_crit := crit(ally)
			shoot(ally,target,power(ally)*unit.swordEcho*(ally.critDmg if echo_crit else 1.0),echo_crit,true)

func resolve(shot: Dictionary) -> void:
	var events := rules.damage(shot.to,shot.amount,shot.from.dmgType)
	var dealt := 0.0
	for event in events:
		event.source = shot.from
		if event.type == "damage":
			event.crit = shot.crit
			dealt += event.dealt
	shot.from.damageDealt += dealt
	emit_events(events)
	if shot.style == "melee" and dealt > 0 and shot.to.thorns > 0 and BattleRules.alive(shot.from):
		var reflected := rules.damage(shot.from,BattleRules.js_round(dealt*shot.to.thorns),"phys")
		for event in reflected:
			event.source = shot.to
			if event.type == "damage": shot.to.damageDealt += event.dealt
		emit_events(reflected)

func advance(dt: float) -> void:
	if phase != "battle" or paused: return
	elapsed += dt
	var has_hero := player.any(func(u):return u.cardType == "char" and BattleRules.alive(u))
	if not has_hero:
		for unit in BattleRules.living(player):
			if unit.cardType == "spell" or unit.cardType == "fabao" and unit.mode == "held":
				BattleRules.corpse(unit)
				emit_events([{"type":"death","unit":unit}])
	for unit in player:
		if unit.status == "corpse" and unit.reviveLeft > 0:
			unit.reviveLeft -= dt*1000
			if unit.reviveLeft <= 0:
				unit.reviveLeft = 0
				unit.status = "alive"
				unit.hp = unit.maxHp
				unit.shield = 0
				unit.cdLeft = unit.cd
				emitted.emit({"type":"revive","unit":unit,"time":elapsed})
	var all := BattleRules.living(player)+BattleRules.living(enemy)
	all.sort_custom(func(a,b):return a.uid < b.uid)
	for unit in all:
		if not BattleRules.alive(unit): continue
		# Once a terminal condition exists, only already launched shots resolve.
		# Otherwise fresh casts can indefinitely postpone defeat behind inflight shots.
		if not winner().is_empty(): break
		unit.cdLeft -= dt*1000
		if unit.cdLeft <= 0: act(unit)
	var pending: Array[Dictionary] = []
	for shot in shots:
		shot.age += dt
		var impact_time: float = shot.duration*(.68 if shot.style == "beam" else 1.0)
		if not shot.get("resolved",false) and shot.age >= impact_time:
			shot.resolved = true
			resolve(shot)
		if shot.age < shot.duration: pending.append(shot)
	shots = pending
	if shots.is_empty(): check_winner()
func winner() -> String:
	var p := BattleRules.living(player).size()
	var e := BattleRules.living(enemy).size()
	for unit in player:
		if unit.cardType == "char" and unit.status == "corpse": return "draw" if e == 0 else "defeat"
	if p == 0 and player.any(func(u):return u.status == "corpse" and u.reviveLeft > 0): return ""
	if p == 0 and e == 0: return "draw"
	if p == 0: return "defeat"
	if e == 0: return "victory"
	return ""
func check_winner() -> void:
	var result := winner()
	if result.is_empty(): return
	phase = result
	for unit in player: unit.reviveLeft = 0
	if result == "victory": wins += 1
	finished.emit(result)

