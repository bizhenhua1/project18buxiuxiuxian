extends Control
var art: Texture2D
var caption := ""
var proximity := 0.0
var flight := false
var flight_t := 0.0
var start_rect := Rect2()
var end_rect := Rect2()
var companions: Array[Dictionary] = []
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	if not art or not flight: return
	draw_texture_rect(art,sample_rect(),false,Color(1,1,1,1-smoothstep(.60,.72,flight_t)))
	for entry in companions:
		var t := clampf((flight_t-entry.delay)/(1-entry.delay),0,1)
		draw_texture_rect(entry.art,sample_between(entry.start_rect,entry.end_rect,t),false,Color(1,1,1,1-smoothstep(.60,.72,t)))
func sample_rect() -> Rect2:
	return sample_between(start_rect,end_rect,flight_t)
func sample_between(from: Rect2, to: Rect2, progress: float) -> Rect2:
	var t := smoothstep(0.0,.72,progress)
	var start := from.get_center()
	var finish := to.get_center()
	# A single quadratic path: upward launch, direct arrival, no intermediate waypoint.
	var control := Vector2(start.x,finish.y)
	var center := start.lerp(control,t).lerp(control.lerp(finish,t),t)
	var dimensions := from.size.lerp(to.size,t)
	return Rect2(center-dimensions/2,dimensions)
