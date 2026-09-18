// Preserve authored interior pixels. Blend only the non-tileable edge strips
// against a half-tile-shifted copy; no reflection, per-frame noise or extra assets.
vec3 fairytale_floor_sample(sampler2D source, vec2 uv, bool blend_edges) {
    if(!blend_edges)return texture(source,uv).rgb;
    vec2 p=fract(uv);
    vec2 w=smoothstep(vec2(0.0),vec2(.14),min(p,1.0-p));
    vec2 dx=dFdx(uv);vec2 dy=dFdy(uv);
    vec3 a=textureGrad(source,p,dx,dy).rgb;
    vec3 b=textureGrad(source,fract(p+vec2(.5,0)),dx,dy).rgb;
    vec3 c=textureGrad(source,fract(p+vec2(0,.5)),dx,dy).rgb;
    vec3 d=textureGrad(source,fract(p+vec2(.5)),dx,dy).rgb;
    return mix(mix(d,c,w.x),mix(b,a,w.x),w.y);
}
