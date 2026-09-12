shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D art : source_color;
uniform bool textured=false;
uniform float opacity=1.0;
void fragment(){
 if(opacity*(texture(art,UV).a*float(textured)+float(!textured))<0.35) discard;
 float depth=clamp(-VERTEX.z/100.0,0.0,0.9999);
 ALBEDO=vec3(floor(depth*255.0)/255.0,fract(depth*255.0),1.0);
}
