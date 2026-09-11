shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void vertex(){ MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]); }
void fragment(){
 vec2 p=UV; float tip=1.0-p.y;
 float center=.5+sin(p.y*9.0+TIME*5.0)*.07*tip;
 float width=mix(.025,.42,p.y);
 float shape=(1.0-smoothstep(width*.45,width,abs(p.x-center)))*smoothstep(0.0,.18,p.y)*(1.0-smoothstep(.72,1.0,p.y));
 ALBEDO=COLOR.rgb; ALPHA=shape*COLOR.a;
}
