extends SceneTree
func _initialize():
 for profession in ["剑士","先锋","术士"]:
  var s=load("res://scripts/tactical/simulation.gd").new();s.reset();s.configure_tactics([0]);s.begin();s.next_spawn=INF;s.config.total=999
  var a:Dictionary=s.allies[0];a.profession=profession;a.pos=Vector3(2,0,5);a.home=a.pos;a.next=INF
  assert(s.command(0,"advance"));assert(a.destination.z>=s.settings.advance_limit_z)
  for i in 200:
   if i%10==0:s.command(0,"advance")
   s.step(.05);assert(a.pos.z>=s.settings.advance_limit_z-.001)
  assert(is_equal_approx(a.pos.z,s.settings.advance_limit_z) and a.order=="hold")
  assert(not s.command(0,"advance"),"Repeated forward commands cannot ratchet the boundary")
  var e={"id":0,"pos":a.pos+Vector3(0,0,-2)}
  s.fire(a,e,false);assert(a.attack_tip.z>=s.settings.advance_limit_z)
  assert(s.command(0,"retreat"));assert(a.destination==a.home)
 print("TACTICAL_ADVANCE_LIMIT_PASS fixed world boundary, repeated orders, all moving professions, melee excursion and retreat")
 quit()
