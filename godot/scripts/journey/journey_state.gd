class_name JourneyState
extends RefCounted
signal updated
var world := IslandModel.new()
var battle := BattleModel.new()
var zones: Array[Dictionary] = []
var cleared := {}
var pending := ""
var stones := 0
var victories := 0
var last_result := ""
var return_position := Vector2i.ZERO
var journal: Array[String] = []
var route_choices := {}
var reward_bonus := 0
var local_steps := {}
var encounter_plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/local_encounters.json"))
func encounters(direction: int) -> Array:
	return LocalRouteSpec.entries(active_zone(),direction)
func _init() -> void:
	world.arrived.connect(on_arrival)
	world.event_requested.connect(on_event_requested)
	updated.connect(sync_events)
	setup_zones()
	battle.player.clear()
	for id in ["waci-yin","masuo","daotong","taomu-jian","tongjing","xiaohulu","qingfeng-jian","lihuo-shu"]: battle.add_card(id)
	battle.toggle_mode(3)
func setup_zones() -> void:
	StyleLibrary.decorate_world(world)
	IslandWater.solve(world.cells)
	world.update_sight()
	world.map_changed.emit()
	zones.clear()
	cleared.clear()
	pending = ""
	route_choices.clear()
	local_steps.clear()
	world.input_locked = false
	return_position = world.player
	# Anchor encounters to the map's original spawn, never the loaded player position.
	var ranked := world.cells.filter(func(c):return c.layer == "land")
	ranked.sort_custom(func(a,b):return absi(int(a.c)-10)+absi(int(a.r)-10) < absi(int(b.c)-10)+absi(int(b.r)-10))
	var origin := IslandModel.key(ranked[0])
	var queue: Array[Vector2i] = [origin]
	var seen := {origin:true}
	var index := 0
	while index < queue.size():
		var p := queue[index]
		index += 1
		for offset in IslandModel.NBS:
			var next: Vector2i = p+offset
			if world.lookup.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	var names := ["林间小径","林中歇脚处","深林岔道"]
	for i in range(3):
		var position := queue[mini(queue.size()-1,2+i*4)]
		var biome: String = world.lookup[position].get("theme","forest")
		zones.append({"id":"island_%d_%d" % [world.map_index,i],"cell":[position.x,position.y],"title":names[i],"theme":biome,"route_kind":"fork" if i == 2 else "short","route_profile":"short_social" if i == 1 else "short_battle","tier":i,"reward":12+i*6})
	sync_events()
func sync_events() -> void:
	world.blocked.clear()
	for zone in zones:
		if not cleared.has(zone.id):
			world.blocked[Vector2i(zone.cell[0],zone.cell[1])] = {"id":zone.id,"art":"assets/style-e/style-e-monster-%s.png" % ["huoli","shujing","shitoujing"][int(zone.tier)]}
func on_event_requested(position: Vector2i) -> void:
	on_arrival(world.lookup[position])
func active_zone() -> Dictionary:
	for zone in zones:
		if zone.id == pending: return zone
	return {}
func on_arrival(cell: Dictionary) -> void:
	var position := IslandModel.key(cell)
	for zone in zones:
		if Vector2i(zone.cell[0],zone.cell[1]) == position and not cleared.has(zone.id):
			pending = zone.id
			world.input_locked = true
			world.walk_path.clear()
			journal.append("发现 · "+zone.title)
			updated.emit()
			return
	return_position = position
	updated.emit()
func prepare_battle() -> bool:
	var zone := active_zone()
	if zone.is_empty() or cleared.has(zone.id): return false
	battle.stage = world.map_index+int(zone.tier)
	battle.health_multiplier=float(zone.get("battle_hp_multiplier",1.0))
	battle.reset()
	battle.enemy.clear()
	var rosters := [["huoli","caoshe","yewu"],["shujing","jinchan","yewu","caoshe"],["shitoujing","yezhu","huoli","yewu","jinchan"]]
	for id in rosters[int(zone.tier)]: battle.enemy.append(battle.rules.create_unit(id,"enemy",battle.enemy.size(),battle.stage))
	for unit in battle.enemy:battle.scale_health(unit)
	last_result = ""
	return true
func settle(result: String) -> bool:
	var zone := active_zone()
	if zone.is_empty() or cleared.has(zone.id) or battle.phase != result or result not in ["victory","defeat","draw"]: return false
	last_result = result
	if result == "victory":
		cleared[zone.id] = true
		stones += int(zone.reward)+reward_bonus
		victories += 1
		journal.append("平息 · %s · 灵石 +%d" % [zone.title,int(zone.reward)+reward_bonus])
		pending = ""
		world.input_locked = false
		return_position = world.player
	else: journal.append("暂退 · "+zone.title)
	updated.emit()
	return true
func event_kind() -> String:
	if active_zone().is_empty(): return ""
	var entries := encounters(int(route_choices.get(pending,0)))
	var index := int(local_steps.get(pending,0))
	return entries[index].get("event","battle") if index < entries.size() else ""
func finish_local() -> bool:
	var zone := active_zone()
	var required := encounters(int(route_choices.get(pending,0))).size()
	if zone.is_empty() or cleared.has(pending) or int(local_steps.get(pending,0)) < required: return false
	cleared[pending] = true
	stones += int(zone.reward)+reward_bonus
	victories += 1
	last_result = "victory"
	journal.append("走通 · %s · 灵石 +%d" % [zone.title,int(zone.reward)+reward_bonus])
	pending = ""
	world.input_locked = false
	return_position = world.player
	updated.emit()
	return true
func resolve_event(option: String, complete := true) -> bool:
	var zone := active_zone()
	if zone.is_empty() or cleared.has(pending): return false
	var kind := event_kind()
	if kind == "battle": return false
	if option == "fortune":
		var cost := 4 if kind == "merchant" else 0
		if stones < cost: return false
		stones -= cost
		reward_bonus += 3 if kind == "merchant" else 2
		journal.append("获得寻宝机缘 · 本次出征后续收获增加")
	elif option == "supplies":
		stones += int(zone.reward)/2+reward_bonus
		journal.append("带走旅途补给 · 已收入行囊")
	else: return false
	if complete:
		cleared[pending] = true
		pending = ""
		world.input_locked = false
		return_position = world.player
	updated.emit()
	return true
func retreat() -> void:
	if pending.is_empty(): return
	if world.walking: return
	world.walk_path.clear()
	world.update_sight()
	world.input_locked = false
	pending = ""
	updated.emit()
func advance_frontier() -> bool:
	if not pending.is_empty(): return false
	var target := world.player
	for zone in zones:
		if not cleared.has(zone.id):
			target = Vector2i(zone.cell[0],zone.cell[1])
			break
	if target != world.player and world.explored.has(target): return world.go_to(target)
	var choices: Array[Vector2i] = []
	for cell in world.cells:
		var p := IslandModel.key(cell)
		if not world.explored.has(p) and world.can_visit(p) and not world.find_path(p).is_empty(): choices.append(p)
	choices.sort_custom(func(a,b):return Vector2(a).distance_squared_to(target) < Vector2(b).distance_squared_to(target))
	return world.go_to(choices[0]) if not choices.is_empty() else false
func next_island() -> bool:
	if cleared.size() != zones.size(): return false
	world.load_map(world.map_index+1)
	setup_zones()
	updated.emit()
	return true
func to_save() -> Dictionary:
	var formation: Array = []
	for unit in battle.player: formation.append({"id":unit.cardId,"mode":unit.mode})
	return {"schema":1,"world":world.to_save(),"cleared":cleared.keys(),"pending":pending,"stones":stones,"victories":victories,"return_position":[return_position.x,return_position.y],"formation":formation,"journal":journal,"route_choices":route_choices,"reward_bonus":reward_bonus,"local_steps":local_steps}
func restore(data: Dictionary) -> bool:
	if data.get("schema",0) != 1 or not data.get("world") is Dictionary: return false
	if not data.get("formation") is Array or data.formation.size() > 10: return false
	if not data.get("cleared",[]) is Array or not data.get("journal",[]) is Array: return false
	if not data.get("route_choices",{}) is Dictionary: return false
	if not data.get("local_steps",{}) is Dictionary: return false
	for step in data.get("local_steps",{}).values():
		if not (step is int or step is float): return false
		if step != floor(step) or step < 0 or step > 3: return false
	if not (data.get("reward_bonus",0) is int or data.get("reward_bonus",0) is float): return false
	for choice in data.get("route_choices",{}).values():
		if not (choice is int or choice is float): return false
		if choice != -1 and choice != 1: return false
	for field in ["stones","victories"]:
		if not data.get(field,0) is float and not data.get(field,0) is int: return false
	var return_data = data.get("return_position",[])
	if not return_data is Array or return_data.size() != 2: return false
	for coordinate in return_data:
		if not coordinate is int and not coordinate is float: return false
	var new_world := IslandModel.new()
	if not new_world.restore(data.world): return false
	var new_battle := BattleModel.new()
	new_battle.stage = mini(31,new_world.map_index+2)
	new_battle.player.clear()
	for entry in data.formation:
		if not entry is Dictionary or not entry.get("id") is String: return false
		if not new_battle.add_card(entry.id).is_empty(): return false
		if entry.get("mode","") == "held" and not new_battle.toggle_mode(new_battle.player.size()-1).is_empty(): return false
	world = new_world
	battle = new_battle
	world.arrived.connect(on_arrival)
	world.event_requested.connect(on_event_requested)
	setup_zones()
	for id in data.get("route_choices",{}):
		if zones.any(func(z):return z.id == id): route_choices[id] = int(data.route_choices[id])
	for id in data.get("local_steps",{}):
		if zones.any(func(z):return z.id == id): local_steps[id] = int(data.local_steps[id])
	reward_bonus = clampi(int(data.get("reward_bonus",0)),0,100)
	for id in data.cleared:
		if zones.any(func(z):return z.id == id): cleared[id] = true
	pending = str(data.get("pending",""))
	if active_zone().is_empty() or cleared.has(pending): pending = ""
	stones = maxi(0,int(data.get("stones",0)))
	victories = maxi(0,int(data.get("victories",0)))
	var saved_return = data.get("return_position",[])
	if saved_return is Array and saved_return.size() == 2:
		var p := Vector2i(saved_return[0],saved_return[1])
		if world.explored.has(p): return_position = p
	journal.clear()
	for line in data.journal:
		if line is String: journal.append(line)
	world.input_locked = not pending.is_empty()
	sync_events()
	# Older saves could leave the player standing on an unresolved event.
	if world.blocked.has(world.player) and world.lookup.has(return_position) and not world.blocked.has(return_position): world.player=return_position
	return true
