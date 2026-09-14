class_name CreatureMotion
extends RefCounted
## All profiles fit the same time slot and return to a neutral pose at the end.
static func family(id: String) -> String:
	if id in ["rabid-hound","boar"]: return "charge"
	if id in ["mouse","rat","laoshu"]: return "scurry"
	if id == "bell-walker": return "slither"
	if id in ["dream-moth","bird"]: return "flutter"
	return "bound"
static func sample(id: String, progress: float) -> Dictionary:
	var t := clampf(progress,0,1)
	var kind := family(id)
	var u := smoothstep(.12 if kind == "charge" else 0.0,1.0,t)
	var pulse := sin(PI*t)
	var hop := pulse*10
	var squash := Vector2(1-pulse*.06,1+pulse*.10)
	if kind == "charge":
		hop = sin(PI*u)*3
		squash = Vector2(1+pulse*.13,1-pulse*.10)
	elif kind == "scurry":
		hop = absf(sin(TAU*u))*5
		squash = Vector2(1+pulse*.08,1-pulse*.06)
	elif kind == "slither":
		hop = 0
		squash = Vector2(1+sin(TAU*t)*.08,1-pulse*.06)
	elif kind == "flutter":
		hop = pulse*22
		squash = Vector2(1+sin(TAU*t*2)*pulse*.06,1+pulse*.05)
	return {"travel":u,"altitude":hop,"squash":squash,"grass_strength":1.0 if kind == "charge" else .4 if kind == "flutter" else .65}
