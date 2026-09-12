extends RefCounted
## Links connect actual cells; navigation owns displacement, clips supply poses.
var links:Array[Dictionary]=[]
var pending:Dictionary={}
var active:Dictionary={}
var clock:=0.0
var duration:=4.0
const SETTLE_SECONDS:=.5
const MANTLE_SECONDS:=1.45
const STEP_SECONDS:=.65
const WALL_CONTACT:=.22
var action_duration:=2.1
var exit_sent:=false
var hip_grid_height:=1.3
const CLIMB_RATE:=.38
var climb_samples:=PackedFloat32Array()
var climb_stride:=0
var climb_frames:=0
var climb_fps:=30.0
var top_samples:=PackedFloat32Array()
var top_frames:=0
func _init():
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motions/catalog.json"))
	var entry:Dictionary=catalog.clips.filter(func(c):return c.id=="3_Obstacle_Climb_Loop")[0]
	climb_samples=FileAccess.get_file_as_bytes(entry.file).to_float32_array();climb_stride=3+catalog.bones.size()*4;climb_frames=entry.frames;climb_fps=entry.fps
	var top:Dictionary=catalog.clips.filter(func(c):return c.id=="3_Obstacle_Climb_onTop")[0]
	top_samples=FileAccess.get_file_as_bytes(top.file).to_float32_array();top_frames=top.frames
func top_root(t:float)->Vector3:
	var frame:=clampf(t,0,1)*(top_frames-1);var i:=int(frame);var j:=mini(i+1,top_frames-1)
	return Vector3(lerpf(top_samples[i*climb_stride],top_samples[j*climb_stride],frame-i),lerpf(top_samples[i*climb_stride+1],top_samples[j*climb_stride+1],frame-i),lerpf(top_samples[i*climb_stride+2],top_samples[j*climb_stride+2],frame-i))
func climb_height(seconds:float)->float:
	var frame:=maxf(0,seconds)*CLIMB_RATE*climb_fps
	var cycles:=floorf(frame/(climb_frames-1));var f:=fmod(frame,climb_frames-1)
	var i:=int(f);var start:=climb_samples[1];var end:=climb_samples[(climb_frames-1)*climb_stride+1]
	return (cycles*(end-start)+lerpf(climb_samples[i*climb_stride+1],climb_samples[mini(i+1,climb_frames-1)*climb_stride+1],f-i)-start)*hip_grid_height
func start_arrival(model:IslandModel,link:Dictionary):
	active=link.duplicate();active.arrival=true;pending={};clock=0;exit_sent=false
	action_duration=MANTLE_SECONDS+STEP_SECONDS if active.kind=="climb" else 1.7
	duration=action_duration+SETTLE_SECONDS
	model.input_locked=true
func advance_departure_fade(dt:float,fade:float):
	clock+=dt*(1.0-smoothstep(0,1,fade))
func advance_arrival(model:IslandModel,dt:float):
	# Advance animation and position together; bound the speed of steep source segments.
	var before:=pose(model);var previous:=clock
	var target:=minf(clock+dt,duration)
	var lo:=previous;var hi:=target
	var limit:=1.3 if active.kind=="climb" else 1.7
	clock=target
	for attempt in 12:
		var delta:=pose(model)-before
		var distance:=Vector3((delta.x-delta.z)*.5,delta.y*IslandView3D.HEIGHT,(delta.x+delta.z)*.5).length()
		if distance<=limit*dt+.000001:
			lo=clock
			if clock==target:break
		else:hi=clock
		clock=(lo+hi)*.5
	clock=lo

func reset():
	links.clear();pending.clear();active.clear();clock=0;exit_sent=false
func request(model: IslandModel,id:String)->bool:
	if model.input_locked or model.walking or model.spin_direction!=0 or not active.is_empty() or not pending.is_empty():return false
	for link in links:
		if link.id!=id:continue
		if not link.has("destination_map") and (not model.lookup.has(link.to) or model.blocked.has(link.to)):return false
		if model.player!=link.from and not model.go_to(link.from):return false
		pending=link;return true
	return false
func advance(model:IslandModel,dt:float):
	if exit_sent:return
	if active.is_empty():
		if pending.is_empty() or model.walking:return
		if model.player!=pending.from:pending={};return
		active=pending;pending={};clock=0
		duration=active.get("duration",4.0)
		model.remember(active.to)
		return
	if active.get("arrival",false):advance_arrival(model,dt)
	else:clock+=dt
	var at_boundary:=clock>=.85 if active.get("kind","")=="hole" else pose(model).y>=float(active.get("transition_height",3.6))
	if active.has("destination_map") and at_boundary:
		exit_sent=true;model.input_locked=true;model.passage_requested.emit(active.duplicate());return
	if active.has("destination_map"):return
	if clock>=duration:
		var arrival:bool=active.get("arrival",false)
		model.player=active.to;active={}
		if arrival:model.input_locked=false
		model.reveal_near(model.player);model.update_sight();model.arrived.emit(model.lookup[model.player])
func pose(model:IslandModel)->Vector3:
	var a:Vector2=Vector2(active.from);var b:Vector2=Vector2(active.to)
	var t:=clampf(clock/duration,0,1)
	var low:float=model.lookup.get(active.from,{}).get("h",0.0);var high:float=active.get("exit_height",model.lookup.get(active.to,{}).get("h",low))
	var edge:=a.lerp(b,.43)
	if active.get("arrival",false):
		t=clampf(clock/action_duration,0,1)
		var land_height:float=model.lookup[active.to].h
		if active.kind=="climb":
			var landing:=a.lerp(b,.72)
			if clock>=MANTLE_SECONDS:
				var step:=clampf((clock-MANTLE_SECONDS)/STEP_SECONDS,0,1)
				var walk:=landing.lerp(b,smoothstep(0,1,step))
				return Vector3(walk.x,land_height,walk.y)
			t=clampf(clock/MANTLE_SECONDS,0,1)
			var contact:Vector2=Vector2(active.get("edge_grid",a.lerp(b,WALL_CONTACT)))
			var root:=top_root(t);var end:=top_root(1);var start:=top_root(0)
			var progress:=clampf((root.z-start.z)/(end.z-start.z),0,1)
			var height:float=(root.y-end.y)*hip_grid_height
			# Keep the pelvis outside the wall until the feet clear its lip.
			progress*=smoothstep(-.4,0,height)
			var p:=contact.lerp(landing,progress)
			return Vector3(p.x,land_height+height,p.y)
		var fall:=clampf(clock/.72,0,1)
		return Vector3(b.x,land_height+3.2*(1-fall*fall),b.y)
	if active.has("destination_map"):
		var drop:bool=active.get("kind","")=="hole"
		edge=a.lerp(b,.9 if drop else WALL_CONTACT)
		var point:Vector2=a.lerp(edge,smoothstep(0,.65,clock))
		var y:=low-5.0*pow(maxf(0,clock-.4),2) if drop else low+climb_height(clock-.75)
		return Vector3(point.x,y,point.y)
	if active.get("kind","")=="hole":edge=a
	var xy:Vector2
	var y:float
	if t<.18:
		xy=a.lerp(edge,smoothstep(0,.18,t));y=low
	elif t<.8:
		xy=edge;y=lerpf(low,high,smoothstep(.18,.8,t))
	else:
		xy=edge.lerp(b,smoothstep(.8,1,t));y=high
	return Vector3(xy.x,y,xy.y)
func motion()->Dictionary:
	var t:=clock/duration
	var down:bool=active.get("down",false)
	if active.get("arrival",false):
		if clock>=action_duration:return {"name":"idle","loop":true,"time":clock-action_duration}
		t=clampf(clock/action_duration,0,1)
		if active.kind=="climb":
			if clock>=MANTLE_SECONDS:return {"name":"walk","loop":true,"time":clock-MANTLE_SECONDS}
			return {"name":"3_Obstacle_Climb_onTop","loop":false,"fraction":clock/MANTLE_SECONDS}
		return {"name":"3_Obstacle_Drop_Loop","loop":true,"time":clock} if clock<.72 else {"name":"jump","loop":false,"fraction":lerpf(.72,1,clampf((clock-.72)/.68,0,1))}
	if active.has("destination_map"):
		if active.get("kind","")=="hole":return {"name":"3_Obstacle_Drop_Loop","loop":true,"time":clock}
		return {"name":"3_Obstacle_Climb_Start","loop":false,"fraction":clock/.75} if clock<.75 else {"name":"3_Obstacle_Climb_Loop","loop":true,"time":(clock-.75)*CLIMB_RATE}
	if active.get("kind","")=="hole":
		return {"name":"3_Obstacle_Drop_Loop" if t<.8 else "3_WallPoints_Release_End","loop":t<.8,"time":clock if t<.8 else clock-duration*.8}
	if t<.18:return {"name":"3_Ladder_Enter_Dn" if down else "3_Obstacle_Climb_Start","loop":false,"fraction":t/.18}
	if t<.8:return {"name":"3_Ladder_Descend_Loop" if down else "3_Obstacle_Climb_Loop","loop":true,"time":(clock-duration*.18)*.38}
	return {"name":"3_Ladder_Exit_Dn" if down else "3_Obstacle_Climb_onTop","loop":false,"fraction":(t-.8)/.2}
