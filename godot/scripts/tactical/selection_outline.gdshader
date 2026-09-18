shader_type canvas_item;
uniform sampler2D mask_image : filter_linear,repeat_disable;
uniform vec2 texel=vec2(.001);
uniform int style=1;
uniform float edge_width=1.5;
uniform float effect_time=0.0;
void fragment(){
 float center=texture(mask_image,UV).a;
 float rim=0.0;
 float halo=0.0;
 for(int i=0;i<16;i++){
  float angle=float(i)*6.2831853/16.0;
  vec2 direction=vec2(cos(angle),sin(angle))*texel;
  rim=max(rim,texture(mask_image,UV+direction*edge_width).a);
  if(style!=0){
   halo+=texture(mask_image,UV+direction*4.0).a*.65;
   halo+=texture(mask_image,UV+direction*8.0).a*.35;
  }
 }
 float edge=max(0.0,rim-center);
 halo=halo/16.0*(1.0-center);
 vec3 color=vec3(.84,.90,.88);
 float alpha=edge*.85;
 vec2 pixel=UV/texel;
 if(style==1){
  float flow=.5+.5*sin(pixel.y*.045+pixel.x*.018-effect_time*1.4);
  color=mix(vec3(.48,.31,.11),vec3(1.0,.86,.53),flow);
  alpha=edge*(.65+.3*flow)+halo*.65;
 }else if(style==2){
  float breath=.72+.18*sin(effect_time*1.6);
  color=vec3(.50,.86,.78);
  alpha=edge*.48+halo*1.65*breath;
 }else if(style==3){
  float ember=pow(.5+.5*sin(pixel.y*.075-pixel.x*.03+effect_time*2.0),10.0);
  color=mix(vec3(.48,.10,.16),vec3(1.0,.57,.27),ember);
  alpha=edge*(.7+.3*ember)+halo*(.5+ember);
 }
 COLOR=vec4(color,clamp(alpha,0.0,.95));
}
