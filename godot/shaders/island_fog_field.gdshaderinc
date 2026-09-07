float fog_hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float fog_noise(vec2 p) {
	vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(fog_hash(i),fog_hash(i+vec2(1,0)),f.x),mix(fog_hash(i+vec2(0,1)),fog_hash(i+vec2(1,1)),f.x),f.y);
}
float fog_density(vec2 p,float time) {
	return fog_noise(p*3.8+vec2(time*0.035,-time*0.022));
}
vec3 fog_color(vec2 p,float time) {
	float detail=fog_noise(p*8.0+vec2(-time*0.028,time*0.013));
	return mix(vec3(0.19,0.29,0.29),vec3(0.47,0.57,0.52),fog_density(p,time)*0.7+detail*0.3);
}
