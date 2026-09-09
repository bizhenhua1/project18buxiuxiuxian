shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float age=0.0;
uniform vec2 tile_center;
uniform float angle=0.0;
varying vec2 point;
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1)).xz;}
void fragment(){
 vec2 delta=point-tile_center;
 delta=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*delta;
 if(abs(delta.x)+abs(delta.y)>.49)discard;
 float radius=length(UV-.5)*2.0;
 float wave=.08+age*.53;
 float ring=exp(-pow((radius-wave)/.025,2.0))+.4*exp(-pow((radius-wave*.65)/.025,2.0));
 ALBEDO=vec3(.48,.72,.69);
 ALPHA=ring*(1.0-smoothstep(.35,1.0,radius))*smoothstep(.04,.18,radius)*(1.0-smoothstep(.3,1.5,age))*.65;
}
