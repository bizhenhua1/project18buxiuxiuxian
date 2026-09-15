extends "res://scripts/world3d/actor.gd"
const LOADOUT=preload("res://scripts/equipment/loadouts.gd")
const GRIP=preload("res://scripts/spaces/weapon_preview.gd")
var attachments:Array=[]
var attacks:Array=[]
var attack_buffers:Array=[]
var attack_seconds:=1.0
var combo:=0
var profile:=""
var applied_loadout:Dictionary={}
var hand_pose:Dictionary={}
var atmosphere_service
var locomotion_blend_enabled:=true
var locomotion_blend_age:=1.0
const LOCOMOTION_BLEND_SECONDS:=.16
var locomotion_from_positions:Array[Vector3]=[]
var locomotion_from_rotations:Array[Quaternion]=[]
func set_opacity(value:float)->void:
 super(value)
 for attachment in attachments:attachment.visible=value>0.0
 if portrait_presenter!=null:portrait_presenter.sync_opacity()
func refresh_equipment_if_changed()->bool:
 var saved:Dictionary=LOADOUT.get_loadout(model_key)
 if saved==applied_loadout:return false
 refresh_equipment(saved)
 return true
func refresh_equipment(data:Dictionary={}):
 if data.is_empty():data=LOADOUT.get_loadout(model_key)
 locomotion_blend_age=1.0
 if atmosphere_service!=null:atmosphere_service.remove_weapons(self)
 var restore_projection:bool=portrait_presenter!=null and portrait_presenter.enabled
 if portrait_presenter!=null:
  portrait_presenter.set_enabled(false);portrait_presenter.weapons.clear();portrait_presenter.margins.clear()
 for a in attachments:a.get_parent().remove_child(a);a.queue_free()
 attachments.clear()
 applied_loadout=data.duplicate(true);profile=LOADOUT.profile(data)
 hand_pose.clear()
 for side in ["right","left"]:
  var holding:bool=not str(data[side]).is_empty() or (side=="left" and not str(data.right).is_empty() and LOADOUT.two_handed(data.right))
  # Empty hands belong entirely to the source animation. A grip is an
  # equipment-specific override, never a replacement for unarmed locomotion.
  if holding:hand_pose.merge(preload("res://scripts/world3d/hand_grip.gd").build(rig,0 if side=="right" else 1))
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
 attacks.clear();attack_buffers.clear();cache.clear()
 for id in ids:
  for c in catalog.clips:
   if c.id==id:attacks.append(c);attack_buffers.append(FileAccess.get_file_as_bytes(c.file).to_float32_array());break
 for c in catalog.clips:
  if c.id==idle_id:library.clips.idle=c;break
 retarget.configure(rig,catalog.bones);combo=0
 play("death" if dead else "idle")
 if portrait_presenter!=null:portrait_presenter.set_enabled(restore_projection)
 if atmosphere_service!=null:atmosphere_service.add_weapons(self)
 set_opacity(opacity)
func trigger(kind:String)->void:
 if kind=="battle_revive":
  locomotion_from_positions.clear();locomotion_from_rotations.clear()
  for bone in retarget.evaluation_bones:
   locomotion_from_positions.append(rig.get_bone_pose_position(bone))
   locomotion_from_rotations.append(rig.get_bone_pose_rotation(bone))
  dead=false;combo=0;play("rise")
  action=float(library.clips.rise.frames-1)/library.clips.rise.fps
  locomotion_blend_age=0.0
  return
 if kind in ["death","revive"]:combo=0
 if kind=="attack" and not dead and not attacks.is_empty():
  library.clips.attack=attacks[combo];cache.attack=attack_buffers[combo]
  combo=(combo+1)%attacks.size()
 super(kind)

func apply_hand_pose():
 if dead:return
 for bone in hand_pose:rig.set_bone_pose_rotation(bone,hand_pose[bone])
func advance(dt:float,velocity:Vector3)->void:
 if clip=="attack" and not dead:
  locomotion_blend_age=1.0
  var duration:float=(library.clips.attack.frames-1)/library.clips.attack.fps
  clock+=dt*duration/maxf(.1,attack_seconds)
  retarget.apply(minf(clock,duration))
  if clock>=duration:
   # Preserve the completed strike while the following idle/walk pose blends in.
   # Changing clip alone bypasses the locomotion change detector next frame.
   locomotion_from_positions.clear();locomotion_from_rotations.clear()
   for bone in retarget.evaluation_bones:
    locomotion_from_positions.append(rig.get_bone_pose_position(bone))
    locomotion_from_rotations.append(rig.get_bone_pose_rotation(bone))
   locomotion_blend_age=0.0
   action=0;play("idle")
  apply_hand_pose()
  return
 var move_speed:=Vector2(velocity.x,velocity.z).length()
 var desired:=locomotion_clip(move_speed)
 if locomotion_blend_enabled and not dead and action<=dt and desired!=clip:
  locomotion_from_positions.clear();locomotion_from_rotations.clear()
  for bone in retarget.evaluation_bones:
   locomotion_from_positions.append(rig.get_bone_pose_position(bone))
   locomotion_from_rotations.append(rig.get_bone_pose_rotation(bone))
  locomotion_blend_age=0.0
 super(dt,velocity)
 if dead or not locomotion_blend_enabled:locomotion_blend_age=1.0
 if locomotion_blend_age<LOCOMOTION_BLEND_SECONDS:
  locomotion_blend_age+=dt
  var weight:=smoothstep(0,1,locomotion_blend_age/LOCOMOTION_BLEND_SECONDS)
  for i in retarget.evaluation_bones.size():
   var bone:int=retarget.evaluation_bones[i]
   rig.set_bone_pose_position(bone,locomotion_from_positions[i].lerp(rig.get_bone_pose_position(bone),weight))
   rig.set_bone_pose_rotation(bone,locomotion_from_rotations[i].slerp(rig.get_bone_pose_rotation(bone),weight))
 apply_hand_pose()
