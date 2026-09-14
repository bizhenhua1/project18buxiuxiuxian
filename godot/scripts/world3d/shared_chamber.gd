extends RefCounted
# Experimental native layout repair: one intact portal for the common entrance,
# instead of three squeezed portals at the same cross-section. Generation only.
static func apply(sprites:Array,route)->Array:
 if route==null or route.exits!=3:return sprites
 var groups:Dictionary={}
 for sprite in sprites:
  if not sprite.get("shell",false) or sprite.get("route_branch",0)==0 or sprite.has("plane_heading"):continue
  var theme:String=str(sprite.region.space.key)
  if theme not in ["whale","swamp"] or float(sprite.w)>=200.0:continue
  var key:=theme+":"+str(sprite.route_s)
  if not groups.has(key):groups[key]=[]
  groups[key].append(sprite)
 var replacements:Dictionary={};var omitted:Dictionary={}
 for group in groups.values():
  var branches:Dictionary={}
  for sprite in group:branches[int(sprite.route_branch)]=true
  if not branches.has(-1) or not branches.has(1) or not branches.has(2):continue
  var first:Dictionary=group[0]
  var portal:=first.duplicate()
  var config:Dictionary=preload("res://scripts/spaces/biome_catalog.gd").CONFIG[str(first.region.space.key)]
  portal.w=config.width;portal.h=config.height
  portal.position=route.point(float(first.route_s),2)
  portal.route_branch=2;portal.plane_heading=route.heading
  portal.native_shared_chamber=true
  replacements[int(first.id)]=portal
  for sprite in group:omitted[int(sprite.id)]=true
 var result:Array=[]
 for sprite in sprites:
  var id:int=int(sprite.get("id",-1))
  if replacements.has(id):result.append(replacements[id])
  elif not omitted.has(id):result.append(sprite)
 return result
