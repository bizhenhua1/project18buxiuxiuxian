class_name IslandWater
extends RefCounted
# Candidate water cells are solved as connected basins before presentation.
static func solve(cells: Array) -> void:
	var lookup := {}
	for cell in cells: lookup[IslandModel.key(cell)]=cell
	var seen := {}
	for seed in cells:
		var start:=IslandModel.key(seed)
		if seed.layer != "water" or seen.has(start): continue
		var basin: Array[Vector2i]=[start]
		seen[start]=true
		var index:=0
		var level:=INF
		var shore:=INF
		var exits: Array[Dictionary]=[]
		while index<basin.size():
			var p:=basin[index]
			index+=1
			var cell: Dictionary=lookup[p]
			if not cell.has("source_h"): cell.source_h=cell.h
			level=minf(level,float(cell.source_h))
			for edge in range(4):
				var next: Vector2i=p+IslandModel.NBS[edge]
				if not lookup.has(next):
					exits.append({"cell":p,"edge":edge})
				elif lookup[next].layer != "water": shore=minf(shore,float(lookup[next].h))
				elif not seen.has(next):
					seen[next]=true
					basin.append(next)
		level=minf(level,shore-0.35)
		# Every exposed edge spills; the distance field routes toward the nearest rim.
		var outlet: Dictionary=exits[0] if not exits.is_empty() else {}
		var distances: Dictionary={}
		if not outlet.is_empty():
			var queue: Array[Vector2i]=[]
			for exit_edge in exits:
				if not distances.has(exit_edge.cell):
					queue.append(exit_edge.cell)
					distances[exit_edge.cell]=0
			for p in queue:
				for offset in IslandModel.NBS:
					var next: Vector2i=p+offset
					if basin.has(next) and not distances.has(next):
						distances[next]=int(distances[p])+1
						queue.append(next)
		for p in basin:
			var cell: Dictionary=lookup[p]
			cell.h=level
			cell.water_level=level
			cell.bed_h=level-0.65
			cell.water_kind="pond" if outlet.is_empty() else "outlet"
			cell.waterfall_edge=int(outlet.edge) if not outlet.is_empty() and outlet.cell==p else -1
			cell.waterfall_edges=[]
			var banks: Array[float]=[0.0,0.0,0.0,0.0]
			var flow:=Vector2.ZERO
			for edge in range(4):
				var next: Vector2i=p+IslandModel.NBS[edge]
				if not lookup.has(next): cell.waterfall_edges.append(edge)
				if lookup.has(next) and lookup[next].layer != "water": banks[edge]=1.0
				if distances.has(next) and int(distances[next])<int(distances.get(p,0)):
					flow=IslandModel.wxz(next.x,next.y)-IslandModel.wxz(p.x,p.y)
			if not cell.waterfall_edges.is_empty():
				flow=Vector2.ZERO
				for edge in cell.waterfall_edges:
					var next: Vector2i=p+IslandModel.NBS[edge]
					flow+=IslandModel.wxz(next.x,next.y)-IslandModel.wxz(p.x,p.y)
			cell.water_flow=[flow.x,flow.y]
			cell.water_banks=banks
