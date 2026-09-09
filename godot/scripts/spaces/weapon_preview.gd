extends VBoxContainer
var save_path:="user://weapon-preview-kaykit-grips.cfg"
var items:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/catalog.json"))
var mount:=Transform3D.IDENTITY
var weapon_tracks:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/weapon_tracks.json"))
var shield_attachment:BoneAttachment3D
var shield_enabled:=false
var browser:Control
var weapon:int=0
var hand:int=0
var attachment:BoneAttachment3D
var visual:Node3D
var picker:OptionButton
var hands:OptionButton
var fields:Dictionary={}
var status:Label
var loading:=false
func setup(owner_browser:Control) -> void:
 browser=owner_browser
 var title:=Label.new();title.text="手持武器预览";add_child(title)
 picker=OptionButton.new()
 for item in items:picker.add_item(item.name)
 add_child(picker);picker.item_selected.connect(func(i):weapon=i;bind_model())
 hands=OptionButton.new();hands.add_item("右手");hands.add_item("左手");add_child(hands)
 hands.item_selected.connect(func(i):hand=i;bind_model())
 var shield:=CheckButton.new();shield.text="副手持盾";add_child(shield);shield.toggled.connect(func(v):shield_enabled=v;bind_model())
 var motions:=Button.new();motions.text="查看对应职业动作";add_child(motions)
 motions.pressed.connect(func():
  var pack:String=items[weapon].pack
  var index:int=browser.pack_ids.find(pack)
  if index>=0:browser.pack_tabs.current_tab=index
  browser.search.text="";browser.categories.select(0);browser.refresh_list())
 var toggle:=CheckButton.new();toggle.text="调整握持位置";add_child(toggle)
 var edits:=VBoxContainer.new();edits.visible=false;add_child(edits);toggle.toggled.connect(func(v):edits.visible=v)
 for key in ["x","y","z","rx","ry","rz","scale"]:
  var row:=HBoxContainer.new();edits.add_child(row)
  var label:=Label.new();label.text={"x":"左右（米）","y":"上下（米）","z":"前后（米）","rx":"旋转 X","ry":"旋转 Y","rz":"旋转 Z","scale":"武器大小"}[key];label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(label)
  var spin:=SpinBox.new();spin.min_value=.1 if key=="scale" else -180 if key.begins_with("r") else -1;spin.max_value=3 if key=="scale" else 180 if key.begins_with("r") else 1;spin.step=.05 if key=="scale" else 5 if key.begins_with("r") else .01;spin.value=1 if key=="scale" else 0;row.add_child(spin);fields[key]=spin
  spin.value_changed.connect(func(_v):apply_grip())
 var save:=Button.new();save.text="保存当前握持";edits.add_child(save);save.pressed.connect(save_grip)
 var reset:=Button.new();reset.text="恢复默认握持";edits.add_child(reset);reset.pressed.connect(func():load_grip(false))
 status=Label.new();status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.custom_minimum_size.x=210;add_child(status)
func section() -> String:return "%s/%d/%d" % [browser.MODELS[browser.selected_model].file,weapon,hand]
func bind_model() -> void:
 if is_instance_valid(attachment):attachment.get_parent().remove_child(attachment);attachment.queue_free()
 if is_instance_valid(shield_attachment):shield_attachment.get_parent().remove_child(shield_attachment);shield_attachment.queue_free()
 shield_attachment=null
 attachment=null;visual=null
 if weapon==0:status.text="未装备武器";return
 if not browser.rig:return
 var names:Array=["手首.R","右手首","RightHand","hand_r"] if hand==0 else ["手首.L","左手首","LeftHand","hand_l"]
 var bone:=-1
 for candidate in names:
  bone=browser.rig.find_bone(candidate)
  if bone>=0:break
 if bone<0:status.text="该角色未找到手部骨骼";return
 attachment=BoneAttachment3D.new();browser.rig.add_child(attachment);attachment.bone_idx=bone
 mount=palm_mount(browser.rig,bone,hand)
 visual=build_weapon(weapon);attachment.add_child(visual)
 load_grip(true)
 if shield_enabled:
  var other:int=browser.rig.find_bone("手首.L" if hand==0 else "手首.R")
  if other>=0:
   shield_attachment=BoneAttachment3D.new();browser.rig.add_child(shield_attachment);shield_attachment.bone_idx=other
   var shield_index:int=0
   for i in range(items.size()):
    if items[i].get("file","")=="shield_A.gltf":shield_index=i;break
   var shield_model:=build_weapon(shield_index);shield_attachment.add_child(shield_model)
   var grip:=palm_mount(browser.rig,other,1-hand)
   var inv_scale:float=1.0/browser.rig.global_transform.basis.get_scale().x
   shield_model.transform=Transform3D(grip.basis*Basis.from_euler(Vector3(0,0,PI*.5))*float(items[shield_index].scale)*inv_scale,grip.origin)
 status.text="已按手掌骨骼校准。源动作中的手指姿态保留；双手武器请选匹配的持握动作。"
func default_value(key:String) -> float:
 return 1.0 if key=="scale" else 0.0
func load_grip(saved:bool) -> void:
 loading=true
 var config:=ConfigFile.new();config.load(save_path)
 for key in fields:fields[key].value=config.get_value(section(),key,default_value(key)) if saved else default_value(key)
 loading=false;apply_grip()
func apply_grip() -> void:
 if loading or not is_instance_valid(visual):return
 var scale_factor:float=1.0/maxf(browser.rig.global_transform.basis.get_scale().x,.001)
 var offset:=Vector3(fields.x.value,fields.y.value,fields.z.value)*scale_factor
 var rotate:=Basis.from_euler(Vector3(fields.rx.value,fields.ry.value,fields.rz.value)*PI/180.0)
 if items[weapon].kind=="shield":rotate=Basis.from_euler(Vector3(0,0,PI*.5))*rotate
 visual.transform=Transform3D(mount.basis*rotate*float(fields.scale.value)*float(items[weapon].scale)*scale_factor,mount.origin+mount.basis*offset)
func save_grip() -> void:
 var config:=ConfigFile.new();config.load(save_path)
 for key in fields:config.set_value(section(),key,fields[key].value)
 var result:=config.save(save_path)
 status.text="握持参数已保存" if result==OK else "保存失败：%s" % error_string(result)
func build_weapon(kind:int) -> Node3D:
 return load("res://assets/weapons/kaykit/"+items[kind].file).instantiate()
static func palm_mount(rig:Skeleton3D,bone:int,side:int) -> Transform3D:
 var suffix:=".R" if side==0 else ".L"
 var wrist:=rig.get_bone_global_rest(bone)
 var index:=rig.find_bone("人指１"+suffix)
 var pinky:=rig.find_bone("小指１"+suffix)
 var middle:=rig.find_bone("中指１"+suffix)
 if index<0 or pinky<0 or middle<0:return Transform3D(Basis.IDENTITY,Vector3.ZERO)
 var first:Vector3=rig.get_bone_global_rest(index).origin
 var last:Vector3=rig.get_bone_global_rest(pinky).origin
 var mid:Vector3=rig.get_bone_global_rest(middle).origin
 var along:Vector3=(mid-wrist.origin).normalized()
 var shaft:Vector3=(first-last).normalized()
 var normal:Vector3=along.cross(shaft).normalized()
 shaft=normal.cross(along).normalized()
 # Weapon Y follows the knuckle line towards the thumb, not the wrist axis.
 var basis:=Basis(shaft.cross(normal).normalized(),shaft,normal).orthonormalized()
 var center:Vector3=wrist.origin.lerp((first+last+mid)/3.0,.72)
 return wrist.affine_inverse()*Transform3D(basis,center)

func sample_weapon_motion() -> void:
 if not is_instance_valid(visual):return
 apply_grip()
 if hand!=0 or not weapon_tracks.has(browser.selected.get("id","")):return
 var track:Dictionary=weapon_tracks[browser.selected.id]
 var frame:float=clampf(browser.elapsed*30.0,0,track.rotations.size()-1)
 var a:=int(frame);var b:=mini(a+1,track.rotations.size()-1);var weight:=frame-a
 var first:Array=track.rotations[0];var qa:Array=track.rotations[a];var qb:Array=track.rotations[b]
 var rest:=Quaternion(first[0],first[1],first[2],first[3]).normalized()
 var current:=Quaternion(qa[0],qa[1],qa[2],qa[3]).normalized().slerp(Quaternion(qb[0],qb[1],qb[2],qb[3]).normalized(),weight)
 # Convert UE local coordinates to the weapon's Y-up glTF frame. The animated
 # correction is relative to the clip's grip, preserving the anatomical mount.
 var convert:=Basis(Vector3(0,0,-1),Vector3(1,0,0),Vector3(0,1,0))
 var correction:Basis=convert*Basis(rest.inverse()*current)*convert.inverse()
 visual.basis=visual.basis*correction
 var pa:Array=track.positions[a];var pb:Array=track.positions[b];var p0:Array=track.positions[0]
 var delta:Vector3=Vector3(pa[0],pa[1],pa[2]).lerp(Vector3(pb[0],pb[1],pb[2]),weight)-Vector3(p0[0],p0[1],p0[2])
 visual.position+=mount.basis*(convert*delta)*.01/browser.rig.global_transform.basis.get_scale().x
