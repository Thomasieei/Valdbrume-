// Surcouche des monstres : éclair blanc quand ils sont touchés, dissolution
// en braises violettes à la mort. Valeurs par instance (aucun matériau dupliqué).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
instance uniform float flash = 0.0;
instance uniform float dissolve = 0.0;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 c = vec3(1.0, 0.95, 0.9) * flash * (0.45 + 0.8 * rim);
	if (dissolve > 0.0) {
		float n = noise(lp * 6.0);
		float edge = 1.0 - smoothstep(0.0, 0.12, abs(n - dissolve));
		c += vec3(0.6, 0.3, 1.0) * edge * 3.0;
		if (n < dissolve - 0.02) c += vec3(0.0);
	}
	ALBEDO = c;
}
