shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 hot_color : source_color = vec4(1.0,0.72,0.22,1.0);
uniform vec4 dark_color : source_color = vec4(0.45,0.045,0.008,1.0);
uniform float age = 0.0;
uniform float opacity = 1.0;
uniform bool ribbon = false;
uniform bool flame_tail = false;
varying vec3 point;
float hash(vec3 p){return fract(sin(dot(p,vec3(12.989,78.233,37.719)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){point=VERTEX;if(!ribbon){float n=noise(VERTEX*9.0+vec3(0,-age*6.0,age*2.0));VERTEX+=NORMAL*(n-.5)*.13;}}
void fragment(){
 float n=noise(point*16.0+vec3(0,-age*9.0,age*3.0));
 float fine=noise(point*39.0+age*2.0);
 if(flame_tail){
  float wave=noise(vec3(UV.x*7.0-age*12.0,UV.y*4.0,age));
  float edge=sin(UV.y*3.14159);
  float shape=smoothstep(.15,.7,edge-wave*.4)*pow(1.0-UV.x,.6);
  ALBEDO=mix(dark_color.rgb,hot_color.rgb,(1.0-UV.x)*(.6+.4*wave));
  ALPHA=shape*opacity;
 }else if(ribbon){
  float edge=sin(UV.y*3.14159);float tail=smoothstep(0.0,.32,UV.x);
  float hatch=step(.35,fract(UV.x*36.0+UV.y*7.0));
  ALBEDO=mix(dark_color.rgb,hot_color.rgb,smoothstep(.25,.8,UV.y));
  ALPHA=opacity*edge*tail*(.7+.3*hatch);
 }else{
  float heat=n*.75+fine*.25;
  ALBEDO=mix(dark_color.rgb,hot_color.rgb,smoothstep(.28,.73,heat));
  ALBEDO=mix(ALBEDO,vec3(1.0,.94,.67),smoothstep(.77,.88,heat));
  ALPHA=opacity*smoothstep(.15,.38,heat);
 }
}
