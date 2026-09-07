// Shared world-space lighting and low mist for ground and upright scenery.
uniform bool lantern_enabled=false;
uniform vec3 lantern_position;
uniform vec3 enemy_light_position;
uniform float enemy_light_strength=0.0;
uniform float atmosphere_time=0.0;
vec3 lantern_atmosphere(vec3 color,vec3 point,float distance_view){
    vec3 delta=point-lantern_position;
    float pool=exp(-dot(delta,delta)/(105.0*105.0));
    float flicker=.97+.025*sin(atmosphere_time*7.1)+.015*sin(atmosphere_time*11.7);
    vec3 enemy_delta=point-enemy_light_position;
    float enemy_pool=exp(-dot(enemy_delta,enemy_delta)/(100.0*100.0))*enemy_light_strength;
    vec3 illumination=vec3(.27,.34,.43)+vec3(.55,.48,.35)*pool*flicker+vec3(.40,.49,.53)*enemy_pool;
    float ground_light=exp(-max(point.y,0.0)*.09);
    illumination+=ground_light*(vec3(.65,.43,.18)*pool*pool+vec3(.55,.72,.82)*enemy_pool*enemy_pool);
    vec3 lit=color*illumination;
    lit+=ground_light*(vec3(.035,.024,.008)*pool*pool+vec3(.022,.045,.055)*enemy_pool*enemy_pool);
    float drift=.5+.25*sin(point.x*.023+point.z*.012+atmosphere_time*.18)
                    +.25*sin(point.z*.031-point.x*.009-atmosphere_time*.13);
    float low=exp(-max(point.y,0.0)*.055);
    float fog=smoothstep(20.0,440.0,distance_view)*(.20+.46*drift*low);
    vec3 mist=mix(vec3(.11,.155,.175),vec3(.185,.185,.17),pool*.35);
    return mix(lit,mist,clamp(fog,0.0,.58));
}
