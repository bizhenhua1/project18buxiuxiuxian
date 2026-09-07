class_name IslandMaterialLibrary
extends RefCounted
## Isolated GPU textures prevent mip levels from averaging adjacent atlas materials.
static var cache := {}
static func texture_pair(atlas_path: String, row: int) -> Array[Texture2D]:
	var key := "%s:%d" % [atlas_path,row]
	if cache.has(key): return cache[key]
	var source: Texture2D = load("res://"+atlas_path)
	var image := source.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var pair: Array[Texture2D] = []
	for column in range(2):
		var start := Vector2i(roundi(float(column)*image.get_width()/2),roundi(float(row)*image.get_height()/4))
		var end := Vector2i(roundi(float(column+1)*image.get_width()/2),roundi(float(row+1)*image.get_height()/4))
		# Discard the generated sheet's faint divider; mipmap each region independently.
		var region := image.get_region(Rect2i(start+Vector2i(2,2),end-start-Vector2i(4,4)))
		region.generate_mipmaps()
		pair.append(ImageTexture.create_from_image(region))
	cache[key] = pair
	return pair
