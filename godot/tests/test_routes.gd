extends SceneTree
## Functional invariants of the new branching model. Run with --headless --script.

var failures: Array[String] = []

func _initialize() -> void:
	for distance in [0.0, 460.0, 699.99, 700.0, 700.01, 850.0, 1119.99, 1120.0, 1120.01, 1800.0, 3650.0]:
		var left := ForestRoute.pose(distance, -1)
		var right := ForestRoute.pose(distance, 1)
		check(absf(left.position.x + right.position.x) < 0.001, "left/right X symmetry at %f" % distance)
		check(absf(left.position.y - right.position.y) < 0.001, "left/right Z symmetry at %f" % distance)
		check(absf(left.heading + right.heading) < 0.001, "heading symmetry")
	for branch in [-1, 1]:
		for boundary in [ForestRoute.JUNCTION, ForestRoute.JUNCTION + ForestRoute.TURN_LENGTH]:
			var before := ForestRoute.pose(boundary - 0.01, branch)
			var after := ForestRoute.pose(boundary + 0.01, branch)
			check(before.position.distance_to(after.position) < 0.021, "position continuous at segment boundary")
			check(absf(before.heading - after.heading) < 0.001, "heading continuous at segment boundary")
		var mid := ForestRoute.pose(1800, branch)
		var final := ForestRoute.pose(ForestRoute.END_AT, branch)
		check(absf(final.heading - branch * ForestRoute.TURN_ANGLE) < 0.00001, "chosen heading persists to the end")
		check(absf(final.position.x) > absf(mid.position.x) + 500, "path continues away from old main axis")
		var landmark := ForestRoute.point_at(18000, branch)
		var local := ForestRoute.to_camera(landmark, final.position, final.heading)
		check(absf(local.x) < 0.01 and local.y > 0, "destination is geometrically ahead, without screen-space centering")
		for distance in [400.0, 800.0, 1100.0, 1900.0]:
			var on_road := ForestRoute.point_at(distance, branch)
			check(ForestRoute.road_distance(on_road) < 0.01, "road clearance function recognizes its own curve")
	# A common rigid rebase cannot alter the projected relative bearing.
	var camera := Vector2(200, 1500)
	var point := Vector2(2000, 5500)
	var local_before := ForestRoute.to_camera(point, camera, 0.5)
	var origin := Vector2(500, 800)
	var local_after := ForestRoute.to_camera(point - origin, camera - origin, 0.5)
	check(local_before.distance_to(local_after) < 0.001, "world-origin rebase preserves projection")
	if failures.is_empty():
		print("PASS: route continuity, symmetry, persistent heading, destination bearings, clearance, common-origin invariance")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
