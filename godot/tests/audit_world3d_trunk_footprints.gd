extends SceneTree
# Conservative footprint candidates, not pixel intersections. No scene mutations.
func _initialize():call_deferred("run")
func overlap(a:Dictionary,b:Dictionary)->float:
 var minimum:=INF
 for axis in [a.right,a.forward,b.right,b.forward]:
  var ar:float=absf(axis.dot(a.right))*a.radius+absf(axis.dot(a.forward))*10.5
  var br:float=absf(axis.dot(b.right))*b.radius+absf(axis.dot(b.forward))*10.5
  var penetration:float=ar+br-absf(axis.dot(b.center-a.center))
  if penetration<=0:return 0
  minimum=minf(minimum,penetration)
 return minimum
func run():
 var app=load("res://scenes/world3d_presentation.tscn").instantiate();root.add_child(app)
 while not app.stage or not app.stage.ready_stage:await process_frame
 app.stage.set_process(false)
 var entries:Array=[];var buckets:Dictionary={};var tested:Dictionary={};var hits:Array=[]
 for sprite in app.stage.world.sprites:
  if float(sprite.get("trunk_radius",0.0))<=0:continue
  var angle:float=float(sprite.get("plane_heading",ForestRoute.pose(sprite.route_s,sprite.route_branch).heading))
  var right:=Vector2(cos(angle),-sin(angle));var forward:=Vector2(sin(angle),cos(angle))
  var center:Vector2=sprite.position+forward*7.5
  var entry:Dictionary={"id":entries.size(),"center":center,"right":right,"forward":forward,"radius":float(sprite.trunk_radius),"position":sprite.position,"route_s":sprite.route_s,"branch":sprite.route_branch}
  var extent:Vector2=right.abs()*entry.radius+forward.abs()*10.5
  var lo:Vector2i=((center-extent)/64).floor();var hi:Vector2i=((center+extent)/64).floor()
  for x in range(lo.x,hi.x+1):
   for y in range(lo.y,hi.y+1):
    var cell:=Vector2i(x,y)
    for other in buckets.get(cell,[]):
     var key:=Vector2i(other.id,entry.id)
     if tested.has(key):continue
     tested[key]=true
     var penetration:=overlap(entry,other)
     if penetration>0:hits.append({"a":other.id,"b":entry.id,"overlap_metres":penetration/20,"a_route":[other.route_s,other.branch],"b_route":[entry.route_s,entry.branch],"a_world":[other.position.x/20,-other.position.y/20],"b_world":[entry.position.x/20,-entry.position.y/20]})
    if not buckets.has(cell):buckets[cell]=[]
    buckets[cell].append(entry)
  entries.append(entry)
 hits.sort_custom(func(a,b):return a.overlap_metres>b.overlap_metres)
 assert(not entries.is_empty())
 if "--verify" in OS.get_cmdline_user_args():
  var exact:Dictionary={}
  for a in entries.size():
   for b in range(a+1,entries.size()):
    var penetration:=overlap(entries[a],entries[b])
    if penetration>0:exact[Vector2i(a,b)]=penetration/20
  assert(exact.size()==hits.size(),"Spatial buckets missed or duplicated footprint collisions")
  for hit in hits:assert(is_equal_approx(exact[Vector2i(hit.a,hit.b)],hit.overlap_metres))
  print("TRUNK_FOOTPRINT_EXHAUSTIVE_MATCH ",exact.size())
 var report:Dictionary={"theme":app.stage.theme_key,"trunks":entries.size(),"pair_checks":tested.size(),"all_pairs":entries.size()*(entries.size()-1)/2,"candidates":hits,"scope":"Initial route chunks, conservative trunk width and legacy 21-unit ground exclusion depth, not opaque silhouette collisions. Candidate only; art and placement unchanged."}
 FileAccess.open("res://../tempassets/work/world3d-trunk-footprints.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("TRUNK_FOOTPRINT_AUDIT trunks=",entries.size()," checks=",tested.size()," all_pairs=",report.all_pairs," candidates=",hits.size())
 for i in mini(3,hits.size()):print(JSON.stringify(hits[i]))
 quit()
