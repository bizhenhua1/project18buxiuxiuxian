extends RefCounted
func populate(world, region: RouteRegion) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(region.key)) + world.seed_value
	var s := region.start
	while s < region.end:
		for side in [-1, 1]:
			for offset in [215.0, 370.0, 570.0]:
				world.place(region, s + rng.randf_range(0, 20), side * offset, "cloudsea/wall-%s.png" % ["a", "b", "c"][rng.randi_range(0, 2)], 255, rng.randf_range(360, 460))
		s += 70
	# Full-width cloud surface: no road clipping and no opaque grass-like strip ends.
	s = region.start
	while s < region.end:
		for offset in range(-700, 701, 95):
			world.place(region, s + rng.randf_range(-8, 8), offset, "cloudsea/puff-%d.png" % rng.randi_range(1, 4), rng.randf_range(170, 210), rng.randf_range(24, 38), 0, false, "sea")
		s += 45
	for i in range(14):
		world.place(region, rng.randf_range(region.start, region.end), rng.randf_range(-320, 320), "cloudsea/rock-%d.png" % rng.randi_range(1, 4), 50, 45, rng.randf_range(42, 110), false, "floater")
