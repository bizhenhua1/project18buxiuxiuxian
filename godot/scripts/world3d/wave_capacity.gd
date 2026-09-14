extends RefCounted
# Corpses retain their model until the encounter ends, so total allocations
# per kind matter even when the live-enemy cap is much smaller.
static func validate(config:Dictionary,pool:Array,stress:bool)->String:
 for key in ["total","cap","interval"]:
  var value:Variant=config.get(key)
  if not (value is int or value is float):return "数量与间隔必须是有效数值"
 if not config.get("enemies",[]) is Array:return "敌人类型配置无效"
 var total:float=50.0 if stress else float(config.get("total",0))
 var cap:float=float(config.get("cap",0))
 var interval:float=float(config.get("interval",0))
 if not is_finite(total) or total<1 or total!=floor(total):return "敌人总数必须为正整数"
 if total>pool.size():return "本场敌人总数超过已加载模型容量"
 if not is_finite(cap) or cap<1 or cap!=floor(cap):return "同时来敌上限必须为正整数"
 if not is_finite(interval) or interval<=0:return "来敌间隔必须大于零"
 var cycle:Variant=config.get("spawn_cycle",[])
 if not cycle is Array or cycle.is_empty():return "缺少来敌类型顺序"
 var available:Dictionary={}
 for slot in pool:available[slot.kind]=int(available.get(slot.kind,0))+1
 var required:Dictionary={}
 for i in int(total):
  var value:Variant=cycle[i%cycle.size()]
  if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floor(float(value)):return "来敌类型无效"
  var kind:=int(value)
  if kind<0 or kind>=config.get("enemies",[]).size():return "来敌类型不存在"
  required[kind]=int(required.get(kind,0))+1
  if required[kind]>int(available.get(kind,0)):return "第 %d 类敌人的数量超过已加载模型容量"%(kind+1)
 return ""
