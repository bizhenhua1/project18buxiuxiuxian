class_name ForestWorld
extends RefCounted
## Both views share exactly this seeded world; landmarks alone differ.
var atmosphere: SkyField
var sprites: Array[Dictionary] = []
var seed_value := 1842
var projection_size := Vector2.ZERO
var projection_camera := Vector2(INF, INF)
var projection_heading := INF
var projection_center := Vector2.ZERO
var projection_cache: Array[Dictionary] = []

func _init(art: ForestArt, straight := false) -> void:
	atmosphere = SkyField.new(art.profile)
	if StyleLibrary.active:
		ForestEcology.populate(self,straight)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var trees := ["tree-side", "tree-b", "tree-c"]
	var lanes := [[122.0, 30.0, 150.0, 55.0], [185.0, 45.0, 180.0, 44.0], [275.0, 65.0, 218.0, 48.0], [405.0, 90.0, 265.0, 52.0], [570.0, 105.0, 330.0, 60.0]]
	for branch in ([0] if straight else [0, -1, 1]):
		var begin := -400.0 if branch == 0 else ForestRoute.JUNCTION
		var end := ForestRoute.JUNCTION if branch == 0 and not straight else ForestRoute.END_AT + 1800.0
		for side in [-1, 1]:
			for lane in lanes:
				var s: float = begin
				while s < end:
					s += lane[3]*(1.65 if StyleLibrary.active else 1.0)
					var offset: float = side * (lane[0] + rng.randf_range(-lane[1], lane[1]))
					var position := ForestRoute.point_at(s, branch, offset)
					# Clearance uses every road, including the unchosen branch. Static geometry.
					var clearance := 165.0 if position.y > ForestRoute.JUNCTION - 70 and position.y < 1800.0 else 125.0
					if (absf(position.x) if straight else ForestRoute.road_distance(position)) < (125.0 if straight else clearance):
						continue
					var tex: Texture2D = art.textures[trees[rng.randi_range(0, 2)]]
					var extent: float = lane[2] * rng.randf_range(0.88, 1.12)
					_add(position, tex, extent * tex.get_width() / float(maxi(tex.get_width(), tex.get_height())), extent * tex.get_height() / float(maxi(tex.get_width(), tex.get_height())), rng.randf() < 0.5, 0)
		# Narrow patches rotate their distribution with the branch; no whole-screen strips crossing roads.
		var s: float = begin
		while s < end:
			s += 38.0 if StyleLibrary.active else 16.0
			for side in [-1, 1]:
				for offset in [105.0, 235.0, 430.0]:
					var pos := ForestRoute.point_at(s + rng.randf_range(-8, 8), branch, side * offset)
					if (absf(pos.x) if straight else ForestRoute.road_distance(pos)) < 65.0:
						continue
					_add(pos, art.patches[rng.randi_range(0, 3)], 42.0 if StyleLibrary.active else 168.0, 20.0 if StyleLibrary.active else 42.0, false, 1)
			# Short cover down the route makes the floor read as meadow rather than a bare road.
			if not StyleLibrary.active: _add(ForestRoute.point_at(s, branch, rng.randf_range(-8, 8)), art.low_patches[rng.randi_range(0, 3)], 142.0, 30.0, false, 1)
		for i in range(int((end - begin) / (40 if StyleLibrary.active else 9))):
			var pos := ForestRoute.point_at(rng.randf_range(begin, end), branch, rng.randf_range(-380, 380))
			if (absf(pos.x) if straight else ForestRoute.road_distance(pos)) < 70.0:
				continue
			var key := "grass-4" if rng.randf() < 0.7 else "grass-1"
			var tex: Texture2D = art.textures[key]
			var h := rng.randf_range(9, 20) if StyleLibrary.active else rng.randf_range(17, 38)
			_add(pos, tex, h * tex.get_width() / float(tex.get_height()), h, rng.randf() < 0.5, 1)

func _add(position: Vector2, tex: Texture2D, w: float, h: float, flip: bool, kind: int) -> void:
	sprites.append({"position": position, "texture": tex, "w": w, "h": h, "flip": flip, "kind": kind, "id": sprites.size()})
