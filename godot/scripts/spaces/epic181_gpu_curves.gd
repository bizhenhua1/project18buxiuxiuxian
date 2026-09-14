extends RefCounted
static var cache:Dictionary={}
static var noise_cache:Dictionary={}
static func prepare_noise(curves:Array)->Dictionary:
 var key:=str(curves)
 if noise_cache.has(key):return noise_cache[key]
 var counts:=Vector2(curves[0].size(),curves[1].size())
 var pixels:=Image.create(int(maxf(counts.x,counts.y)),1,false,Image.FORMAT_RGBAF)
 for x in pixels.get_width():pixels.set_pixel(x,0,Color(curves[0][mini(x,int(counts.x)-1)],curves[1][mini(x,int(counts.y)-1)],0,0))
 var result:={"texture":ImageTexture.create_from_image(pixels),"counts":counts}
 noise_cache[key]=result;return result
static func prepare(size:Array,gradient:Array)->Dictionary:
 var key:=str(size)+str(gradient)
 if cache.has(key):return cache[key]
 var counts:=Vector4(size[0].size(),size[1].size(),gradient[0].size(),gradient[1].size())
 var width:=int(maxf(maxf(counts.x,counts.y),maxf(counts.z,counts.w)))
 var pixels:=Image.create(width,3,false,Image.FORMAT_RGBAF)
 for x in width:
  pixels.set_pixel(x,0,Color(size[0][mini(x,int(counts.x)-1)],size[1][mini(x,int(counts.y)-1)],0,0))
  for row in 2:
   var c:Array=gradient[row][mini(x,gradient[row].size()-1)]
   pixels.set_pixel(x,row+1,Color(c[0],c[1],c[2],c[3]))
 var result:={"texture":ImageTexture.create_from_image(pixels),"counts":counts}
 cache[key]=result;return result
