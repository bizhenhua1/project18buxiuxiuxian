extends SceneTree
const SIM=preload("res://scripts/tactical/simulation.gd")
var roster:Array=JSON.parse_string(FileAccess.get_file_as_string("res://data/tactical_roster.json"))
func fixture():
 var s=SIM.new();s.reset()
 while s.allies.size()<8:
  var a:Dictionary=s.allies[0].duplicate(true);a.id=s.allies.size();s.allies.append(a)
 s.configure_tactics([0,1,2,3,4,5,6,7]);s.begin();s.next_spawn=INF;s.config.total=999
 for i in 8:s.roles.configure(s.allies[i],roster[i]);s.allies[i].pos=Vector3((i-4)*30,0,0);s.allies[i].home=s.allies[i].pos;s.allies[i].next=INF
 return s
func enemy(s,p:Vector3)->Dictionary:
 s.spawn_enemy();var e:Dictionary=s.enemies.back();e.pos=p;e.previous_pos=p;e.activate_at=0;e.entry="road";e.entry_phase="advance";e.next=INF;e.hp=10000;e.max_hp=10000;return e
func cast(s,id:int):
 var a:Dictionary=s.allies[id];a.pos=Vector3.ZERO;a.home=a.pos;a.energy=s.energy_limit(a);assert(s.cast(id));assert(a.energy==0)
func jobs(s,time:float):s.clock=time;s.roles.step()
func _initialize():
 var s=fixture();var a:Dictionary=s.allies[0]
 cast(s,0);assert(a.block==5 and a.reduce==.35)
 var hp:float=a.hp;s.hurt(a,100);assert(is_equal_approx(a.hp,hp-65))
 jobs(s,8.01);assert(a.block==3 and a.reduce==0)
 var e=enemy(s,Vector3(0,0,-1));e.blocked_by=0;hp=e.hp;s.roles.deal(a,10,e);assert(e.hp<hp)
 s=fixture();e=enemy(s,Vector3(0,0,-8));var miss=enemy(s,Vector3(8,0,-8));cast(s,1);jobs(s,.3)
 assert(is_equal_approx(e.hp,10000-52*2.8) and miss.hp==10000)
 s=fixture();e=enemy(s,Vector3(0,0,-8));s.columns.assign([-4.0,0.0,4.0]);s.allies[1].pos=Vector3(4,0,0);cast(s,2);jobs(s,.3)
 assert(is_equal_approx(e.hp,10000-42*2.2) and s.allies[1].energy==4)
 s=fixture();e=enemy(s,Vector3(0,0,-12));cast(s,3);jobs(s,.3)
 assert(s.projectiles.active.size()==1 and s.projectiles.active[0].mode=="ground")
 e.query_id=e.id*2;e.query_enemy=true
 s.projectiles.step(2,[e],s.hurt);assert(is_equal_approx(e.hp,10000-64*3) and s.roles.zones.size()==1)
 jobs(s,1.01);assert(e.hp<10000-64*3)
 s=fixture();e=enemy(s,Vector3(0,0,-8));cast(s,4);jobs(s,.3)
 for i in 7:jobs(s,.31+i*4.0/6.0)
 assert(s.projectiles.active.size()==7,"Seven scheduled missiles, not seven instant strikes")
 s=fixture();s.allies[1].pos=Vector3(2,0,0);s.allies[1].hp=200;cast(s,5);jobs(s,.3)
 assert(s.allies[1].shield==80);hp=s.allies[1].hp;s.hurt(s.allies[1],50);assert(s.allies[1].hp==hp and s.allies[1].shield==30)
 jobs(s,1.01);assert(s.allies[1].hp>hp)
 s=fixture();e=enemy(s,Vector3(0,0,-12));cast(s,6);jobs(s,.3);assert(e.slow_amount==.45);jobs(s,1.01);assert(e.hp<10000)
 s=fixture();e=enemy(s,Vector3(0,0,-5));var boss=enemy(s,Vector3(1,0,-5));boss.boss=true;cast(s,7);jobs(s,.3)
 assert(e.push_left==4 and boss.get("push_left",0)==0)
 # Passive fourth strike, healer target selection and interrupted casts.
 s=fixture();a=s.allies[1];a.pos=Vector3.ZERO;e=enemy(s,Vector3(0,0,-1));a.strikes=3;s.roles.attack(a,e);jobs(s,.3);assert(is_equal_approx(e.hp,10000-52*1.4))
 s=fixture();a=s.allies[5];a.pos=Vector3.ZERO;s.allies[1].pos=Vector3(1,0,0);s.allies[1].hp=100;assert(s.roles.choose(a).id==1)
 s=fixture();e=enemy(s,Vector3(0,0,-8));cast(s,1);s.hurt(s.allies[1],99999);jobs(s,.3);assert(e.hp==10000)
 s=fixture();e=enemy(s,Vector3(0,0,-8));cast(s,4);jobs(s,.3);assert(not s.roles.pending.is_empty())
 s.move_to(s.allies[4],Vector3(3,0,0),"move");assert(s.roles.pending.is_empty(),"Swapping cancels the remaining volley")
 # Every role's ground range and recharge metadata must be usable by the UI.
 for r in roster:
  var spec:Dictionary=s.settings.skills[r.skill];assert(spec.cost>0 and spec.has("shape"))
 print("TACTICAL_ROSTER_SKILLS_PASS eight active skills, reflect, fourth strike, healing, energy, projectile landing, zones, push immunity and death interruption")
 quit()
