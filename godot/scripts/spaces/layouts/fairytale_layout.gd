extends RefCounted
## Whole independently anchored objects. The central walking belt is never populated.
func populate(world,region:RouteRegion)->void:
 var key:=str(region.space.key)
 var spec:=FairytaleCatalog.entry(key)
 var rng:=RandomNumberGenerator.new();rng.seed=world.seed_value+hash(key)+region.branch*91
 var structure:Texture2D=load(FairytaleCatalog.asset(key,"structure.png"))
 var props:Array[Texture2D]=[]
 for i in 4:props.append(load(FairytaleCatalog.asset(key,"prop-%d.png"%i)))
 var indoors:bool=spec.space in ["interior","stage","clock","cave"]
 var gap:=125.0 if indoors else 170.0
 var height_range:=Vector2(270,320) if indoors else Vector2(290,360)
 match key:
  "piper_bridge":height_range=Vector2(100,115);gap=145
  "alice_tea":height_range=Vector2(175,195);gap=190
  "snow_house":height_range=Vector2(230,255);gap=170
  "puppet_theatre":height_range=Vector2(330,355);gap=230
  "cinder_clock":height_range=Vector2(410,450);gap=190
  "cinder_garden":height_range=Vector2(190,215);gap=220
 var s:float=region.start+45
 if not world.plan.straight and region.branch!=0:s=ForestRoute.JUNCTION+440.0
 while s<region.end:
  for side in [-1,1]:
   var at:=s+rng.randf_range(-24,24)
   var h:=rng.randf_range(height_range.x,height_range.y)
   var w:=h*structure.get_width()/float(structure.get_height())
   var lateral:float=side*(105+w*.45)
   put(world,region,at,lateral,structure,h,side>0)
  s+=gap*rng.randf_range(.93,1.10)
 s=region.start+30
 while s<region.end:
  s+=rng.randf_range(60,105)
  for side in [-1,1]:
   var i:=rng.randi_range(0,3)
   var h:=rng.randf_range(19,37)
   put(world,region,s+rng.randf_range(-20,20),side*rng.randf_range(99,165),props[i],h,side>0)
func put(world,region:RouteRegion,s:float,x:float,tex:Texture2D,h:float,flip:bool)->void:
 var point:=ForestRoute.point_at(s,region.branch,x)
 var w:=h*tex.get_width()/float(tex.get_height())
 var clearance:float=absf(point.x) if world.plan.straight else ForestRoute.road_distance(point,world.plan.exits==3)
 if clearance<76+w*.40:return
 world.sprites.append({"position":point,"texture":tex,"w":w,"h":h,"flip":flip,"kind":0,"id":world.sprites.size(),"region":region,"route_s":s,"route_branch":region.branch,"altitude":0.0,"motion":"static","biome_prop":true,"ground_anchor":Vector2(.5,1-8.0/tex.get_height())})
