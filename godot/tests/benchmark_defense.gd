extends SceneTree
var app
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(1440,900)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 app=load("res://scenes/defense_route.tscn").instantiate();root.add_child(app)
 while not app.defense_ready:await process_frame
 var results:Array=[]
 for storm in [false,true]:
  app.reset_defense(true);app.defense.begin();app.storm_enabled=storm
  await create_timer(2).timeout
  app.profile_enabled=true;app.profile_usec.clear()
  var times:Array=[];var draws:Array=[];var start:=Time.get_ticks_usec();var last:=start
  while Time.get_ticks_usec()-start<6000000:
   await process_frame
   var now:=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
   draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  app.profile_enabled=false;times.sort();draws.sort()
  var sections:Dictionary={}
  for key in app.profile_usec:sections[key]=app.profile_usec[key]/1000.0/times.size()
  var row={"storm":storm,"frames":times.size(),"mean_ms":(last-start)/1000.0/times.size(),"p50_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"draw_calls":draws[draws.size()/2],"sections_ms":sections}
  results.append(row);print("DEFENSE_BENCH ",JSON.stringify(row))
 var suffix="optimized" if "--optimized" in OS.get_cmdline_user_args() else "baseline"
 var f=FileAccess.open("res://../tempassets/work/defense-benchmark-"+suffix+".json",FileAccess.WRITE);f.store_string(JSON.stringify(results,"  "))
 quit()
