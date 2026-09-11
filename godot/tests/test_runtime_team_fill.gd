extends SceneTree
const TEAM=preload("res://scripts/battle/team_lighting.gd")
func _initialize():call_deferred("run")
func run():
 var actor=preload("res://scripts/battle/equipped_actor.gd").new()
 actor.ally=true;actor.model_key="gentleman.glb";actor.model_scene=load("res://assets/characters3d/gentleman.glb");root.add_child(actor)
 actor.body.rotation.y=PI-.22
 for i in 180:actor.sync(.016,"battle",0,false,1,true)
 var saved=TEAM.profiles().battle
 assert(is_equal_approx(actor.team_rim.light_energy,float(saved.rim)))
 assert(is_equal_approx(actor.team_environment.ambient_light_energy,float(saved.ambient)))
 assert(is_equal_approx(actor.team_key.light_energy,float(saved.energy)))
 var data=TEAM.defaults();data.battle.energy=0;data.battle.rim=0;data.battle.ambient=0
 actor.team_light_override=data;actor.update_team_light("battle",0)
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 var dark=brightness(actor.texture().get_image())
 data.battle.ambient=2;actor.update_team_light("battle",0)
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 var filled=brightness(actor.texture().get_image())
 assert(filled>dark+.04)
 print("RUNTIME_TEAM_FILL_PASS saved battle rim=",saved.rim," ambient=",saved.ambient,"; rendered brightness ",dark," -> ",filled)
 quit()
func brightness(image:Image) -> float:
 var sum:=0.0;var count:=0
 for y in range(0,image.get_height(),3):
  for x in range(0,image.get_width(),3):
   var c=image.get_pixel(x,y)
   if c.a>.9:sum+=(c.r+c.g+c.b)/3;count+=1
 return sum/maxi(1,count)
