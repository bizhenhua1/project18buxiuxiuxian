extends SceneTree
const SIM=preload("res://scripts/tactical/simulation.gd")
func fixture():
 var s=SIM.new();s.reset();s.configure_tactics([0,1]);s.begin();s.next_spawn=INF;s.config.total=999
 for a in s.allies:a.next=INF
 return s
func enemy(s,pos:Vector3):
 s.spawn_enemy();var e:Dictionary=s.enemies.back();e.pos=pos;e.previous_pos=pos;e.activate_at=0;e.entry="road";e.entry_phase="advance";e.next=INF;e.hp=10000;e.max_hp=10000;return e
func _initialize():
 var s=fixture();var a:Dictionary=s.allies[0];var life:int=s.life
 for i in 4:enemy(s,a.pos+Vector3(.1*i,0,-1.2))
 s.step(.05);assert(a.blocked.size()==2)
 var first:Array=a.blocked.duplicate();s.step(.05);assert(a.blocked==first,"Existing blockers must retain ownership")
 s.command(0,"retreat");assert(a.blocked.is_empty())
 for e in s.enemies:assert(e.get("blocked_by",-1)!=0)
 assert(s.swap(0,1));assert(s.allies[0].slot==1 and s.allies[1].slot==0)
 s.hurt(a,9999);assert(s.life==life,"Captain damage must not deduct defense life")
 s.clock=a.death_at+3;s.step(.05);assert(a.hp==0)
 s.clock=a.death_at+5;s.step(.05);assert(a.death_phase=="respawn" and a.pos==a.home)
 s.clock=a.death_at+20;s.step(.05);assert(a.hp==a.max_hp)
 var leak=enemy(s,Vector3(5,0,float(s.config.line_z)+.1));s.step(.05);assert(leak.resolved and s.life==life-1)
 s=fixture();a=s.allies[0]
 a.skill=2;s.step(.5);assert(a.energy==1)
 a.skill=0;s.add_energy(a,"attack");assert(a.energy==6)
 a.skill=1;s.hurt(a,1);assert(a.energy==9)
 a.energy=s.settings.energy_max;a.skill=0
 var hit=enemy(s,a.pos+Vector3(0,0,-10));var miss=enemy(s,a.pos+Vector3(5,0,-10))
 assert(s.cast(0));assert(hit.hp<10000 and miss.hp==10000 and a.energy==0);assert(not s.cast(0))
 var shape=load("res://scripts/tactical/range.gd")
 assert(shape.contains(Vector3.ZERO,Vector3(0,0,-1000),s.settings.skills[3]))
 assert(not shape.contains(Vector3.ZERO,Vector3(0,0,-1000),s.settings.skills[0]))
 assert(shape.contains(Vector3.ZERO,Vector3(0,0,-12),s.settings.skills[2]))
 print("TACTICAL_RULES_PASS blocking capacity/release, swap, captain life isolation, death return/revive, three recharge modes, skill geometry")
 quit()
