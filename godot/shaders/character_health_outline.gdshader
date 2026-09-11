shader_type spatial;
render_mode unshaded,cull_front;
uniform float width=.008;
uniform vec4 ink_color : source_color=vec4(.015,.022,.028,1);
uniform sampler2D base_texture : source_color,filter_linear_mipmap;
uniform bool textured=true;
uniform float opacity=1.0;
void vertex(){VERTEX+=NORMAL*width;}
uniform float health_progress=0.0;
void fragment(){
 if(health_progress>=1.0 || (health_progress>0.0 && UV2.x<mix(-.02,1.02,health_progress)))discard;
 if(opacity<.3 || (textured && texture(base_texture,UV).a*opacity<.3))discard;
 ALBEDO=ink_color.rgb;
}
