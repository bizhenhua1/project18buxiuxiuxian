extends RefCounted
# Art variant, not a claim of equivalent full-detail rendering. Never mutates
# source assets or the combat simulation. Caps include each emitter's live tail.
static func ordinary(spec:Dictionary,kind:String)->Dictionary:
 var budgets:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/world3d_vfx_budgets.json"))
 var profile:Dictionary=budgets.ordinary[kind]
 assert(spec.layers.size()==profile.caps.size(),"Review the budget when source layers change")
 var result:Dictionary=spec.duplicate(true)
 for i in result.layers.size():
  var layer:Dictionary=result.layers[i]
  assert(layer.name==budgets.layer_names[kind][i],"Review layer roles when source order changes")
  layer.runtime_particle_limit=int(profile.caps[i])
  layer.material.gain=float(layer.material.get("gain",2.0))*float(profile.gain[i])
  for curve in layer.start.startSize:
   for j in curve.size():curve[j]*=float(profile.size[i])
  var scale:float=profile.emission[i]
  for key in ["rate","distance_rate"]:
   for curve in layer[key]:
    for j in curve.size():curve[j]*=scale
  for burst in layer.bursts:
   for curve in burst.count:
    for j in curve.size():curve[j]*=scale
 return result
