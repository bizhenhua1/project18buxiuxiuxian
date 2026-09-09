extends RefCounted
var frames:Dictionary
func _init() -> void:
 frames=JSON.parse_string(FileAccess.get_file_as_string("res://data/native3d_camera_presets/我的镜头方案.json")).frames
func point(value:Array) -> Vector3:return Vector3(value[0],value[1],value[2])
func camera_frame(key:String,origin:Vector3,f:Vector3) -> Dictionary:
 var c:Dictionary=frames[key].camera
 var r:=f.cross(Vector3.UP).normalized()
 var p:=origin+r*float(c.position[0])+Vector3.UP*float(c.position[1])-f*float(c.position[2])
 var dir:=f.rotated(Vector3.UP,-deg_to_rad(float(c.yaw)))
 dir=dir*cos(deg_to_rad(float(c.pitch)))+Vector3.UP*sin(deg_to_rad(float(c.pitch)))
 return {"position":p,"look":p+dir*10,"fov":float(c.fov)}
func player_slots(count:int,hero_right:bool,characters:int=2) -> Array:
 var a:Dictionary=frames.battle.units[0];var b:Dictionary=frames.battle.units[1]
 var left:=minf(a.position[0],b.position[0]);var right:=maxf(a.position[0],b.position[0])
 var result:Array=[]
 var character_x:Array[float]=[]
 for i in range(characters):
  var t:float=float(i)/maxi(1,characters-1) if characters>1 else .5
  var pos:=point(a.position).lerp(point(b.position),t)
  result.append(pos);character_x.append(pos.x)
 if hero_right and characters>1:
  var swap=result[0];result[0]=result[characters-1];result[characters-1]=swap
 var candidates:Array[float]=[]
 for i in range(401):
  var x:=lerpf(left-.6,right+.6,i/400.0)
  var occupied:=false
  for cx in character_x:
   if absf(x-cx)<.38:occupied=true
  if not occupied:candidates.append(x)
 if candidates.is_empty():candidates=[left,right]
 var height:float=(frames.battle.units[2].position[1]+frames.battle.units[3].position[1])*.5
 var z:float=(frames.battle.units[2].position[2]+frames.battle.units[3].position[2])*.5
 for i in range(maxi(0,count-characters)):
  var x:float=candidates[mini(candidates.size()-1,int((i+.5)/maxi(1,count-characters)*candidates.size()))]
  var arc:=absf((x-(left+right)*.5)/maxf(.1,(right-left)*.5))
  result.append(Vector3(x,height,z-.4*arc*arc))
 return result
func prop_scale() -> float:return (float(frames.battle.units[2].scale)+float(frames.battle.units[3].scale))*.5

func enemy_slots(count:int) -> Array:
 var source:Array=frames.battle.units.slice(4)
 var result:Array=[]
 for i in range(count):
  var t:float=float(i)/maxi(1,count-1)*(source.size()-1)
  var a:=int(t);var b:=mini(a+1,source.size()-1)
  result.append(point(source[a].position).lerp(point(source[b].position),t-a))
 return result
