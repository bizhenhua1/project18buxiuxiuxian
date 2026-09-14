class_name HomeState
extends RefCounted
signal changed
const PLANTS := {
	"herbs":{"name":"药草圃","cost":8,"period":60.0,"yield":3,"art":"flower_1"},
	"grove":{"name":"苗木园","cost":12,"period":90.0,"yield":5,"art":"grove_1"}}
const COTTAGE := Vector2i(9,10)
var world := IslandModel.new()
var bank := 24
var returns := 0
var unlocked := {}
var plots := {}
var selected := Vector2i(10,10)
var message := "先在空地种下一圃药草，再出发寻找云外的线索。"
func _init() -> void:
	# A fixed home layout, independent of the expedition sample pool.
	world.cells.clear()
	world.lookup.clear()
	for r in range(8,13):
		for c in range(8,13):
			if (c in [8,12]) and (r in [8,12]): continue
			var cell := {"c":c,"r":r,"h":0,"layer":"land","base":"assets/world/forest/base/grass_%d.png" % (1+posmod(c+r,3)),"feat":null}
			world.cells.append(cell)
			world.lookup[Vector2i(c,r)] = cell
	world.pivot = IslandModel.wxz(10,10)
	world.player = Vector2i(10,10)
	world.explored.clear()
	world.preview_all = true
	world.zoom = 1.3
	world.zoom_goal = 1.3
	for p in world.lookup:
		if absi(p.x-10)+absi(p.y-10) <= 2: unlocked[p] = true
	plots[Vector2i(9,9)] = {"kind":"grove","growth":0.0}
	plots[Vector2i(11,10)] = {"kind":"herbs","growth":0.0}
	rebuild()
func rebuild() -> void:
	for p in world.lookup:
		var cell: Dictionary = world.lookup[p]
		cell.feat = null
		cell.base = "assets/world/forest/base/grass_%d.png" % (1+posmod(p.x+p.y,3)) if unlocked.has(p) else "assets/world/forest/base/rock_1.png"
		cell.h = 0 if unlocked.has(p) else -1
		if plots.has(p):
			cell.feat = {"kind":"garden","src":"assets/world/forest/feature/%s.png" % PLANTS[plots[p].kind].art,"w":0.42 if plots[p].kind == "herbs" else 0.9}
		elif p == Vector2i(10,8):
			cell.feat = {"kind":"tree","src":"assets/world/forest/feature/giant_tree_1.png","w":1.5}
		elif p == COTTAGE:
			cell.feat = {"kind":"home","src":"assets/home/cottage.png","w":1.25}
		world.remember(p)
	world.update_sight()
	world.map_changed.emit()
	changed.emit()
func unlock(p: Vector2i) -> bool:
	if not world.lookup.has(p) or unlocked.has(p) or not world.adjacent(p,unlocked) or bank < 10: return false
	bank -= 10
	unlocked[p] = true
	message = "封土已开，可以在这里安排新的种植。"
	rebuild()
	return true
func plant(p: Vector2i, kind: String) -> bool:
	if not PLANTS.has(kind) or not unlocked.has(p) or plots.has(p) or p in [world.player,Vector2i(10,8),COTTAGE] or bank < PLANTS[kind].cost: return false
	bank -= PLANTS[kind].cost
	plots[p] = {"kind":kind,"growth":0.0}
	message = "已布置 "+PLANTS[kind].name
	rebuild()
	return true
func relocate(from: Vector2i,to: Vector2i) -> bool:
	if not plots.has(from) or not unlocked.has(to) or plots.has(to) or to in [world.player,Vector2i(10,8),COTTAGE]: return false
	plots[to] = plots[from]
	plots.erase(from)
	message = "已搬迁，生长进度保留。"
	rebuild()
	return true
func advance(dt: float) -> void:
	for plot in plots.values(): plot.growth = minf(PLANTS[plot.kind].period,float(plot.growth)+maxf(0,dt))
func harvest() -> int:
	var amount := 0
	for plot in plots.values():
		if plot.growth >= PLANTS[plot.kind].period:
			amount += PLANTS[plot.kind].yield
			plot.growth = 0.0
	bank += amount
	message = "收获秘银 %d" % amount if amount > 0 else "草木尚在生长，成熟后可收获。"
	changed.emit()
	return amount
func to_save() -> Dictionary:
	var saved_plots: Array = []
	var land: Array = []
	for p in unlocked: land.append([p.x,p.y])
	for p in plots: saved_plots.append({"cell":[p.x,p.y],"kind":plots[p].kind,"growth":plots[p].growth})
	return {"bank":bank,"returns":returns,"unlocked":land,"plots":saved_plots}
func restore(data: Dictionary) -> bool:
	if not data.get("unlocked") is Array or not data.get("plots") is Array: return false
	if not (data.get("bank") is int or data.get("bank") is float): return false
	var land := {}
	var plants := {}
	for cell in data.unlocked:
		if not valid_cell(cell): return false
		land[Vector2i(cell[0],cell[1])] = true
	if not land.has(world.player): return false
	for plot in data.plots:
		if not plot is Dictionary or not valid_cell(plot.get("cell")) or not PLANTS.has(plot.get("kind","")): return false
		if not (plot.get("growth") is int or plot.get("growth") is float): return false
		var p := Vector2i(plot.cell[0],plot.cell[1])
		if not land.has(p) or plants.has(p) or p in [world.player,Vector2i(10,8),COTTAGE]: return false
		plants[p] = {"kind":plot.kind,"growth":clampf(plot.growth,0,PLANTS[plot.kind].period)}
	if not (data.get("returns",0) is int or data.get("returns",0) is float): return false
	unlocked = land
	plots = plants
	bank = maxi(0,int(data.bank))
	returns = maxi(0,int(data.get("returns",0)))
	rebuild()
	return true
func valid_cell(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for n in value:
		if not (n is int or n is float): return false
	return world.lookup.has(Vector2i(value[0],value[1]))
