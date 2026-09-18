shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform int surface_kind=0;
uniform bool circular=false;
uniform vec4 tint : source_color=vec4(.5,.86,.72,1);
uniform vec2 extent=vec2(1);
void fragment(){
 vec2 p=UV*2.0-1.0;
 float alpha=0.0;
 if(surface_kind==1){
  float fade=pow(1.0-UV.y,2.6);
  float rise=.5+.5*sin(UV.y*19.0-TIME*1.8);
  alpha=fade*(.12+.10*rise);
 }else if(surface_kind==2){
  float r=length(p);
  alpha=(1.0-smoothstep(.90,1.0,r))*smoothstep(.72,.82,r)*.85;
 }else{
  float distance_edge=circular ? (1.0-length(p))*min(extent.x,extent.y)*.5 : min(min(UV.x,1.0-UV.x)*extent.x,min(UV.y,1.0-UV.y)*extent.y);
  if(distance_edge<0.0)discard;
  float border=1.0-smoothstep(.015,.05,distance_edge);
  float pattern=1.0-smoothstep(.025,.06,abs(fract((UV.x*extent.x+UV.y*extent.y)*2.0)-.5));
  alpha=.07+pattern*.07+border*.58;
 }
 ALBEDO=tint.rgb;ALPHA=alpha*tint.a;
}
