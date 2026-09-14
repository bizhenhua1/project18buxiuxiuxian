shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float terrain_amplitude=1.0;
void vertex(){
 vec4 world=MODEL_MATRIX*vec4(VERTEX,1.0);
 vec2 p=vec2(world.x,-world.z)*20.0;
 world.y=(2.2*sin(p.y*.009)+1.3*sin(p.x*.017+p.y*.004))*terrain_amplitude/20.0+.06;
 VERTEX=(inverse(MODEL_MATRIX)*world).xyz;
}
void fragment(){ALBEDO=COLOR.rgb;ALPHA=COLOR.a;}
