// Shared world-space lighting and low mist for ground and upright scenery.
uniform bool lantern_enabled=false;
uniform vec3 lantern_position;
uniform float team_light_energy=1.0;
uniform float team_light_radius=82.0;
uniform vec4 team_light_color : source_color=vec4(1.0);
uniform vec2 lantern_forward=vec2(0,1);
uniform vec3 enemy_light_position;
uniform float enemy_light_strength=0.0;
uniform vec4 environment_light_tint : source_color=vec4(1.0);
uniform vec4 enemy_scene_tint : source_color=vec4(1.0);
uniform float atmosphere_time=0.0;
#ifdef WORLD3D_SHARED_CLOCK
uniform bool shared_atmosphere_clock_enabled=false;
uniform sampler2D shared_atmosphere_clock : filter_nearest, repeat_disable;
float atmosphere_clock_time(){
    return shared_atmosphere_clock_enabled?texelFetch(shared_atmosphere_clock,ivec2(0),0).r:atmosphere_time;
}
#else
float atmosphere_clock_time(){return atmosphere_time;}
#endif
uniform vec4 combat_light_positions[4];
uniform vec4 combat_light_colors[4];
uniform int biome_kind=0;
uniform vec3 fairytale_mist_color=vec3(.075,.11,.14);
uniform vec4 biome_lights[4];
uniform vec4 biome_glow_color : source_color=vec4(.2,.7,1,1);
// Palette shared by depth haze and world-anchored cloud patches.
vec3 environment_mist(vec3 original){
    if(biome_kind>=6)return fairytale_mist_color;
    if(biome_kind==2)return vec3(.15,.28,.48);
    if(biome_kind==3 || biome_kind==5)return vec3(.12,.24,.115);
    if(biome_kind==4)return vec3(.29,.065,.08);
    return original;
}
// Material response for scenery only. Ink contours remain visible under the wet film.
vec3 environment_surface(vec3 color,vec3 point,vec2 uv){
    if(biome_kind!=3 && biome_kind!=4 && biome_kind!=5)return color;
    float value=dot(color,vec3(.299,.587,.114));
    float film=.5+.27*sin(point.x*.12+point.z*.067+sin(uv.y*19.0))+.23*sin(uv.x*39.0+uv.y*17.0);
    vec3 material=color;
    if(biome_kind==3 || biome_kind==5){
        material=mix(color*vec3(.61,.91,.67),value*vec3(.43,.76,.45),.30*film);
    }else{
        vec3 flesh=value*vec3(1.45,.46,.51);
        // The palest original ridges keep their ivory identity; folds take the flesh tone.
        float bone=smoothstep(.52,.83,value);
        material=mix(flesh,color*vec3(1.05,.82,.75),bone*.75);
    }
    vec3 lamp_delta=point-lantern_position;
    vec3 foe_delta=point-enemy_light_position;
    float light=.15+exp(-dot(lamp_delta,lamp_delta)/22500.0)*team_light_energy+.65*exp(-dot(foe_delta,foe_delta)/22500.0)*enemy_light_strength;
    float streak=pow(.5+.5*sin(uv.x*71.0+sin(uv.y*26.0)+sin(point.z*.07)+atmosphere_clock_time()*.13),18.0);
    float slick=smoothstep(.3,.67,value)*smoothstep(.4,.85,film)*streak;
    vec3 glint=biome_kind==4?vec3(.65,.34,.32):vec3(.32,.57,.39);
    return material+glint*slick*light*.38;
}
vec3 lantern_atmosphere(vec3 color,vec3 point,float distance_view){
    float effect_time=atmosphere_clock_time();
    vec3 delta=point-lantern_position;
    float pool=exp(-dot(delta,delta)/max(team_light_radius*team_light_radius,1.0));
    pool*=.18+.82*smoothstep(-15.0,35.0,dot(delta.xz,lantern_forward));
    float flicker=.97+.025*sin(effect_time*7.1)+.015*sin(effect_time*11.7);
    vec3 enemy_delta=point-enemy_light_position;
    float enemy_pool=exp(-dot(enemy_delta,enemy_delta)/(88.0*88.0))*enemy_light_strength;
    vec3 illumination=vec3(.115,.155,.215)*environment_light_tint.rgb+vec3(1.12,.99,.79)*team_light_color.rgb*team_light_energy*pool*flicker+vec3(.76,1.02,1.19)*enemy_scene_tint.rgb*enemy_pool;
    float ground_light=exp(-max(point.y,0.0)*.09);
    illumination+=ground_light*(vec3(.86,.66,.37)*team_light_color.rgb*team_light_energy*pool*pool+vec3(.72,.96,1.18)*enemy_scene_tint.rgb*enemy_pool*enemy_pool);
    vec3 lit=color*illumination;
    vec3 spell_scatter=vec3(0.0);
    for(int i=0;i<4;i++){
        vec3 d=point-combat_light_positions[i].xyz;
        float radius=max(1.0,combat_light_positions[i].w);
        float power=exp(-dot(d,d)/(radius*radius))*combat_light_colors[i].a;
        lit+=combat_light_colors[i].rgb*power*(color*1.8+vec3(.035));
        spell_scatter+=combat_light_colors[i].rgb*power*.10;
    }
    if(biome_kind>0){
        for(int i=0;i<4;i++){
            vec3 d=point-biome_lights[i].xyz;
            float r=biome_lights[i].w;
            float power=exp(-dot(d,d)/max(r*r,1.0))*step(1.0,r);
            lit+=biome_glow_color.rgb*power*(color*.65+.025)*(.88+.12*sin(effect_time*1.5+float(i)));
        }
    }
    lit+=ground_light*(vec3(.035,.024,.008)*team_light_color.rgb*team_light_energy*pool*pool+vec3(.022,.045,.055)*enemy_scene_tint.rgb*enemy_pool*enemy_pool);
    // Roll off intense highlights without lifting the surrounding blacks.
    lit=lit/(vec3(1.0)+max(lit-vec3(.55),vec3(0.0))*.8);
    float drift=.5+.25*sin(point.x*.023+point.z*.012+effect_time*.18)
                    +.25*sin(point.z*.031-point.x*.009-effect_time*.13);
    float low=exp(-max(point.y,0.0)*.055);
    float fog=smoothstep(20.0,440.0,distance_view)*(.13+.34*drift*low);
    vec3 mist=mix(environment_mist(vec3(.075,.11,.14))*(biome_kind>=2?.63:1.0),vec3(.185,.185,.17),clamp(pool*team_light_energy,0.0,1.0)*(biome_kind>=2?.15:.35));
    return mix(lit,mist+spell_scatter,clamp(fog,0.0,.48));
}
