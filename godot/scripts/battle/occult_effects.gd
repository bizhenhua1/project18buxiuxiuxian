class_name OccultEffects
extends RefCounted
## Analytic ribbons, sigils and trails. Time comes from battle simulation, never flipbooks.
static func color_for(unit: Dictionary) -> Color:
	var id: String = unit.get("cardId","")
	if id in ["silent-medium","scarlet-edict","sealed-book"]: return Color("dc725a")
	if id in ["watchful-clock","faceless-mask"]: return Color("e6c884")
	return Color("91d3d5") if unit.get("side","") == "player" else Color("b19bbd")
static func glow(canvas:CanvasItem,at:Vector2,radius:float,color:Color,energy:float) -> void:
	for i in range(8,0,-1):
		var r:float=radius*i/8.0
		canvas.draw_circle(at,r,Color(color,energy*.035*(1-i/10.0)))
static func sigil(canvas: CanvasItem, center: Vector2, radius: float, color: Color, rotation: float) -> void:
	canvas.draw_arc(center,radius,rotation,rotation+TAU*.86,48,color,1.4,true)
	for i in range(6):
		var angle := rotation+i*TAU/6
		var a := center+Vector2.from_angle(angle)*radius
		var b := center+Vector2.from_angle(angle+TAU/3)*radius
		canvas.draw_line(a,b,Color(color,color.a*.65),1,true)
static func shot(canvas: CanvasItem, shot: Dictionary, start: Vector2, finish: Vector2) -> void:
	# Melee is conveyed by the actor animation; do not draw weapon stamps or trails.
	if shot.get("style", "") == "melee" or shot.from.get("sword_combo", false): return
	var t: float = clampf(shot.age/shot.duration,0,1)
	var color := color_for(shot.from)
	var delta := finish-start
	var normal := delta.normalized().orthogonal()
	var envelope := smoothstep(0,.12,t)*(1-smoothstep(.72,1,t))
	glow(canvas,start.lerp(finish,t),30,color,envelope)
	glow(canvas,start,22,color,envelope*.8)
	var id: String = shot.from.cardId
	if id == "night-warden" or shot.style == "melee":
		var points := PackedVector2Array()
		var back := PackedVector2Array()
		for i in range(20):
			var u := lerpf(maxf(0,t-.28),t,i/19.0)
			var p := start.lerp(finish,u)+normal*sin(u*PI)*55
			var width := sin(i/19.0*PI)*7*envelope
			points.append(p+normal*width)
			back.append(p-normal*width)
		back.reverse()
		points.append_array(back)
		if envelope > .01: canvas.draw_colored_polygon(points,Color(color,envelope*.8))
		canvas.draw_line(finish-normal*25,finish+normal*25,Color(color,envelope*.55),2,true)
	elif shot.style == "beam" or id == "silent-medium":
		var line := PackedVector2Array()
		for i in range(17):
			var u := i/16.0
			line.append(start.lerp(finish,u)+normal*sin(u*TAU*2+t*12)*sin(u*PI)*8)
		canvas.draw_polyline(line,Color(color,envelope*.14),10,true)
		canvas.draw_polyline(line,Color(color,envelope),2,true)
		canvas.draw_line(start,finish,Color("f0e4c7",envelope*.65),.8,true)
	else:
		var p := start.lerp(finish,t)
		for i in range(7):
			var previous := start.lerp(finish,maxf(0,t-i*.018))
			canvas.draw_circle(previous,4*(1-i/8.0),Color(color,(1-i/8.0)*.55))
		canvas.draw_circle(p,3,Color("f6ebd4"))
	sigil(canvas,start,12+sin(t*PI)*7,Color(color,envelope*.65),t*2)
	if t > .55: sigil(canvas,finish,10+18*t,Color(color,envelope),-t*2)
static func impact(canvas: CanvasItem, event: Dictionary, at: Vector2) -> void:
	var t: float = clampf(event.age/.38,0,1)
	if t >= 1: return
	var source: Dictionary = event.get("source", {})
	if event.type == "damage" and (source.get("sword_combo", false) or source.get("atkType", "") == "melee"): return
	var color := Color("94d8ca") if event.type in ["heal","buff","revive"] else Color("ddb98a")
	glow(canvas,at,44+20*t,color,pow(1-t,2)*1.6)
	sigil(canvas,at,8+t*35,Color(color,pow(1-t,2)),t*.7)
