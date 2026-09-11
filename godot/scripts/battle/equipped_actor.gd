extends "res://scripts/battle/selected_hero_actor.gd"
const LOADOUT=preload("res://scripts/equipment/loadouts.gd")
const GRIP=preload("res://scripts/spaces/weapon_preview.gd")
var model_key:=""
var equipment_revision:=-1
var attachments:Array=[]
var attacks:Array=[]
var attack_buffers:Array=[]
var combo:=0
var attack_rate:=1.0
var current_unit:Dictionary={}
var profile:=""
var base_clips:Dictionary
func _ready():
 super();base_clips=clips.duplicate(true)
 refresh_equipment()
func refresh_equipment():
 equipment_revision=LOADOUT.revision
 for a in attachments:a.get_parent().remove_child(a);a.queue_free()
 attachments.clear()
 var data:Dictionary=LOADOUT.get_loadout(model_key);profile=LOADOUT.profile(data)
 for side in ["right","left"]:
  var file:String=data[side]
  if file.is_empty() or (side=="left" and LOADOUT.two_handed(file)):continue
  var bone:int=rig.find_bone("手首.R" if side=="right" else "手首.L")
  if bone<0:continue
  var attach=BoneAttachment3D.new();rig.add_child(attach);attach.bone_idx=bone;attachments.append(attach)
  var mesh=load("res://assets/weapons/kaykit/"+file).instantiate();attach.add_child(mesh)
  var grip:Transform3D=GRIP.palm_mount(rig,bone,0 if side=="right" else 1)
  var rotation:=Basis.IDENTITY
  if LOADOUT.item(file).kind=="shield":rotation=Basis(Vector3.BACK,PI*.5)*Basis(Vector3.UP,PI)
  if file=="axe_C.gltf":rotation=Basis(Vector3.UP,PI)
  mesh.transform=Transform3D(grip.basis*rotation*float(LOADOUT.item(file).scale)/rig.global_transform.basis.get_scale().x,grip.origin)
 var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
 var ids:Array=[]
 if profile=="mage" or profile=="unarmed":ids=["9_EM_Attack01","9_EM_Attack02","9_EM_RangeAttack"]
 elif profile=="spear":ids=["8_Anim_Combo1_1","8_Anim_Combo1_2","8_Anim_Combo1_3"]
 else:
  for i in range(1,5):ids.append("5_ARPG_Warrior_Anim_rig_Attack_Combo"+str(i) if profile=="warrior" else "4_Anim_ARPGSamurai_Attack_Combo"+str(i))
 var idle_id:String="9_EM_Idle" if profile in ["mage","unarmed"] else "8_Anim_Fight_Idle" if profile=="spear" else "7_Shield_Idle_Seq" if profile=="sword_shield" else "5_ARPG_Warrior_Anim_rig_Idle1" if profile=="warrior" else "4_Anim_ARPGSamurai_Idle1"
 attacks.clear();attack_buffers.clear();clips=base_clips.duplicate(true);clip_cache.clear()
 for id in ids:
  for c in catalog.clips:
   if c.id==id:attacks.append(c);attack_buffers.append(FileAccess.get_file_as_bytes(c.file).to_float32_array());break
 for c in catalog.clips:
  if c.id==idle_id:clips.idle=c;break
 retarget.configure(rig,catalog.bones);combo=0
 play("death" if dead else "idle")
func bind_unit(unit:Dictionary):
 if uid!=int(unit.uid) or (dead and float(unit.hp)>0):combo=0
 current_unit=unit
 unit.atkType="ranged" if profile in ["mage","unarmed"] else "melee"
 unit.weapon_kind="staff" if profile=="mage" else "spear" if profile=="spear" else "hammer" if profile=="warrior" else "sword"
 unit.sword_combo=profile not in ["mage","unarmed"]
 super(unit)
func trigger(kind:String):
 if kind in ["death","revive"]:combo=0;super(kind);return
 if dead:return
 if kind=="damage" and state=="attack":return
 if kind=="shot":
  clips.attack=attacks[combo];clip_cache.attack=attack_buffers[combo]
  current_unit.combo_stage=combo+1
  var duration:float=(clips.attack.frames-1)/clips.attack.fps
  attack_rate=maxf(1.0,duration/maxf(.25,float(current_unit.get("cd",1500))*.001))
  current_unit.combo_duration=duration/attack_rate
  combo=(combo+1)%attacks.size();play("attack")
 else:super(kind)
func advance(dt:float,phase:String,paused:bool,speed:float,enabled:bool,entrance:float=-1.0):
 if equipment_revision!=LOADOUT.revision:refresh_equipment()
 if phase in ["clearing","travel","defeat"]:combo=0
 super(dt,phase,paused,speed*(attack_rate if state=="attack" else 1.0),enabled,entrance)
