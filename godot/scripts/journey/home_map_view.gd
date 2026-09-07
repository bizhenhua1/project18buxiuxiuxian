class_name HomeMapView
extends IslandView3D
signal cell_selected(cell: Vector2i)
func _process(dt: float) -> void:
	if not model: return
	var requested_zoom := model.zoom
	model.zoom *= minf(1.0,minf(size.x/850.0,size.y/700.0))
	super(dt)
	model.zoom = requested_zoom
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p := pick(event.position)
		if model.lookup.has(p): cell_selected.emit(p)
		accept_event()
		return
	super(event)
