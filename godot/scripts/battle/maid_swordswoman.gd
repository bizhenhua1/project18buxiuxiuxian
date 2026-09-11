extends "res://scripts/battle/enemy_actor.gd"
const GRIP=preload("res://scripts/spaces/weapon_preview.gd")
var combo:=0
var attack_rate:=1.0
var combo_clips:Array=[]
var combo_data:Array=[]
var current_unit:Dictionary={}
var sword:Node3D
func _ready():
 super()
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
 retarget.configure(rig,catalog.bones)
 for i in range(1,5):
  var id:String="5_ARPG_Warrior_Anim_rig_Attack_Combo"+str(i)
  for entry in catalog.clips:
   if entry.id==id:
    combo_clips.append(entry);combo_data.append(FileAccess.get_file_as_bytes(entry.file).to_float32_array());break
 var bone:int=rig.find_bone("手首.R")
 if bone>=0:
  var attachment=BoneAttachment3D.new();rig.add_child(attachment);attachment.bone_idx=bone
  sword=load("res://assets/weapons/kaykit/sword_B.gltf").instantiate();attachment.add_child(sword)
  var weapons:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/catalog.json"))
  for item in weapons:
   if item.get("file","")=="sword_B.gltf":
    var grip:Transform3D=GRIP.palm_mount(rig,bone,0)
    sword.transform=Transform3D(grip.basis*float(item.scale)/rig.global_transform.basis.get_scale().x,grip.origin)
    break
 play("idle")
func bind_unit(unit:Dictionary):
 if uid!=int(unit.uid) or (dead and float(unit.hp)>0):combo=0
 current_unit=unit;unit.atkType="melee";unit.weapon_kind="sword";unit.sword_combo=true
 super(unit)
func trigger(kind:String):
 if kind in ["death","revive"]:combo=0;super(kind);return
 if dead:return
 if kind=="damage" and state=="attack":return
 if kind=="shot":
  clips.attack=combo_clips[combo];clip_cache.attack=combo_data[combo]
  current_unit.combo_stage=combo+1
  var duration:float=(clips.attack.frames-1)/clips.attack.fps
  attack_rate=maxf(1.0,duration/maxf(.25,float(current_unit.get("cd",1500))*.001))
  current_unit.combo_duration=duration/attack_rate
  combo=(combo+1)%4;play("attack")
 else:super(kind)
func advance(dt:float,phase:String,paused:bool,speed:float,enabled:bool,entrance:float=-1.0):
 if phase in ["clearing","travel","defeat"]:combo=0
 super(dt,phase,paused,speed*(attack_rate if state=="attack" else 1.0),enabled,entrance)
