class_name AtmosphereProfile
extends Resource
## Theme/stage art direction. Shared by both views; units are world units and seconds.
@export var haze_color := Color(0.43, 0.56, 0.63)
@export var depth_color := Color(0.015, 0.027, 0.025)
@export_range(0.0, 1.0) var horizon_strength := 0.94
@export_range(0.0, 1.0) var horizon_up := 0.22
@export_range(0.0, 1.0) var horizon_down := 0.30
@export var cloud_seed := 1842
# Near / middle / far: radius, spacing, altitude, width, wind and opacity.
@export var cloud_layers: Array[Dictionary] = [
	{"name": "near", "min": 7000.0, "max": 23000.0, "spacing": 10500.0, "altitude": 4200.0, "width": 6500.0, "wind": 48.0, "opacity": 0.58},
	{"name": "middle", "min": 24000.0, "max": 48000.0, "spacing": 17000.0, "altitude": 10500.0, "width": 10000.0, "wind": 38.0, "opacity": 0.44},
	{"name": "far", "min": 49000.0, "max": 82000.0, "spacing": 26000.0, "altitude": 22000.0, "width": 14000.0, "wind": 27.0, "opacity": 0.30}]
