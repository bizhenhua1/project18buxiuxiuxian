extends "res://scripts/battle/enemy_actor.gd"
func _init():auto_locomotion=false
var opening_run:=false
var world_units_per_meter:=30.0
var world_scale_calibrated:=false
var defeated:bool:
	get:return dead
func calibrate_world_scale(height:float):
	if not world_scale_calibrated:world_units_per_meter=height/2.55;world_scale_calibrated=true
func travel_speed() -> float:return 1.598785/1.366667*world_units_per_meter
func sync(dt:float,phase:String,moving:float,paused:bool,speed:float,enabled:bool,_distance:float=0):
	if dt<=0:return
	if not dead and state in ["idle","walk","run"]:
		var next:=("run" if opening_run else "walk") if moving>.05 and phase in ["travel","approach","entering","clearing"] else "idle"
		if next!=state:play(next)
	advance(dt,phase,paused,speed,enabled)
