// Rest-pose height keeps the luminous front tied to transformation/health,
// even when the character crouches. Visible surface halo also works without bloom.
vec2 transformation_edge(float height, float line, float amount) {
 float active = step(0.001, amount) * step(amount, 0.999);
 float distance_to_front = abs(height - line);
 float aa = max(fwidth(height), 0.0005);
 float core = 1.0 - smoothstep(0.003, 0.003 + aa, distance_to_front);
 float halo = 1.0 - smoothstep(0.004, 0.022 + aa, distance_to_front);
 return vec2(core, halo) * active;
}
