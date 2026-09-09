extends RefCounted
## One published snapshot, polled twice a second. No file IO in the layout loop.
const ACTIVE="res://data/traditional_camera_active.json"
const KEYS=["lateral","forward","height","horizon","lens","yaw"]
var active_path:String=ACTIVE
var data:Dictionary={}
var current:Dictionary={}
var clock:=1.0
var fingerprint:=""
var slot_targets:Dictionary={}
var lineup:=""
func poll(dt:float) -> void:
 clock+=dt
 if clock<.5:return
 clock=0
 if not FileAccess.file_exists(active_path):return
 var text:=FileAccess.get_file_as_string(active_path)
 if text==fingerprint:return
 var parser:=JSON.new()
 if parser.parse(text)!=OK:return
 var value=parser.data
 if not valid(value):return
 fingerprint=text;data=value;slot_targets.clear();lineup=""
static func valid(value:Variant) -> bool:
 if not value is Dictionary or value.get("mode","")!="traditional_2_5d" or not value.get("frames") is Dictionary:return false
 for state in ["travel","event","battle"]:
  if not value.frames.get(state) is Dictionary:return false
  for key in KEYS:
   var number=value.frames[state].get(key)
   if not (number is float or number is int) or not is_finite(number):return false
  if value.frames[state].height<=0 or value.frames[state].lens<=0:return false
 if value.has("battle_slots") and not preload("res://scripts/traditional/slot_profiles.gd").valid(value.battle_slots):return false
 if not value.get("battle_units",[]) is Array:return false
 for entry in value.get("battle_units",[]):
  if not entry is Dictionary or not entry.get("card_id") is String:return false
  for key in ["x","depth","height","clearance","occurrence"]:
   var number=entry.get(key)
   if not (number is float or number is int) or not is_finite(number):return false
  if entry.depth<=0 or entry.height<=0:return false
 return true
func advance(app:Control,dt:float) -> void:
 poll(dt)
 if data.is_empty():return
 var target:Dictionary=data.frames.travel.duplicate()
 var mix:float=clampf(app.arena.battle_mix,0,1)
 var destination:String="battle" if app.phase in ["entering","battle","defeat","reviving","clearing"] else "event"
 for key in KEYS:target[key]=lerpf(target[key],data.frames[destination][key],mix)
 if current.is_empty():current=target.duplicate()
 for key in KEYS:current[key]=lerpf(current[key],target[key],1-exp(-7*clampf(dt,0,.1)))
 var heading:float=ForestRoute.pose(app.distance,app.branch).heading if app.phase in ["travel","approach"] else app.heading
 app.camera+=Vector2(cos(heading),-sin(heading))*float(current.lateral)+Vector2(sin(heading),cos(heading))*float(current.forward)
 app.heading=heading+deg_to_rad(current.yaw)
 app.arena.scenery.renderer.runtime_camera=current
func prepare_slots(player:Array,model_uids:Array=[]) -> void:
 var signature:=str(model_uids)
 for unit in player:signature+=str(unit.uid)+":"+str(unit.cardId)+";"
 if signature==lineup:return
 lineup=signature;slot_targets.clear()
 if data.has("battle_slots"):
  for i in range(player.size()):
   var unit:Dictionary=player[i]
   var kind:String="character" if unit.uid in model_uids or unit.get("portrait_kind","")=="person" or unit.cardType=="char" else "prop"
   slot_targets[unit.uid]=preload("res://scripts/traditional/slot_profiles.gd").sample(data.battle_slots,i,player.size(),kind)
  return
 var entries:Array=data.get("battle_units",[])
 if entries.is_empty():return
 var same:bool=entries.size()==player.size()
 if same:
  for i in range(player.size()):
   if player[i].cardId!=entries[i].card_id:same=false;break
 if same:
  for i in range(player.size()):slot_targets[player[i].uid]=entries[i].duplicate()
  return
 # Changed decks follow the saved character bounds / prop arc, not a fixed number of slots.
 for kind in ["character","prop"]:
  var units:Array=player.filter(func(u):return ("character" if u.get("portrait_kind","")=="person" or u.cardType=="char" else "prop")==kind)
  var samples:Array=entries.filter(func(e):return e.get("kind","prop")==kind)
  if samples.is_empty():continue
  samples.sort_custom(func(a,b):return a.x<b.x)
  for i in range(units.size()):
   var t:float=float(i)/maxi(1,units.size()-1) if units.size()>1 else .5
   var f:float=t*(samples.size()-1)
   var a:Dictionary=samples[int(f)];var b:Dictionary=samples[mini(int(f)+1,samples.size()-1)]
   var slot:Dictionary={}
   for key in ["x","depth","height","clearance"]:slot[key]=lerpf(a[key],b[key],f-floor(f))
   if samples.size()==1 and units.size()>1:slot.x+=lerpf(-18,18,t)
   slot_targets[units[i].uid]=slot
func apply_slot(uid:int,slot:Dictionary,dt:float) -> void:
 if not slot_targets.has(uid):return
 var weight:float=1-exp(-7*clampf(dt,0,.1))
 for key in ["x","depth","height","clearance"]:slot[key]=lerpf(slot[key],slot_targets[uid][key],weight)
 slot.right_facing=float(slot.x)>0
