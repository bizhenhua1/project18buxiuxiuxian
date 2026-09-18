extends RefCounted

# Static cutout artwork often arrives without mip levels (unlike ForestBatch's
# generated atlas). The material retains this copy once per source texture.
static func mipmapped(texture:Texture2D)->Texture2D:
 # Animated preview targets must remain live. Reading them back here both
 # stalls the render thread and freezes an animation into a static mip copy.
 if texture is ViewportTexture:return texture
 var pixels:Image=texture.get_image()
 if pixels==null or pixels.is_empty() or pixels.has_mipmaps():return texture
 if pixels.is_compressed() and pixels.decompress()!=OK:return texture
 if pixels.generate_mipmaps()!=OK:return texture
 return ImageTexture.create_from_image(pixels)
