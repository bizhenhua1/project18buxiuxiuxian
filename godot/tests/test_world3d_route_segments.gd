extends SceneTree
const SEGMENT=preload("res://scripts/world3d/route_segment.gd")
func _initialize():
 ForestRoute.reset_frame();ForestRoute.configure(false)
 var first=SEGMENT.new()
 for s in [0.0,500.0,700.0,900.0,1120.0,2200.0]:
  for branch in [-1,0,1]:
   var original:=ForestRoute.pose(s,branch);var actual:Dictionary=first.pose(s,branch)
   assert(original.position.distance_to(actual.position)<.001)
   assert(absf(original.heading-actual.heading)<.00001)
 # Compare analytic road distance to an independent densely sampled polyline.
 var rng:=RandomNumberGenerator.new();rng.seed=8142
 var turned=SEGMENT.new(2200,Vector2(300,1800),.5,3000,420,4700,3)
 for trial in 40:
  var query:=Vector2(rng.randf_range(-500,2200),rng.randf_range(1200,4500))
  var brute:=INF
  for branch in [-1,1,2]:
   var previous:Vector2=turned.point(turned.start_s,branch)
   for sample in range(1,2501):
    var next:Vector2=turned.point(turned.start_s+sample,branch)
    var direction:=next-previous
    var t:=clampf((query-previous).dot(direction)/maxf(.000001,direction.length_squared()),0,1)
    brute=minf(brute,query.distance_to(previous+direction*t));previous=next
  assert(absf(brute-turned.lane_distance(query))<.01,"Analytic ground road must match the actual curved path")
 var current=first;var history:Array=[];var worst:=0.0;var step_error:=0.0
 for index in range(1,101):
  var branch:=(-1 if index%2==0 else 1) if current.exits==2 or index%3!=0 else 2
  var before:Dictionary=current.pose(current.end_s,branch)
  var next=current.successor(branch,98713,index)
  var repeated=current.successor(branch,98713,index)
  assert(next.snapshot()==repeated.snapshot(),"Same seed and path must reproduce the planned segment")
  var after:Dictionary=next.pose(next.start_s,0)
  worst=maxf(worst,before.position.distance_to(after.position))
  assert(absf(before.heading-after.heading)<.00001,"Connection must preserve tangent")
  var past:Vector2=current.point(current.end_s-.1,branch)
  var future:Vector2=next.point(next.start_s+.1,0)
  step_error=maxf(step_error,absf(past.distance_to(future)-.2))
  assert(step_error<.06,"Connection error exceeds 3 mm at combat world scale")
  history.append({"segment":current,"sample":current.point(current.end_s,branch),"branch":branch})
  current=next
 for record in history:assert(record.segment.point(record.segment.end_s,record.branch)==record.sample,"Planning future routes must not mutate old geometry")
 assert(worst<.001)
 print("WORLD3D_ROUTE_SEGMENTS_PASS 100 repeated forks, old-route parity, position/tangent continuity, deterministic seeds, immutable history; max step error metres=",step_error/20)
 quit()
