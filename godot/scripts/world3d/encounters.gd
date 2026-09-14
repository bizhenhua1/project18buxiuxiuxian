extends RefCounted
var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/local_encounters.json"))
var sequence:Array=[]
var cursor:=0
var arrived:=false
var resolved:=false
var stones:=0
var reward_bonus:=0
var zone_reward:=2
var tier:=0
var notice:=""
func _init():sequence=catalog.short_battle.events.duplicate(true)
func current()->Dictionary:return sequence[cursor%sequence.size()]
func choose_branch(direction:int):
 sequence=catalog.fork["left" if direction==-1 else "right"].duplicate(true)
 cursor=0;arrived=false;resolved=false
func depart()->bool:
 if arrived and not resolved:return false
 if resolved:cursor+=1
 arrived=false;resolved=false
 return true
func arrive():arrived=true
func win()->bool:
 if not arrived or resolved or current().kind!="battle":return false
 stones+=int(current().get("reward",0))+tier;resolved=true
 notice="战斗胜利 · 收获已收入本次测试行囊"
 return true
func choose(option:String)->bool:
 if not arrived or resolved or current().kind!="social":return false
 var merchant:bool=current().get("event","")=="merchant"
 if option=="fortune":
  var cost:=4 if merchant else 0
  if stones<cost:return false
  stones-=cost;reward_bonus+=3 if merchant else 2
  notice="获得寻宝线索 · 后续补给收获增加"
 elif option=="supplies":
  stones+=int(zone_reward/2)+reward_bonus;notice="带走旅途补给 · 已收入本次测试行囊"
 else:return false
 resolved=true
 return true
