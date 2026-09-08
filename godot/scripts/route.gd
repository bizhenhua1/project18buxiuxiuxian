class_name ForestRoute
extends RefCounted
## Arc-length paths in a persistent XZ world. No merge back to the old axis.
static var JUNCTION := 700.0
static var TURN_LENGTH := 420.0
const TURN_ANGLE := 0.50
static var PAUSE_AT := 460.0
const END_AT := 3650.0
static var APPROACH_SECONDS := 1.8

static func configure(compact:bool) -> void:
	JUNCTION=120.0 if compact else 700.0
	TURN_LENGTH=120.0 if compact else 420.0
	PAUSE_AT=100.0 if compact else 460.0
	APPROACH_SECONDS=.7 if compact else 1.8

static func pose(distance: float, branch: int) -> Dictionary:
	if branch == 2: branch = 0 # The third exit continues along the trunk axis.
	if distance <= JUNCTION or branch == 0:
		return {"position": Vector2(0.0, distance), "heading": 0.0}
	var travel := distance - JUNCTION
	# Integrate a linearly increasing heading: an exact circular transition.
	var radius := TURN_LENGTH / TURN_ANGLE
	var angle := minf(travel / radius, TURN_ANGLE)
	var p := Vector2(branch * radius * (1.0 - cos(angle)), JUNCTION + radius * sin(angle))
	if travel > TURN_LENGTH:
		p += Vector2(branch * sin(TURN_ANGLE), cos(TURN_ANGLE)) * (travel - TURN_LENGTH)
	return {"position": p, "heading": branch * angle}

static func point_at(distance: float, branch: int, offset: float = 0.0) -> Vector2:
	var p := pose(distance, branch)
	var h: float = p.heading
	return p.position + Vector2(cos(h), -sin(h)) * offset

static func to_camera(point: Vector2, camera: Vector2, heading: float) -> Vector2:
	var d := point - camera
	return Vector2(d.x * cos(heading) - d.y * sin(heading), d.x * sin(heading) + d.y * cos(heading))

static func road_distance(point: Vector2, three_way := false) -> float:
	var closest := absf(point.x) if point.y <= JUNCTION else INF
	if three_way: closest = absf(point.x)
	for branch in [-1, 1]:
		var radius := TURN_LENGTH / TURN_ANGLE
		var center := Vector2(branch * radius, JUNCTION)
		var d := point - center
		var angle := atan2(d.y, -branch * d.x)
		if angle >= 0.0 and angle <= TURN_ANGLE:
			closest = minf(closest, absf(d.length() - radius))
		var end := point_at(JUNCTION + TURN_LENGTH, branch)
		var tangent := Vector2(branch * sin(TURN_ANGLE), cos(TURN_ANGLE))
		var progress := maxf(0.0, (point - end).dot(tangent))
		closest = minf(closest, point.distance_to(end + tangent * progress))
		closest = minf(closest, point.distance_to(Vector2(0, JUNCTION)))
	return closest
