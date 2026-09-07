class_name RouteRegion
extends Resource
## Owns geometry in a persistent route interval; other intervals coexist in view.
@export var key: StringName
@export var branch := 0
@export var start := -400.0
@export var end := 6000.0
@export var space: SpaceType
@export var blend_length := 160.0

func contains(s: float, path: int) -> bool:
	return path == branch and s >= start and s < end
