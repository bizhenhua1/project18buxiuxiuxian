extends RefCounted
# Arc-length lookup is built once per stop; playback does not allocate.
const STEPS:=64
var start:Vector2
var control:Vector2
var finish:Vector2
var cumulative:=PackedFloat64Array()
var length:=0.0
var speed:=0.0
var duration:=0.0
var exponent:=1.0
var feasible:=false
func point(t:float)->Vector2:
 return start*(1-t)*(1-t)+control*2*t*(1-t)+finish*t*t
func configure(from:Vector2,to:Vector2,velocity:Vector2,seconds:float):
 start=from;finish=to;speed=velocity.length();duration=seconds
 control=start+velocity.normalized()*start.distance_to(finish)*.5
 cumulative.resize(STEPS+1);cumulative[0]=0;length=0
 var previous:=start
 for i in range(1,STEPS+1):
  var next:=point(float(i)/STEPS);length+=previous.distance_to(next);cumulative[i]=length;previous=next
 var ratio:float=length/maxf(.0001,speed*duration)
 feasible=ratio>=.5 and ratio<.98
 if feasible:exponent=ratio/(1-ratio)
func sample(t:float)->Vector2:
 if t>=1:return finish
 if t<=0:return start
 var distance:float=speed*duration*(t-pow(t,exponent+1)/(exponent+1))
 var lo:=0;var hi:=STEPS
 while hi-lo>1:
  var middle:int=(lo+hi)/2
  if cumulative[middle]<distance:lo=middle
  else:hi=middle
 var part:float=(distance-cumulative[lo])/maxf(.000001,cumulative[hi]-cumulative[lo])
 return point((lo+part)/STEPS)
