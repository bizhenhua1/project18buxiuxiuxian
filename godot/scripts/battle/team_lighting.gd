extends RefCounted
const GAME=preload("res://scripts/battle/character_ink_material.gd")
static func defaults() -> Dictionary:
 var base={"x":1.2,"y":1.6,"z":.3,"energy":2.2,"range":6.0,"ambient":.28,"rim":.35,"color":"e5dfc9ff","road_x":2.0,"road_y":16.0,"road_z":40.0,"road_energy":1.0,"road_radius":82.0,"road_color":"ffffffff"}
 var battle=base.duplicate();battle.road_x=-10.0;battle.road_z=56.0
 return {"travel":base,"battle":battle}
static func profiles(override:Dictionary={}) -> Dictionary:
 var result=defaults()
 var data=override if not override.is_empty() else GAME.settings().get("team_lights",{})
 for state in result:result[state].merge(data.get(state,{}),true)
 return result
static func sample(blend:float,override:Dictionary={}) -> Dictionary:
 var data=profiles(override);var result={}
 for key in data.travel:
  result[key]=Color(data.travel[key]).lerp(Color(data.battle[key]),blend) if key in ["color","road_color"] else lerpf(float(data.travel[key]),float(data.battle[key]),blend)
 return result
