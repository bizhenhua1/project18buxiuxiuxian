extends RefCounted
var settings:Dictionary=preload("res://scripts/spaces/vfx_preview.gd").LIGHT_DEFAULTS.duplicate()
var bursts:Array=[]
var shared_flights:=false
var flight_groups:Array=[]
var merge_distance:=.75
var handoff_seconds:=.12
var burst_limit:=32
var burst_merge_distance:=.75
var burst_merge_window:=.05
func clear():
 bursts.clear();flight_groups.clear()
func grouped_flights(dt:float,flights:Array)->Array:
 # Four persistent spatial groups: O(4*N), no pairwise projectile comparisons.
 # A departed group fades where it was, rather than travelling to a new projectile.
 for group in flight_groups:
  group.sum=Vector3.ZERO;group.count=0
 for point in flights:
  var best=-1;var distance_sq:float=merge_distance*merge_distance
  for i in flight_groups.size():
   var d:float=flight_groups[i].position.distance_squared_to(point)
   if d<=distance_sq:best=i;distance_sq=d
  if best<0:
   if flight_groups.size()>=4:continue
   flight_groups.append({"position":point,"sum":Vector3.ZERO,"count":0,"weight":0.0})
   best=flight_groups.size()-1
  flight_groups[best].sum+=point;flight_groups[best].count+=1
 var result:Array=[]
 for group in flight_groups:
  var occupied:bool=group.count>0
  group.weight=move_toward(float(group.weight),1.0 if occupied else 0.0,maxf(0,dt)/maxf(.001,handoff_seconds))
  if occupied:group.position=group.sum/float(group.count)
  if group.weight>0:
   result.append(light(group.position,settings.missile_light_energy*group.weight,settings.missile_light_radius,Color(settings.missile_light_color)))
 flight_groups=flight_groups.filter(func(group):return group.count>0 or group.weight>0)
 return result
func load_profile(file:String):
 settings.missile_light_enabled=true
 if FileAccess.file_exists("user://projectile-light-profiles.json"):
  var saved=JSON.parse_string(FileAccess.get_file_as_string("user://projectile-light-profiles.json"))
  if saved is Dictionary:settings.merge(saved.get(file,{}),true)
func impact(world_position:Vector3):
 if not settings.missile_burst_enabled:return
 if shared_flights:
  # Merge illumination only. Keep its original anchor and age: repeated hits
  # must not drag the flash or keep it alive indefinitely.
  for burst in bursts:
   if burst.age<=burst_merge_window and burst.position.distance_squared_to(world_position)<=burst_merge_distance*burst_merge_distance:return
  if bursts.size()>=burst_limit:return
 bursts.append({"position":world_position,"age":0.0})
func light(p:Vector3,energy:float,radius:float,color:Color)->Dictionary:
 return {"position":Vector3(p.x,p.y,-p.z)*20,"energy":energy,"radius":radius,"color":color}
func advance(dt:float,flights:Array)->Array:
 var result:Array=[]
 var duration:float=maxf(.01,settings.missile_burst_duration)
 for burst in bursts:
  burst.age+=dt
  if settings.missile_burst_enabled and burst.age<duration and result.size()<4:
   var peak:=clampf(float(settings.missile_burst_rise),.001,duration*.8)
   var rise:=smoothstep(0,peak,burst.age);var fade:=1-smoothstep(peak,duration,burst.age)
   result.append(light(burst.position,lerpf(settings.missile_light_energy,settings.missile_burst_energy,rise)*fade,lerpf(settings.missile_light_radius,settings.missile_burst_radius,rise),Color(settings.missile_light_color).lerp(Color(settings.missile_burst_color),rise)))
 bursts=bursts.filter(func(b):return b.age<duration)
 if settings.missile_light_enabled:
  if shared_flights:
   var grouped:=grouped_flights(dt,flights)
   for i in mini(grouped.size(),4-result.size()):result.append(grouped[i])
  else:
   for i in mini(flights.size(),4-result.size()):result.append(light(flights[i],settings.missile_light_energy,settings.missile_light_radius,Color(settings.missile_light_color)))
 else:flight_groups.clear()
 var total:=0.0
 for entry in result:total+=entry.energy
 var budget:float=maxf(settings.missile_light_energy,settings.missile_burst_energy)
 if total>budget and total>0:
  for entry in result:entry.energy*=budget/total
 return result
