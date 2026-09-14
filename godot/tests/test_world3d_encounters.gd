extends SceneTree
func _initialize():
 var session=preload("res://scripts/world3d/encounters.gd").new()
 assert(not session.win() and not session.choose("supplies"),"No interaction before arrival")
 assert(session.depart());session.arrive()
 assert(not session.depart(),"Unresolved battle cannot be skipped by Continue")
 assert(session.win());var earned:int=session.stones
 assert(not session.win() and session.stones==earned,"Reward can be collected only once")
 assert(session.depart() and session.cursor==1)
 session.choose_branch(-1)
 assert(session.current().kind=="social" and not session.arrived)
 assert(not session.choose("fortune"));session.arrive()
 assert(session.choose("fortune") and session.reward_bonus==2)
 assert(not session.choose("supplies"));assert(session.depart())
 assert(session.current().kind=="battle")
 session.sequence=[{"kind":"social","event":"merchant"}];session.cursor=0;session.arrive();session.stones=3
 assert(not session.choose("fortune") and not session.resolved)
 session.stones=4;assert(session.choose("fortune") and session.stones==0)
 print("WORLD3D_ENCOUNTERS_PASS arrival gates, branch content, no skipping, reward deduplication, merchant cost")
 quit()
