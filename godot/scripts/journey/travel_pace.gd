class_name TravelPace
extends RefCounted
# Locomotion defines world distance. Event layout consumes these values, never vice versa.
const WALK:=1.598785/1.366667*30.0
const RUN:=WALK*1.75
const BRAKE_SECONDS:=.4
static func leg_distance(first:bool) -> float:
	return (RUN if first else WALK)*((3.0 if first else 4.0)-.25)


const EXIT_DISTANCE:=16.0
static func mixed_distance(fork:bool=false) -> float:
	return RUN*(4.6 if fork else 2.7)+WALK*((1.4 if fork else 1.0)-BRAKE_SECONDS*.5)
static func mixed_speed(traveled:float,fork:bool=false) -> float:
	var run_distance:=RUN*(4.6 if fork else 2.7)
	return lerpf(RUN,WALK,smoothstep(run_distance-RUN*.25,run_distance,traveled))

const MONSTER_APPROACH_SECONDS:=2.8
const MONSTER_WALK_SPEED:=WALK*.8
