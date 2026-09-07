extends IslandView3D
## Experimental geometry; production remains on the accepted clean cliff.
var variant := 0
const HALF := 0.35355339
const NEIGHBORS := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]

func rebuild() -> void:
	super()
	if variant == 0: return
	for tile in tiles.values():
		var cell: Dictionary = tile.cell
		var depth: float = tile.body.mesh.size.y
		var stone: bool = "rock_" in cell.base
		var exposed: Array[bool] = []
		for offset in NEIGHBORS:
			var other: Dictionary = model.lookup.get(IslandModel.key(cell)+offset,{})
			exposed.append(other.is_empty() or float(other.h) < float(cell.h)-0.01)
		var corners := [Vector3(HALF,0,-HALF),Vector3(HALF,0,HALF),Vector3(-HALF,0,HALF),Vector3(-HALF,0,-HALF)]
		var directions := [Vector3.RIGHT,Vector3.BACK,Vector3.LEFT,Vector3.FORWARD]
		var inner: Array[Vector3] = []
		var outer: Array[Vector3] = []
		for edge in range(4):
			for step in range(8):
				var t := float(step)/8
				var point: Vector3 = corners[edge].lerp(corners[(edge+1)%4],t)
				var active: bool = exposed[edge] and (step != 0 or exposed[posmod(edge-1,4)])
				var amount := (0.025 if stone else 0.014) if active else 0.0
				if variant == 2 and active:
					var seed_value := posmod(int(cell.c)*13+int(cell.r)*7+edge*3,7)
					var chip_center := 0.25+float(seed_value)*0.075
					var chip := maxf(0,1-absf(t-chip_center)/0.18)
					amount = (0.012+chip*0.065) if stone else (0.009+chip*0.025)
				var direction: Vector3 = directions[edge]
				if step == 0: direction += directions[posmod(edge-1,4)]
				inner.append(point-direction*amount)
				outer.append(point-Vector3.UP*amount*0.85)
		var top_builder := SurfaceTool.new()
		var side_builder := SurfaceTool.new()
		top_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		side_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		var uv := assets.diamond_uv(cell.base)
		for i in range(inner.size()):
			var j := (i+1)%inner.size()
			add_triangle(top_builder,[Vector3.ZERO,inner[j],inner[i]],uv,true,depth)
			add_triangle(top_builder,[inner[i],inner[j],outer[j]],uv,true,depth)
			add_triangle(top_builder,[inner[i],outer[j],outer[i]],uv,true,depth)
			var bottom_i := Vector3(outer[i].x,-depth,outer[i].z)
			var bottom_j := Vector3(outer[j].x,-depth,outer[j].z)
			add_triangle(side_builder,[outer[i],outer[j],bottom_j],uv,false,depth)
			add_triangle(side_builder,[outer[i],bottom_j,bottom_i],uv,false,depth)
			add_triangle(side_builder,[Vector3(0,-depth,0),bottom_i,bottom_j],uv,false,depth)
		tile.top.mesh = top_builder.commit()
		tile.body.mesh = side_builder.commit()
		if variant == 2 and not stone:
			# One small cluster, on an exposed edge; most of the perimeter stays bare.
			var edge := posmod(int(cell.c)*3+int(cell.r),4)
			if exposed[edge]: add_grass_cluster(tile.root,corners[edge].lerp(corners[(edge+1)%4],0.36))

func add_triangle(builder: SurfaceTool, points: Array, uv: PackedVector2Array, top: bool, depth: float) -> void:
	var normal: Vector3 = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
	for point: Vector3 in points:
		builder.set_normal(normal)
		if top:
			var diamond := Vector3((point.x+point.z)*sqrt(0.5),point.y+0.002,(-point.x+point.z)*sqrt(0.5))
			builder.set_uv((uv[0]+uv[2])*0.5+diamond.x*(uv[0]-uv[2])+diamond.z*(uv[1]-uv[3]))
			builder.add_vertex(diamond)
		else: builder.add_vertex(point+Vector3.UP*depth/2)

func add_grass_cluster(parent: Node3D, point: Vector3) -> void:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var foot := point+Vector3(float(i-2)*0.012,0.004,0)
		var tip := foot+Vector3(float(i-2)*0.012,0.045+0.012*float(i%2),0.006)
		for vertex in [foot-Vector3.RIGHT*0.008,tip,foot+Vector3.RIGHT*0.008]: builder.add_vertex(vertex)
	var mesh := MeshInstance3D.new()
	mesh.mesh = builder.commit()
	mesh.rotation.y = PI/4
	mesh.material_override = surface("",Color("596331"))
	parent.add_child(mesh)
