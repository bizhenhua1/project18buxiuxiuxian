class_name IslandModel
extends RefCounted
signal changed
signal map_changed
signal arrived(cell: Dictionary)
signal event_requested(position: Vector2i)
const NBS := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
const STEP_SECONDS := 0.5625
const SPIN_SECONDS := 0.30
var samples: Array
var map_index := 0
var cells: Array = []
var lookup := {}
var explored := {}
var last_seen := {}
var sight := {}
var player := Vector2i.ZERO
var walk_path: Array[Vector2i] = []
var walk_from := Vector2i.ZERO
var walk_to := Vector2i.ZERO
var walk_t := 1.0
var walking := false
var heading := 0
var spin_direction := 0
var spin_t := 1.0
var spin_queue := 0
var zoom := 2.4
var zoom_goal := 2.4
var elapsed := 0.0
var hover := Vector2i(-999,-999)
var preview_all := false
var input_locked := false
var pivot := Vector2.ZERO
var reveal_range := 0
var blocked := {}
var rebounding := false
var approach_event := Vector2i(-999,-999)
const REBOUND_SECONDS := 0.6
const AMBUSH_EDGE := 0.46
const AMBUSH_WINDUP := STEP_SECONDS*AMBUSH_EDGE
var probing_monster:=false
var ambush_position:=Vector2i(-999,-999)
var ambush_elapsed:=10.0
var confronted:Dictionary={}
func reveal_near(position: Vector2i) -> void:
	var radius := (reveal_range+1)/2
	for cell in cells:
		var p := key(cell)
		var d := (p-position).abs()
		var included := maxi(d.x,d.y) <= radius if reveal_range % 2 == 0 else d.x+d.y <= radius
		if included: remember(p)
func set_reveal_range(value: int) -> void:
	reveal_range = clampi(value,0,12)
	reveal_near(player)
	changed.emit()

func _init() -> void:
	samples = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_samples.json")).maps
	load_map(0)
static func key(cell: Dictionary) -> Vector2i: return Vector2i(cell.c,cell.r)
static func wxz(c: float, r: float) -> Vector2: return Vector2((c-r)/2,(c+r)/2)
func load_map(index: int) -> void:
	map_index = posmod(index,samples.size())
	cells = samples[map_index].grid.duplicate(true)
	preload("res://scripts/world/island_theme_assets.gd").apply(cells,map_index)
	lookup.clear()
	blocked.clear()
	confronted.clear()
	ambush_elapsed=10.0
	probing_monster=false
	rebounding = false
	approach_event = Vector2i(-999,-999)
	pivot = Vector2.ZERO
	for cell in cells:
		lookup[key(cell)] = cell
		pivot += wxz(cell.c,cell.r)
	pivot /= cells.size()
	explored.clear()
	last_seen.clear()
	var ranked := cells.filter(func(c):return c.layer == "land")
	ranked.sort_custom(func(a,b):return absi(int(a.c)-10)+absi(int(a.r)-10) < absi(int(b.c)-10)+absi(int(b.r)-10))
	player = key(ranked[0])
	walking = false
	walk_path.clear()
	walk_t = 1
	heading = 0
	spin_direction = 0
	spin_t = 1
	spin_queue = 0
	hover = Vector2i(-999,-999)
	reveal_near(player)
	update_sight()
	map_changed.emit()
	changed.emit()
func remember(position: Vector2i) -> void:
	if not lookup.has(position): return
	explored[position] = true
	var cell: Dictionary = lookup[position]
	last_seen[position] = {"base":cell.base,"feat":cell.feat,"h":cell.h,"layer":cell.layer}
func vision_radius() -> int:
	var cell: Dictionary = lookup[player]
	var radius := 3+(1 if cell.h >= 1 else 0)
	if cell.feat != null and cell.feat.get("kind","") == "forest": radius = maxi(1,radius-1)
	return radius
func has_los(from: Vector2i, to: Vector2i) -> bool:
	var n := absi(to.x-from.x)+absi(to.y-from.y)
	for i in range(1,n):
		var p := Vector2(from).lerp(Vector2(to),float(i)/n)
		var position := Vector2i(int(floor(p.x+0.5)),int(floor(p.y+0.5)))
		if position == to: continue
		if not lookup.has(position): return false
		if lookup[position].layer == "ridge" or lookup[position].h > lookup[from].h: return false
	return true
func update_sight() -> void:
	sight = {player:true}
	for cell in cells:
		var position := key(cell)
		if absi(position.x-player.x)+absi(position.y-player.y) <= vision_radius() and has_los(player,position): sight[position] = true
func adjacent(position: Vector2i, set_value: Dictionary) -> bool:
	for offset in NBS:
		if set_value.has(position+offset): return true
	return false
func level(position: Vector2i) -> int:
	if explored.has(position): return 3 if sight.has(position) else 2
	return 1 if sight.has(position) or adjacent(position,sight) else 0
func can_visit(position: Vector2i) -> bool:
	return lookup.has(position) and not (blocked.has(position) and explored.has(position) and confronted.has(position)) and (explored.has(position) or adjacent(position,explored))
func find_path(destination: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not can_visit(destination) or destination == player: return result
	var queue: Array[Vector2i] = [player]
	var previous := {player:player}
	var index := 0
	while index < queue.size():
		var current := queue[index]
		index += 1
		for offset in NBS:
			var next: Vector2i = current+offset
			if previous.has(next) or not lookup.has(next): continue
			var probing_unknown := next == destination and (not explored.has(next) or (blocked.has(next) and not confronted.has(next)))
			if blocked.has(next) and not probing_unknown: continue
			if not explored.has(next) and not probing_unknown: continue
			previous[next] = current
			if next == destination:
				var at := destination
				while at != player:
					result.push_front(at)
					at = previous[at]
				return result
			queue.append(next)
	return result
func go_to(destination: Vector2i) -> bool:
	if input_locked or walking or spin_direction != 0: return false
	if blocked.has(destination) and explored.has(destination) and confronted.has(destination):
		var best: Array[Vector2i] = []
		for offset in NBS:
			var neighbor: Vector2i = destination+offset
			if neighbor == player:
				event_requested.emit(destination)
				return true
			if not explored.has(neighbor): continue
			var path := find_path(neighbor)
			if not path.is_empty() and (best.is_empty() or path.size()<best.size()): best=path
		if best.is_empty(): return false
		approach_event=destination
		walk_path=best
		walking=true
		begin_step()
		return true
	walk_path = find_path(destination)
	if walk_path.is_empty(): return false
	walking = true
	begin_step()
	return true
func begin_step() -> void:
	walk_from = player
	walk_to = walk_path.pop_front()
	walk_t = 0
	probing_monster=blocked.has(walk_to) and blocked[walk_to].get("battle",true) and not confronted.has(walk_to)
	if probing_monster:
		ambush_position=walk_to;ambush_elapsed=0.0
		remember(walk_to)
		walk_path.clear()
		changed.emit()
func rotate_view(direction: int) -> void:
	if input_locked or walking: return
	if spin_direction != 0:
		if spin_direction == direction: spin_queue = direction
		return
	spin_direction = direction
	spin_t = 0
func angles() -> Vector2:
	var base := heading*PI/4
	if spin_direction == 0: return Vector2(base,base)
	var global_weight := 0.5-0.5*cos(PI*clampf(spin_t,0,1))
	var local_weight := 0.5-0.5*cos(PI*clampf((spin_t-0.4)/0.2,0,1))
	return Vector2(base+spin_direction*PI/4*global_weight,base+spin_direction*PI/4*local_weight)
func advance(dt: float) -> void:
	elapsed += dt
	ambush_elapsed+=dt
	zoom = lerpf(zoom,zoom_goal,minf(1,dt/0.07))
	if absf(zoom-zoom_goal) < 0.0008: zoom = zoom_goal
	if walking and probing_monster:
		if ambush_elapsed<AMBUSH_WINDUP:
			walk_t=ambush_elapsed/AMBUSH_WINDUP
		else:
			rebounding=true
			walk_t=clampf((ambush_elapsed-AMBUSH_WINDUP)/REBOUND_SECONDS,0,1)
			if walk_t>=1:
				confronted[walk_to]=true
				probing_monster=false;rebounding=false;walking=false
				update_sight()
	elif walking:
		var step_dt:=maxf(0.0,ambush_elapsed-maxf(AMBUSH_WINDUP,ambush_elapsed-dt)) if rebounding else dt
		walk_t += step_dt/step_seconds()
		while walking and walk_t >= 1:
			var extra := (walk_t-1)*step_seconds()
			if rebounding:
				walking=false
				rebounding=false
				walk_t=1.0
				break
			var previous := walk_from
			player = walk_to
			reveal_near(player)
			update_sight()
			if blocked.has(player):
				var encounter := player
				player=previous
				walk_from=encounter
				walk_to=previous
				walk_t=0.0
				rebounding=true
				walk_path.clear()
				update_sight()
				confronted[encounter]=true
				if blocked[encounter].get("battle",true):
					ambush_position=encounter;ambush_elapsed=0.0
				else:event_requested.emit(encounter)
				break
			arrived.emit(lookup[player])
			if walk_path.is_empty():
				walking = false
				if blocked.has(approach_event): event_requested.emit(approach_event)
				approach_event=Vector2i(-999,-999)
			else:
				begin_step()
				walk_t = extra/step_seconds()
	if spin_direction != 0:
		spin_t += dt/SPIN_SECONDS
		if spin_t >= 1:
			heading = posmod(heading+spin_direction,8)
			spin_direction = 0
			if spin_queue != 0:
				var direction := spin_queue
				spin_queue = 0
				rotate_view(direction)
	changed.emit()
static func ease_walk(t: float) -> float: return 2*t*t if t < 0.5 else 1-pow(-2*t+2,2)/2
func avatar() -> Vector3:
	if not walking: return Vector3(player.x,lookup[player].h,player.y)
	if probing_monster:
		var advance_weight:=AMBUSH_EDGE*(1.0-ease_walk(walk_t) if rebounding else walk_t)
		return Vector3(lerpf(walk_from.x,walk_to.x,advance_weight),lookup[walk_from].h,lerpf(walk_from.y,walk_to.y,advance_weight))
	var weight := clampf(walk_t,0,1)
	var height:float=lookup[walk_from].h
	if rebounding:
		height=lerpf(height,float(lookup[walk_to].h),weight)
	elif has_height_step():
		var start:=jump_start()
		var end:=.82
		var destination:float=lookup[walk_to].h
		if weight>=end:height=destination
		elif weight>start:
			# Upward jumps clear the vertical face before crossing the shared edge (.5).
			# Downward jumps step off the lip, with a small lift followed by a longer fall.
			var peak_at:=.49 if destination>height else .54
			var peak:=maxf(height,destination)+(.35 if destination>height else .10)
			if weight<peak_at:
				var rise:float=(weight-start)/(peak_at-start)
				height=lerpf(height,peak,1-pow(1-rise,2))
			else:
				var fall:float=(weight-peak_at)/(end-peak_at)
				height=lerpf(peak,destination,fall*fall)
	return Vector3(lerpf(walk_from.x,walk_to.x,weight),height,lerpf(walk_from.y,walk_to.y,weight))
func style(position: Vector2i) -> Dictionary:
	var lv := level(position)
	var distance := absi(position.x-player.x)+absi(position.y-player.y)
	var known := lv >= 2 or preview_all
	var bright := 0.76
	var saturation := 0.3
	if preview_all:
		bright = 1.0
		saturation = 1.0
	elif lv == 3:
		var t := minf(1,float(distance)/vision_radius())
		bright = 1.04-t*0.18
		saturation = 1-t*0.22
	elif lv == 2:
		var lift := 0.12 if adjacent(position,sight) else 0.0
		bright = 0.58+lift
		saturation = 0.4+lift
	elif lv == 1:
		bright = 0.92
		saturation = 0.45
	var frontier := not explored.has(position) and adjacent(position,explored)
	var pulse := 0.5+0.5*sin(elapsed*2.8)
	if frontier and not preview_all:
		bright = 0.68+pow(pulse,2)*(0.7 if hover == position else 0.52)+(0.1 if hover == position else 0)
		saturation = 0.3+pow(pulse,2)*0.25
	if hover == position:
		bright = minf(1.42,bright+0.12+pulse*0.48)
		saturation = maxf(saturation,0.65)
	return {"known":known,"bright":bright,"sat":saturation,"frontier":frontier,"level":lv}
func to_save() -> Dictionary:
	var keys: Array = []
	var memories := {}
	for position in explored:
		var id := "%d,%d" % [position.x,position.y]
		keys.append(id)
		memories[id] = last_seen.get(position,{})
	var encounters:Array=[]
	for p in confronted:encounters.append("%d,%d" % [p.x,p.y])
	return {"confronted":encounters,"schema":1,"map_index":map_index,"player":[player.x,player.y],"heading":heading,"zoom":zoom_goal,"explored":keys,"last_seen":memories,"reveal_range":reveal_range}
func restore(data: Dictionary) -> bool:
	if data.get("schema",0) != 1 or not data.has("player"): return false
	if not data.player is Array or data.player.size() != 2: return false
	for component in data.player:
		if not (component is int or component is float): return false
	var index := int(data.get("map_index",0))
	if index < 0 or index >= samples.size(): return false
	var position := Vector2i(data.player[0],data.player[1])
	if not samples[index].grid.any(func(cell):return key(cell) == position): return false
	if not data.get("explored",[]) is Array: return false
	for id in data.get("explored",[]):
		if not id is String: return false
	# Validate before replacing a live map: a bad save must not reset exploration.
	if not (data.get("reveal_range",0) is int or data.get("reveal_range",0) is float): return false
	reveal_range=clampi(int(data.get("reveal_range",0)),0,12)
	load_map(index)
	explored.clear()
	last_seen.clear()
	for id in data.get("explored",[]):
		var parts: PackedStringArray = id.split(",")
		if parts.size() == 2: remember(Vector2i(int(parts[0]),int(parts[1])))
	for id in data.get("confronted",[]):
		var parts:=str(id).split(",")
		if parts.size()==2:confronted[Vector2i(int(parts[0]),int(parts[1]))]=true
	player = position
	remember(player)
	heading = posmod(int(data.get("heading",0)),8)
	zoom = clampf(data.get("zoom",2.4),0.42,2.4)
	zoom_goal = zoom
	update_sight()
	changed.emit()
	return true


func has_height_step() -> bool:
	return walking and lookup[walk_from].h!=lookup[walk_to].h
func jump_start() -> float:
	# Centers are one unit apart; the shared edge is halfway between them.
	return 1.0/3.0 if lookup[walk_to].h>lookup[walk_from].h else .46
func is_jumping() -> bool:
	return not probing_monster and not rebounding and has_height_step() and walk_t>=jump_start() and walk_t<.82
func jump_progress() -> float:
	return clampf((walk_t-jump_start())/(.82-jump_start()),0,1)
func step_seconds() -> float:
	if rebounding:return REBOUND_SECONDS
	return .875 if has_height_step() else STEP_SECONDS
