class_name SpaceAssets
extends RefCounted
var textures := {}
func texture(path: String) -> Texture2D:
	if path not in textures:
		var source: Texture2D = load(StyleLibrary.path(path))
		var image := source.get_image()
		image.convert(Image.FORMAT_RGBA8)
		if not path.ends_with("ground-tile.png"): image = image.get_region(image.get_used_rect())
		image.generate_mipmaps()
		textures[path] = ImageTexture.create_from_image(image)
	return textures[path]

var silhouettes := {}
static var shared_silhouettes := {}
func silhouette(texture_value: Texture2D, color: Color) -> Texture2D:
	var key := str(texture_value.get_instance_id()) + str(color)
	if shared_silhouettes.has(key): return shared_silhouettes[key]
	if key not in silhouettes:
		var source := texture_value.get_image().duplicate() as Image
		if source.has_mipmaps(): source.clear_mipmaps()
		for y in range(source.get_height()):
			for x in range(source.get_width()):
				source.set_pixel(x, y, Color(color, source.get_pixel(x,y).a))
		source.generate_mipmaps()
		silhouettes[key] = ImageTexture.create_from_image(source)
	return silhouettes[key]
