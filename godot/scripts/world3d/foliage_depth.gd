extends RefCounted
# Reuse the exact placement/lighting implementation, but submit foliage to
# depth-tested opaque rendering. MultiMesh alpha blending sorts whole batches.
static var cached:Shader
static func shader()->Shader:
 if cached!=null:return cached
 var source:String=load("res://scripts/world3d/cutout.gdshader").code
 var alpha_line:="ALPHA=tex.a*fade*mix(1.0,smoothstep(0.0,root_band*root_edge,root_clearance),root_blend);"
 assert(source.contains(alpha_line),"Foliage variant must track the shared cutout coverage expression")
 source=source.replace("depth_prepass_alpha","depth_draw_opaque")
 # Different foliage textures can share a precisely coplanar root plane.
 # Resolve those depth ties deterministically, not by submission order.
 source=source.replace("uniform float heading=0.0;","uniform float heading=0.0;\nuniform float foliage_depth_bias=0.0;")
 source=source.replace("depth=-VERTEX.z*20.0;","VERTEX.z+=foliage_depth_bias;depth=-VERTEX.z*20.0;")
 source=source.replace(alpha_line,"""
 float coverage=tex.a*fade*mix(1.0,smoothstep(0.0,root_band*root_edge,root_clearance),root_blend);
 // Stable artwork-space coverage: no frame seed, no moving screen-space noise.
 vec2 cell=floor(UV*vec2(textureSize(art,0)));
 float threshold=fract(sin(dot(cell,vec2(12.9898,78.233)))*43758.5453);
 if(coverage<=threshold)discard;
 """)
 cached=Shader.new();cached.code=source
 return cached
