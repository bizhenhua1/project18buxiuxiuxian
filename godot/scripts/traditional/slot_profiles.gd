extends RefCounted
const KEYS=["x","depth","height","clearance"]
static func build(entries:Array) -> Array:
 var result:Array=[]
 for i in range(8):
  var sample:Dictionary=entries[mini(i,entries.size()-1)] if not entries.is_empty() else {"x":lerpf(-40,40,i/7.0),"depth":42,"height":10,"clearance":7,"kind":"prop"}
  var prop:Dictionary={};var character:Dictionary={}
  for key in KEYS:prop[key]=sample[key];character[key]=sample[key]
  if sample.get("kind","prop")=="character":prop.height=10;prop.clearance=7
  else:character.height=38;character.clearance=0
  result.append({"character":character,"prop":prop,"preview_kind":sample.get("kind","prop")})
 return result
static func valid(slots:Variant) -> bool:
 if not slots is Array or slots.size()!=8:return false
 for slot in slots:
  if not slot is Dictionary or slot.get("preview_kind","") not in ["character","prop"]:return false
  for kind in ["character","prop"]:
   if not slot.get(kind) is Dictionary:return false
   for key in KEYS:
    var value=slot[kind].get(key)
    if not (value is float or value is int) or not is_finite(value):return false
   if slot[kind].depth<5 or slot[kind].depth>220 or slot[kind].height<1 or slot[kind].height>120 or absf(slot[kind].x)>120 or slot[kind].clearance<0 or slot[kind].clearance>100:return false
 return true
static func sample(slots:Array,index:int,count:int,kind:String) -> Dictionary:
 var t:float=float(index)*7/maxi(1,count-1) if count>1 else 3.5
 var a:Dictionary=slots[int(t)][kind];var b:Dictionary=slots[mini(int(t)+1,7)][kind]
 var value:Dictionary={}
 for key in KEYS:value[key]=lerpf(a[key],b[key],t-floor(t))
 return value
