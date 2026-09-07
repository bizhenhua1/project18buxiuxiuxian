class_name ForestArt
extends RefCounted
## Original final PNGs are retained; generated crops/mips/patches live in memory.
var profile: AtmosphereProfile
var textures: Dictionary = {}
var images: Dictionary = {}
var patches: Array[Texture2D] = []
var low_patches: Array[Texture2D] = []
var clouds: Array[Texture2D] = []
static var prepared: PreparedForestArt
var route_coordinates := PackedVector2Array()

func _init(settings: AtmosphereProfile = null) -> void:
	profile = settings if settings else load("res://profiles/forest.tres") as AtmosphereProfile
	if StyleLibrary.active:
		profile = profile.duplicate(true)
		profile.haze_color = Color("657b85")
		profile.depth_color = Color("101923")
		for layer in profile.cloud_layers: layer.opacity *= .45
		var mapping := {"tree-side":"tree-a","tree-b":"tree-b","tree-c":"tree-a","grass-1":"fern","grass-2":"reeds","grass-3":"shrub","grass-4":"fern","foliage":"shrub","mtn-far":"tree-b","mtn-near":"tree-a","sun":"mist","moon":"mist","cloud-strip":"mist","ground-tile":"ground","ridge-haze":"mist","island":"tower"}
		for key in mapping:
			textures[key] = StyleLibrary.texture(mapping[key])
			images[key] = textures[key].get_image()
		clouds.append(textures["cloud-strip"])
		for i in range(4):
			patches.append(textures["grass-1" if i%2==0 else "grass-2"])
			low_patches.append(textures["grass-4"])
		return
	if settings == null and ResourceLoader.exists("res://assets/prepared/forest_art.res"):
		if not prepared: prepared = load("res://assets/prepared/forest_art.res")
		textures = prepared.textures.duplicate()
		patches = prepared.patches.duplicate()
		low_patches = prepared.low_patches.duplicate()
		clouds = prepared.clouds.duplicate()
		route_coordinates = prepared.route_coordinates
		for entry in prepared.silhouettes:
			SpaceAssets.shared_silhouettes[str(entry.texture.get_instance_id())+str(entry.color)] = entry.result
		return
	for key in ["tree-side", "tree-b", "tree-c", "grass-1", "grass-2", "grass-3", "grass-4", "foliage", "mtn-far", "mtn-near", "sun", "moon", "cloud-strip", "ground-tile"]:
		var original: Texture2D = load("res://assets/forest/%s.png" % key)
		var img := original.get_image()
		img.convert(Image.FORMAT_RGBA8)
		if key != "ground-tile":
			img = img.get_region(img.get_used_rect())
		if maxi(img.get_width(), img.get_height()) > 1024:
			var ratio := 1024.0 / maxi(img.get_width(), img.get_height())
			img.resize(int(img.get_width() * ratio), int(img.get_height() * ratio), Image.INTERPOLATE_LANCZOS)
		images[key] = img
		var mip := img.duplicate() as Image
		mip.generate_mipmaps()
		textures[key] = ImageTexture.create_from_image(mip)
	# Atmospheric distance changes RGB, never silhouette opacity: the sun cannot bleed through.
	var hazy_ridge: Image = images["mtn-far"].duplicate()
	for y in range(hazy_ridge.get_height()):
		for x in range(hazy_ridge.get_width()):
			var pixel := hazy_ridge.get_pixel(x, y)
			var fogged := pixel.lerp(Color(profile.haze_color, pixel.a), 0.72)
			hazy_ridge.set_pixel(x, y, fogged)
	hazy_ridge.generate_mipmaps()
	textures["ridge-haze"] = ImageTexture.create_from_image(hazy_ridge)
	var landmark: Texture2D = load("res://assets/landmarks/island-far.png")
	var island := landmark.get_image()
	island.convert(Image.FORMAT_RGBA8)
	island = island.get_region(island.get_used_rect())
	island.generate_mipmaps()
	textures["island"] = ImageTexture.create_from_image(island)
	_split_clouds()
	for i in range(4):
		patches.append(_patch(8421 + i, false))
		low_patches.append(_patch(1829 + i, true))

func _split_clouds() -> void:
	var img: Image = images["cloud-strip"]
	var start := -1
	for x in range(img.get_width() + 1):
		var used := false
		if x < img.get_width():
			for y in range(img.get_height()):
				if img.get_pixel(x, y).a > 0.05:
					used = true
					break
		if used and start < 0:
			start = x
		elif not used and start >= 0:
			if x - start > 40:
				var part := img.get_region(Rect2i(start, 0, x - start, img.get_height()))
				part = part.get_region(part.get_used_rect())
				part.generate_mipmaps()
				clouds.append(ImageTexture.create_from_image(part))
			start = -1
	if clouds.is_empty():
		clouds.append(textures["cloud-strip"])

func _patch(seed_value: int, low: bool) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result := Image.create(768, 192 if not low else 110, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for i in range(85 if not low else 140):
		var keys := ["grass-1", "grass-1", "grass-4", "grass-4"]
		var key: String = keys[rng.randi_range(0, keys.size() - 1)]
		if not low and rng.randf() < 0.025:
			key = "grass-2"
		var src := (images[key] as Image).duplicate() as Image
		var h := rng.randi_range(44, 98) if not low else rng.randi_range(18, 43)
		var w := int(h * float(src.get_width()) / src.get_height() * (1.65 if low else 1.0))
		src.resize(maxi(w, 1), h, Image.INTERPOLATE_LANCZOS)
		if rng.randf() < 0.5:
			src.flip_x()
		var pos := Vector2i(rng.randi_range(-w, 768), rng.randi_range(result.get_height() / 3, result.get_height() - h))
		result.blend_rect(src, Rect2i(0, 0, w, h), pos)
		result.blend_rect(src, Rect2i(0, 0, w, h), pos + Vector2i(768, 0))
		result.blend_rect(src, Rect2i(0, 0, w, h), pos - Vector2i(768, 0))
	result = result.get_region(result.get_used_rect())
	result.generate_mipmaps()
	return ImageTexture.create_from_image(result)
