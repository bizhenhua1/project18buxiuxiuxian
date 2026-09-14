extends RefCounted
# Combat Y is already metres; X/Z conversion is owned by the stage.
# Aim and swept collision must use the same scaled body centre.
static func prone(unit:Dictionary)->bool:
 return unit.get("entry","")=="crawl" and unit.get("entry_phase","")=="advance"
static func center_offset(unit:Dictionary)->Vector3:
 return Vector3.UP*float(unit.get("body_scale",1.0))*(.35 if prone(unit) else 1.0)
static func vertical_radius(unit:Dictionary)->float:
 return float(unit.get("body_scale",1.0))*(.3 if prone(unit) else .65)
static func center(unit:Dictionary)->Vector3:
 return unit.pos+center_offset(unit)
static func height(unit:Dictionary)->float:
 # Area volumes include legs down to the grounded root, unlike the torso
 # projectile proxy. Both share the same posture-dependent upper extent.
 return center_offset(unit).y+vertical_radius(unit)
