extends RefCounted
func populate(world, region: RouteRegion) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(region.key)) + world.seed_value
	var s := region.start
	while s < region.end:
		for side in [-1, 1]:
			for offset in [215.0, 350.0, 520.0]:
				world.place(region, s + rng.randf_range(0, 35), side * offset, "cave/pillar-%s.png" % ["a", "b", "c"][rng.randi_range(0, 2)], rng.randf_range(300, 370), rng.randf_range(410, 470), 0, side < 0)
		for i in range(6):
			var offset := rng.randf_range(-460, 460)
			var name := "deco-rubble-%d" % rng.randi_range(1, 2)
			if absf(offset) > 110 and rng.randf() < 0.42: name = "deco-stalag-%d" % rng.randi_range(1, 2)
			world.place(region, s + rng.randf_range(0, 45), offset, "cave/" + name + ".png", 48, rng.randf_range(15, 34))
		s += 48
	# The roof is an independent capability. Disabling it does not change wall layout.
	if region.space.ceiling_enabled:
		s = region.start
		while s < region.end:
			if region.branch != 0 and s < 1700:
				s += region.space.shell_spacing
				continue
			world.place(region, s, 0, "cave/arch-%s.png" % ("a" if int(s / region.space.shell_spacing) % 2 == 0 else "b"), region.space.shell_width, region.space.ceiling_height, 0, false, "shell")
			s += region.space.shell_spacing
