// Surface-space ornament, shared by the editor and gameplay materials.
float occult_pattern(vec2 surface_uv, float rest_height, float clock, int expression) {
 if(expression==0)return .7+.3*sin(rest_height*100.0-clock*3.0);
 if(expression==1){
  vec2 grid=vec2(surface_uv.x*28.0,rest_height*24.0-clock*.32);
  vec2 cell=floor(grid);vec2 p=fract(grid)-.5;
  float seed=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
  float stem=(1.0-smoothstep(.025,.075,abs(p.x)))*(1.0-smoothstep(.29,.36,abs(p.y)));
  float arms=(1.0-smoothstep(.025,.065,abs(abs(p.y)-abs(p.x)*.8-.06)))*(1.0-smoothstep(.2,.3,abs(p.x)));
  float cross=(1.0-smoothstep(.025,.065,abs(p.y+.18)))*(1.0-smoothstep(.15,.23,abs(p.x)))*step(.4,seed);
  return .13+max(stem,max(arms,cross))*.95;
 }
 if(expression==2){
  float wave=sin(surface_uv.x*55.0+sin(rest_height*23.0-clock*.8)*2.0-rest_height*16.0);
  return .12+pow(max(0.0,wave),7.0)*.85;
 }
 float ink_wave=sin(surface_uv.x*34.0+sin(rest_height*18.0-clock*.28)*3.0)*sin(rest_height*31.0+surface_uv.x*8.0);
 return .10+pow(1.0-abs(ink_wave),13.0)*.8;
}
