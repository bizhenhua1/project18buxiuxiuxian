class_name IslandAssets
extends RefCounted
const SHROUD := "assets/world/sky/shroud_base.png"
const HERO := "assets/style-e/style-e-char-daotong.png"
var textures := {}
var diamonds := {}
func texture(path: String) -> Texture2D:
	if not textures.has(path):
		var source: Texture2D = load(StyleLibrary.path("res://"+path))
		var image := source.get_image()
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		textures[path] = ImageTexture.create_from_image(image)
	return textures[path]
func diamond_uv(path: String) -> PackedVector2Array:
	if StyleLibrary.active:
		return PackedVector2Array([Vector2(.5,0),Vector2(1,.5),Vector2(.5,1),Vector2(0,.5)])
	if not diamonds.has(path):
		var image := texture(path).get_image()
		var min_x := image.get_width()
		var max_x := 0
		var widest := 0
		var equator := image.get_height()*129.0/320
		for y in range(0,image.get_height(),2):
			var lo := image.get_width()
			var hi := -1
			for x in range(image.get_width()):
				if image.get_pixel(x,y).a > 10.0/255:
					lo = mini(lo,x)
					hi = maxi(hi,x)
			if hi >= 0:
				min_x = mini(min_x,lo)
				max_x = maxi(max_x,hi)
				if hi-lo > widest:
					widest = hi-lo
					equator = y
		var half_w := maxf(1,max_x-min_x+1)/2
		var half_h := half_w*0.5
		var center := image.get_width()/2.0
		var size := Vector2(image.get_width(),image.get_height())
		diamonds[path] = PackedVector2Array([Vector2(center,equator-half_h)/size,Vector2(center+half_w,equator)/size,Vector2(center,equator+half_h)/size,Vector2(center-half_w,equator)/size])
	return diamonds[path]
static func side_colors(path: String) -> Array[Color]:
	if StyleLibrary.active: return [Color("37414d"),Color("2b3540")]
	if "water_" in path: return [Color("24525c"),Color("163840")]
	if "rock_" in path: return [Color("4a4640"),Color("2e2c28")]
	if "shroud" in path: return [Color("3c3e44"),Color("26282c")]
	return [Color("5a3f2c"),Color("3a281c")]
