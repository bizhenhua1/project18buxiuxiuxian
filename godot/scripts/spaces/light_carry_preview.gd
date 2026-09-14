extends VBoxContainer
const GRIP=preload("res://scripts/spaces/weapon_preview.gd")
var browser:Control
var mode:=0
var side:=0
var prop:Node3D
var flame:MeshInstance3D
var light:OmniLight3D
var picker:OptionButton
var height:SpinBox
var reach:SpinBox
var walking:=true
var note:Label
var clock:=0.0
func setup(owner_browser:Control):
 browser=owner_browser
 var label:=Label.new();label.text="持灯行走 · 试验";add_child(label)
 picker=OptionButton.new()
 for text in ["关闭持灯","举火把","提灯笼"]:picker.add_item(text)
 add_child(picker);picker.item_selected.connect(func(i):mode=i;rebuild();choose_motion())
 var hand:=OptionButton.new();hand.add_item("右手持灯");hand.add_item("左手持灯");add_child(hand)
 hand.item_selected.connect(func(i):side=i;rebuild())
 var walk:=CheckButton.new();walk.text="一边行走";walk.button_pressed=true;add_child(walk)
 walk.toggled.connect(func(v):walking=v;choose_motion())
 for spec in [["手部高度",.3,1.8,1.3],["向前伸出",.05,.6,.30]]:
  var row:=HBoxContainer.new();add_child(row)
  var text:=Label.new();text.text=spec[0];row.add_child(text)
  var spin:=SpinBox.new();spin.min_value=spec[1];spin.max_value=spec[2];spin.step=.02;spin.value=spec[3];row.add_child(spin)
  if height==null:height=spin
  else:reach=spin
 note=Label.new();note.text="原地步态预览 · 上半身持灯叠加
切换角色、左右手检查握持";add_child(note)
func choose_motion():
 if mode==0:return
 browser.weapon_panel.weapon=0;browser.weapon_panel.picker.select(0);browser.weapon_panel.bind_model()
 var data=JSON.parse_string(FileAccess.get_file_as_string("res://data/world_hero_motions.json"))
 var entry:Dictionary=data.walk if walking else data.idle
 entry=entry.duplicate();entry.id="light_carry_walk" if walking else "light_carry_idle";entry.name="持灯行走" if walking else "持灯待机"
 browser.select_clip(entry);browser.looping=true
func rebuild():
 if is_instance_valid(prop):prop.queue_free()
 prop=null;flame=null
 if mode==0:return
 prop=Node3D.new();browser.stage.add_child(prop)
 height.value=1.3 if mode==1 else .96
 var wood:=StandardMaterial3D.new();wood.albedo_color=Color("493025")
 var metal:=StandardMaterial3D.new();metal.albedo_color=Color("866744");metal.metallic=.75;metal.roughness=.35
 var glow:=StandardMaterial3D.new();glow.albedo_color=Color("ffba43");glow.emission_enabled=true;glow.emission=Color("ff922b");glow.emission_energy_multiplier=2
 if mode==1:
  cylinder(.024,.4,Vector3(0,.1,0),wood)
  cylinder(.045,.1,Vector3(0,.31,0),metal)
  flame=MeshInstance3D.new();flame.mesh=SphereMesh.new();flame.mesh.radius=.05;flame.mesh.height=.17;flame.position.y=.4;flame.material_override=glow;prop.add_child(flame)
 else:
  var handle:=MeshInstance3D.new();handle.mesh=TorusMesh.new();handle.mesh.inner_radius=.045;handle.mesh.outer_radius=.06;handle.rotation.x=PI/2;handle.position.y=-.045;handle.material_override=metal;prop.add_child(handle)
  cylinder(.10,.025,Vector3(0,-.14,0),metal);cylinder(.10,.03,Vector3(0,-.34,0),metal)
  for x in [-.065,.065]:
   for z in [-.065,.065]:cylinder(.009,.20,Vector3(x,-.24,z),metal)
  cylinder(.022,.1,Vector3(0,-.27,0),wood)
  flame=MeshInstance3D.new();flame.mesh=SphereMesh.new();flame.mesh.radius=.022;flame.mesh.height=.065;flame.position.y=-.195;flame.material_override=glow;prop.add_child(flame)
 light=OmniLight3D.new();light.light_color=Color("ffd599");light.light_energy=.6;light.omni_range=1.6;light.position=flame.position;prop.add_child(light)
func cylinder(radius:float,length:float,position:Vector3,material:Material):
 var mesh:=MeshInstance3D.new();mesh.mesh=CylinderMesh.new();mesh.mesh.top_radius=radius;mesh.mesh.bottom_radius=radius;mesh.mesh.height=length;mesh.position=position;mesh.material_override=material;prop.add_child(mesh)
func aim(rig:Skeleton3D,bone:int,child:int,destination:Vector3):
 var pose:=rig.get_bone_global_pose(bone)
 var from:=rig.get_bone_global_pose(child).origin-pose.origin
 var to:=destination-pose.origin
 if from.length_squared()<.00001 or to.length_squared()<.00001:return
 var rotation:=Basis(Quaternion(from.normalized(),to.normalized()))*pose.basis
 var parent:=rig.get_bone_parent(bone)
 var parent_basis:=rig.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
 rig.set_bone_pose_rotation(bone,(parent_basis.inverse()*rotation).get_rotation_quaternion())
func advance(dt:float):
 if mode==0 or not is_instance_valid(prop) or not browser.rig:return
 if browser.playing:clock+=dt*browser.rate
 var rig:Skeleton3D=browser.rig
 var suffix:=".R" if side==0 else ".L"
 var upper:=rig.find_bone("腕"+suffix);var elbow:=rig.find_bone("ひじ"+suffix);var hand:=rig.find_bone("手首"+suffix)
 if mini(upper,mini(elbow,hand))<0:note.text="该模型手臂骨骼未匹配";prop.hide();return
 prop.show()
 var scale:float=rig.global_basis.get_scale().x
 var shoulder:=rig.get_bone_global_pose(upper).origin
 var sign_x:=signf(rig.get_bone_global_rest(hand).origin.x)
 var target:=Vector3(sign_x*.32,height.value,reach.value)/scale
 target.y+=sin(clock*5)*.009/scale
 var l1:=shoulder.distance_to(rig.get_bone_global_pose(elbow).origin)
 var l2:=rig.get_bone_global_pose(elbow).origin.distance_to(rig.get_bone_global_pose(hand).origin)
 var direction:Vector3=(target-shoulder).normalized()
 var distance:=clampf(target.distance_to(shoulder),absf(l1-l2)+.01,l1+l2-.015)
 target=shoulder+direction*distance
 var along:float=(l1*l1-l2*l2+distance*distance)/(2*distance)
 var pole:=Vector3(sign_x,-.5,-.2);pole=(pole-direction*pole.dot(direction)).normalized()
 var bend:=shoulder+direction*along+pole*sqrt(maxf(0,l1*l1-along*along))
 aim(rig,upper,elbow,bend);aim(rig,elbow,hand,target)
 var mount:Transform3D=GRIP.palm_mount(rig,hand,side)
 var sway:=sin(clock*3)*.06 if mode==2 else sin(clock*4)*.018
 # Let the forearm supply pronation; do not force a fixed world yaw at the wrist.
 var forearm:Vector3=(rig.get_bone_global_pose(hand).origin-rig.get_bone_global_pose(elbow).origin).normalized()
 var neutral:Basis=rig.get_bone_global_pose(elbow).basis*rig.get_bone_rest(hand).basis
 var shaft:Vector3=(neutral*mount.basis).y.normalized()
 var desired:=Vector3.UP if mode==1 else Vector3(sign_x,0,0)
 if mode==2 and desired.dot(shaft)<0:desired=-desired
 var projected:Vector3=(shaft-forearm*shaft.dot(forearm)).normalized()
 var goal:Vector3=(desired-forearm*desired.dot(forearm)).normalized()
 var twist:=projected.signed_angle_to(goal,forearm)
 var elbow_pose:=rig.get_bone_global_pose(elbow)
 var elbow_parent:=rig.get_bone_parent(elbow)
 var roll:=Basis(forearm,clampf(twist,-1.35,1.35))*elbow_pose.basis
 rig.set_bone_pose_rotation(elbow,(rig.get_bone_global_pose(elbow_parent).basis.inverse()*roll).get_rotation_quaternion())
 neutral=roll*rig.get_bone_rest(hand).basis
 shaft=(neutral*mount.basis).y.normalized()
 var correction:=Quaternion(shaft,desired)
 var limited:=Quaternion.IDENTITY.slerp(correction,minf(1.0,deg_to_rad(28)/maxf(correction.get_angle(),.001)))
 var wrist_basis:=Basis(limited)*neutral
 rig.set_bone_pose_rotation(hand,(roll.inverse()*wrist_basis).get_rotation_quaternion())
 browser.weapon_panel.curl_hand(side)
 # The thumb opposes the index finger; its basal joint needs its own direction.
 var thumb0:=rig.find_bone("親指０"+suffix)
 var thumb1:=rig.find_bone("親指１"+suffix)
 var thumb2:=rig.find_bone("親指２"+suffix)
 var index:=rig.find_bone("人指１"+suffix)
 if thumb0>=0 and thumb1>=0 and thumb2>=0 and index>=0:
  for bone in [thumb0,thumb1,thumb2]:rig.set_bone_pose_rotation(bone,rig.get_bone_rest(bone).basis.get_rotation_quaternion())
  var grip:=rig.get_bone_global_pose(hand)*mount
  var index_point:=rig.get_bone_global_pose(index).origin
  aim(rig,thumb0,thumb1,index_point.lerp(grip.origin,.45))
  aim(rig,thumb1,thumb2,grip.origin+grip.basis.y*.018/scale)
 var palm:Transform3D=rig.global_transform*rig.get_bone_global_pose(hand)*mount
 var prop_basis:=Basis(Vector3.FORWARD,sway)
 prop.global_transform=Transform3D(rig.global_basis.orthonormalized()*prop_basis,palm.origin)
 if flame:flame.scale=Vector3(1+.06*sin(clock*17),1+.15*sin(clock*13),1)
 light.light_energy=.55+.05*sin(clock*17)
