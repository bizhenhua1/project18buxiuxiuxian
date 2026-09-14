extends RefCounted
# Immutable world-space route description. Unlike ForestRoute, multiple segments coexist.
var start_s:float
var origin:Vector2
var heading:float
var junction_s:float
var turn_length:float
var end_s:float
var exits:int
var seed_value:int
var theme:String
const TURN_ANGLE:=.5
func _init(start:=0.0,position:=Vector2.ZERO,angle:=0.0,junction:=700.0,turn:=420.0,finish:=2200.0,count:=2,seed_number:=1842,biome:="forest"):
 start_s=start;origin=position;heading=angle;junction_s=junction;turn_length=turn;end_s=finish;exits=count;seed_value=seed_number;theme=biome
func valid_exit(branch:int)->bool:return branch in [-1,1] or (branch==2 and exits==3)
func pose(s:float,branch:int)->Dictionary:
 var offset:=Vector2(0,s-start_s);var angle:=0.0
 if s>junction_s and branch in [-1,1]:
  var travel:=s-junction_s;var radius:=turn_length/TURN_ANGLE
  angle=minf(travel/radius,TURN_ANGLE)
  offset=Vector2(branch*radius*(1-cos(angle)),junction_s-start_s+radius*sin(angle))
  if travel>turn_length:offset+=Vector2(branch*sin(TURN_ANGLE),cos(TURN_ANGLE))*(travel-turn_length)
  angle*=branch
 return {"position":origin+offset.rotated(-heading),"heading":heading+angle}
func point(s:float,branch:int,lateral:=0.0)->Vector2:
 var at:=pose(s,branch)
 return at.position+Vector2(cos(at.heading),-sin(at.heading))*lateral
func successor(branch:int,run_seed:int,index:int):
 assert(valid_exit(branch),"Only an available selected exit can connect a successor")
 var connection:=pose(end_s,branch)
 var rng:=RandomNumberGenerator.new();rng.seed=run_seed+index*104729
 var next_seed:=int(rng.randi())
 var next_exits:=rng.randi_range(2,3)
 # Forks are planned beyond the current visible corridor; event pacing remains separate.
 var length:=rng.randf_range(1900,2400)
 return get_script().new(end_s,connection.position,connection.heading,end_s+length,turn_length,end_s+length+1600,next_exits,next_seed,theme)
func snapshot()->Dictionary:
 return {"start":start_s,"origin":[origin.x,origin.y],"heading":heading,"junction":junction_s,"turn":turn_length,"end":end_s,"exits":exits,"seed":seed_value,"theme":theme}
func lane_distance(world:Vector2)->float:
 var p:=ForestRoute.to_camera(world,origin,heading)
 var junction:=junction_s-start_s
 var best:=p.distance_to(Vector2(0,clampf(p.y,0,junction)))
 if exits==3:best=minf(best,p.distance_to(Vector2(0,clampf(p.y,0,end_s-start_s))))
 var radius:=turn_length/TURN_ANGLE
 for branch in [-1,1]:
  var delta:=p-Vector2(branch*radius,junction)
  var angle:=clampf(atan2(delta.y,-branch*delta.x),0,TURN_ANGLE)
  var arc:=Vector2(branch*radius*(1-cos(angle)),junction+radius*sin(angle))
  best=minf(best,p.distance_to(arc))
  var end:=Vector2(branch*radius*(1-cos(TURN_ANGLE)),junction+radius*sin(TURN_ANGLE))
  var tangent:=Vector2(branch*sin(TURN_ANGLE),cos(TURN_ANGLE))
  var t:=clampf((p-end).dot(tangent),0,maxf(0,end_s-junction_s-turn_length))
  best=minf(best,p.distance_to(end+tangent*t))
 return best
