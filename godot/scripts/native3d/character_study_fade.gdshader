shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform bool textured = true;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 shadow_color : source_color = vec4(.15,.20,.26,1);
uniform float threshold = .45;
uniform float softness = .06;
uniform float ambient = .25;
uniform float environment_fill = 0.0;
uniform vec4 environment_fill_color : source_color = vec4(.596,.686,.749,1.0);
uniform float saturation = .8;
uniform int style = 1;
uniform float ink = .3;
varying vec2 screen_uv;
uniform float actor_opacity = 1.0;
void fragment(){
 if(fract(sin(dot(floor(FRAGCOORD.xy),vec2(12.9898,78.233)))*43758.5453)>=actor_opacity)discard;
 vec4 tex=base_color;
 if(textured)tex*=texture(base_texture,UV);
 if(tex.a<.3)discard;
 vec3 color=mix(vec3(dot(tex.rgb,vec3(.299,.587,.114))),tex.rgb,saturation);
 ALBEDO=color;
 ROUGHNESS=1.0;
 // Explicit fill keeps stylized shading while making the team ambient control effective.
 EMISSION=color*(shadow_color.rgb*ambient+environment_fill_color.rgb*environment_fill*.25);
 screen_uv=FRAGCOORD.xy;
}
void light(){
 float n=max(dot(NORMAL,LIGHT),0.0);
 float shade=smoothstep(threshold-softness,threshold+softness,n);
 if(style==2){
  float middle=smoothstep(.18,.26,n)*.38;
  shade=max(middle,shade);
  float hatch=step(.72,fract((screen_uv.x+screen_uv.y)*.13));
  shade*=1.0-hatch*ink*(1.0-shade);
 }else if(style==3){
  shade=mix(n,smoothstep(.15,.8,n),.55);
 }
 DIFFUSE_LIGHT+=ALBEDO*LIGHT_COLOR*ATTENUATION*mix(shadow_color.rgb*.2,vec3(1.0),shade)/3.14159265;
}
