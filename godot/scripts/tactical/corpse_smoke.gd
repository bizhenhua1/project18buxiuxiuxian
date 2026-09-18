extends "res://scripts/world3d/defeat_clear.gd"
var tracked:Dictionary={}
func clear():
 super();tracked.clear()
func retains_corpse(stage,e:Dictionary)->bool:
 var spec:Dictionary=stage.sim.config.enemies[e.type]
 return bool(e.get("revival_pending",false)) or int(e.get("revives_remaining",spec.get("revives",0)))>0
func sync(stage):
 # Defeat already owns a full-scene dissolve. Avoid two opacity writers.
 if stage.phase=="defeat":clear();return
 for i in range(entries.size()-1,-1,-1):
  var entry:Dictionary=entries[i];var e:Dictionary=stage.sim.enemies[entry.enemy_id]
  if e.hp>0 or retains_corpse(stage,e):
   entry.node.set_opacity(1);tracked.erase(e.id);entries.remove_at(i)
 for e in stage.sim.enemies:
  if e.hp>0 or e.get("visual_removed",false) or retains_corpse(stage,e) or tracked.has(e.id) or not stage.pool_ids.has(e.id):continue
  var actor=stage.pool_ids[e.id].actor
  var clip:Dictionary=actor.library.clips.get(actor.clip,{})
  var duration:float=float(clip.get("frames",1)-1)/float(clip.get("fps",25))
  var start:float=float(e.changed)+maxf(float(stage.sim.settings.enemy_corpse_seconds),duration)
  entries.append({"enemy_id":e.id,"node":actor,"actor":true,"origin":actor.position,"delay":start,"alpha":1.0,"height":.4*actor.scale.y})
  tracked[e.id]=true
 age=stage.sim.clock;multimesh.visible_instance_count=0
 super.advance(0,stage.camera)
 for i in range(entries.size()-1,-1,-1):
  var entry:Dictionary=entries[i]
  if age<entry.delay+DURATION:continue
  var e:Dictionary=stage.sim.enemies[entry.enemy_id];e.visual_removed=true
  entry.node.set_opacity(0)
  if stage.pool_ids.has(e.id):
   stage.pool_ids[e.id].id=-1;stage.pool_ids.erase(e.id)
  tracked.erase(e.id);entries.remove_at(i)
