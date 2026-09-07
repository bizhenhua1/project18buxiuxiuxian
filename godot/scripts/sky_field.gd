class_name SkyField
extends RefCounted
## Deterministic world-space field. Camera selects cells, but never drags clouds.
var profile: AtmosphereProfile
var horizon_texture: Texture2D
var cached_camera := Vector2(INF, INF)
var cached_time := -1.0
var cached_clouds: Array[Dictionary] = []

func _init(settings: AtmosphereProfile) -> void:
	profile = settings
	var gradient := Gradient.new()
	var pivot := profile.horizon_up / (profile.horizon_up + profile.horizon_down)
	gradient.offsets = PackedFloat32Array([0, pivot * 0.45, pivot * 0.75, pivot, pivot + (1.0 - pivot) * 0.35, 1])
	var deep := profile.haze_color.lerp(profile.depth_color, 0.92)
	gradient.colors = PackedColorArray([Color(profile.haze_color, 0), Color(profile.haze_color.lerp(deep, 0.35), 0.25 * profile.horizon_strength), Color(deep, 0.72 * profile.horizon_strength), Color(deep, profile.horizon_strength), Color(profile.depth_color, 0.65 * profile.horizon_strength), Color(profile.depth_color, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 2
	texture.height = 512
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	horizon_texture = texture

func cell(layer_index: int, grid: Vector2i, time: float) -> Dictionary:
	var layer := profile.cloud_layers[layer_index]
	var rng := RandomNumberGenerator.new()
	rng.seed = profile.cloud_seed + grid.x * 73856093 + grid.y * 19349663 + layer_index * 83492791
	var jitter := Vector2(rng.randf_range(-0.32, 0.32), rng.randf_range(-0.32, 0.32))
	var position := (Vector2(grid) + jitter) * float(layer.spacing)
	# One prevailing wind per altitude, with a small smooth gust. No idle Z conveyor.
	position.x += float(layer.wind) * time + 160.0 * sin(time * 0.035 + layer_index)
	return {"position": position, "altitude": float(layer.altitude) * rng.randf_range(0.85, 1.15),
		"width": float(layer.width) * rng.randf_range(0.8, 1.2), "texture_index": rng.randi_range(0, 100),
		"opacity": float(layer.opacity), "layer": layer_index, "id": str(layer_index) + ":" + str(grid)}

func visible_clouds(camera: Vector2, time: float) -> Array[Dictionary]:
	if camera == cached_camera and time == cached_time:
		return cached_clouds
	var result: Array[Dictionary] = []
	for index in range(profile.cloud_layers.size()):
		var layer := profile.cloud_layers[index]
		var wind := float(layer.wind) * time + 160.0 * sin(time * 0.035 + index)
		var center := Vector2i((camera - Vector2(wind, 0)) / float(layer.spacing))
		var radius := int(ceil(float(layer.max) / float(layer.spacing))) + 1
		for z in range(center.y - radius, center.y + radius + 1):
			for x in range(center.x - radius, center.x + radius + 1):
				var state := cell(index, Vector2i(x, z), time)
				var distance: float = state.position.distance_to(camera)
				var fade := smoothstep(float(layer.min), float(layer.min) + 2500, distance) * (1.0 - smoothstep(float(layer.max) - 4000, float(layer.max), distance))
				if fade <= 0:
					continue
				state.opacity *= fade
				result.append(state)
	cached_camera = camera
	cached_time = time
	cached_clouds = result
	return result
