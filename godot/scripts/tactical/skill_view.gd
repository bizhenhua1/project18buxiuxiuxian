extends Node3D
var stage
var views:Array=[]
var assigned:Dictionary={}
func setup(owner_stage):
 stage=owner_stage
 for i in 32:
  var view=preload("res://scripts/tactical/range_view.gd").new();add_child(view);view.setup(stage);views.append(view)
func sync():
 var current:Dictionary={}
 for cue in stage.sim.roles.cues:current[cue.id]=true
 for id in assigned.keys():
  if not current.has(id):assigned[id].sync(Vector3.ZERO,{},false);assigned.erase(id)
 for cue in stage.sim.roles.cues:
  if not assigned.has(cue.id):
   for view in views:
    if not view in assigned.values():assigned[cue.id]=view;break
  if not assigned.has(cue.id):continue
  var spec:Dictionary=cue.spec.duplicate();spec.color=cue.color;spec.wall=float(spec.get("radius",3))>=2.0
  assigned[cue.id].sync(cue.origin,spec,true,false)
