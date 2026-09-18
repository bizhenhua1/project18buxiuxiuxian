extends SceneTree
const SIM=preload("res://scripts/tactical/simulation.gd")
const PROJECTILES=preload("res://scripts/tactical/projectiles.gd")
func enemy(s,p:Vector3)->Dictionary:
 s.spawn_enemy();var e:Dictionary=s.enemies.back();e.pos=p;e.previous_pos=p;e.activate_at=0;e.entry="road";e.entry_phase="advance";e.next=INF;e.hp=10000;e.max_hp=10000;return e
func target(id:int,p:Vector3)->Dictionary:
 return {"id":id,"query_id":id*2,"query_enemy":true,"pos":p,"previous_pos":p,"hp":100.0,"body_scale":1.0}
func _initialize():
 var s=SIM.new();s.reset();s.configure_tactics([0]);s.begin();s.next_spawn=INF;s.config.total=999
 s.columns.assign([-4.0,0.0,4.0,8.0])
 var a:Dictionary=s.allies[0];a.pos=Vector3.ZERO;a.home=a.pos;a.next=INF;a.taunt=true;a.block=1
 var near=enemy(s,Vector3(4,0,-2));var far=enemy(s,Vector3(4,0,-4));var two_columns=enemy(s,Vector3(8,0,-1))
 s.step(.05)
 assert(near.taunted_by==a.id and far.taunted_by==-1 and two_columns.taunted_by==-1,"Reserve only the closest adjacent-column enemy")
 assert(a.taunting.size()==1 and near.pos.x<4,"Reserved enemy must walk toward its taunter")
 for i in 10:s.step(.05)
 assert(near.taunted_by==a.id,"Retain reservation while crossing columns")
 near.pos=Vector3(0,0,-1);near.previous_pos=near.pos;s.step(.05)
 assert(near.blocked_by==a.id and a.taunting.is_empty() and far.taunted_by==-1,"Contact converts reservation to blocking without admitting excess enemies")
 s.command(a.id,"retreat");assert(near.blocked_by==-1 and near.taunted_by==-1)
 a.order="hold";a.state="idle";near.pos=Vector3(4,0,-2);far.pos=Vector3(4,0,-4);s.step(.05)
 assert(a.taunting.size()==1)
 s.hurt(a,100000);assert(near.taunted_by==-1,"Death releases taunt immediately")
 var p=PROJECTILES.new();var locked=target(1,Vector3(0,0,-4));var intercept=target(0,Vector3(0,0,-2))
 var body=load("res://scripts/world3d/combat_body.gd")
 var origin:Vector3=body.center(locked)+Vector3(0,0,4)
 var hits:Array=[]
 p.launch_at(origin,locked,14,10,false,0,"homing")
 p.step(.4,[intercept,locked],func(unit,damage):unit.hp-=damage;hits.append(unit.id))
 assert(hits==[1],"Homing must not be intercepted by an unrelated body")
 p.clear();hits.clear();p.launch_at(origin,locked,14,10,false,0,"ballistic")
 p.step(.4,[intercept,locked],func(unit,damage):unit.hp-=damage;hits.append(unit.id))
 assert(hits==[0],"Ballistic must hit the first physical enemy")
 p.clear();p.launch_at(origin,locked,14,10,false,0,"homing");locked.pos.x=3;locked.previous_pos=locked.pos
 p.step(.05,[locked],func(_unit,_damage):pass);assert(p.active[0].velocity.x>0)
 locked.hp=0;p.step(.05,[locked],func(_unit,_damage):pass);assert(p.active.is_empty(),"Lost homing target must not silently retarget")
 locked.hp=100;locked.pos=Vector3(0,0,-4);locked.previous_pos=locked.pos
 p.launch_at(origin,locked,14,10,false,0,"ballistic");locked.pos.x=5;locked.previous_pos=locked.pos
 p.step(.4,[locked],func(_unit,_damage):assert(false,"A dodged fixed projectile must miss"))
 assert(is_zero_approx(p.active[0].velocity.x))
 print("TACTICAL_TAUNT_PROJECTILES_PASS adjacency, nearest, capacity, stable diversion, contact, release, homing, interception and dodge")
 quit()
