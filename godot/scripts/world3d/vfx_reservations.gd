extends RefCounted
# Reserve the live-tail maximum, not last frame's occupancy. Core minima may
# exceed the soft budget; a visual budget must never remove a gameplay shot.
var soft_limit:=2000
var reserved:=0
var reduced:=0
var entries:Dictionary={}
func acquire(token,normal:Array,minimum:Array,reduce_order:Array=[])->Array:
 assert(not entries.has(token))
 assert(normal.size()==minimum.size())
 var order:Array=reduce_order if not reduce_order.is_empty() else range(normal.size())
 assert(order.size()==normal.size())
 var seen:Dictionary={}
 for i in order:
  assert(int(i)>=0 and int(i)<normal.size() and not seen.has(int(i)))
  assert(int(minimum[int(i)])>=0 and int(minimum[int(i)])<=int(normal[int(i)]))
  seen[int(i)]=true
 var caps:Array=normal.duplicate()
 var total:=0
 for cap in caps:total+=int(cap)
 var excess:=maxi(0,reserved+total-soft_limit)
 for index in order:
  var i:=int(index)
  var reduction:=mini(excess,int(caps[i])-int(minimum[i]))
  caps[i]=int(caps[i])-reduction;excess-=reduction;total-=reduction
 if caps!=normal:reduced+=1
 entries[token]=total;reserved+=total
 return caps
func release(token):
 reserved-=int(entries.get(token,0));entries.erase(token)
func clear():
 entries.clear();reserved=0
