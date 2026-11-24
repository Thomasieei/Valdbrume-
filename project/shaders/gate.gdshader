// Portail (Gate) : ovale vertical d'énergie en spirale, bord incandescent,
// cœur sombre et profond. Couleur selon le rang (bleu = rang E).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 col_a : source_color = vec3(0.25, 0.55, 1.0);
uniform vec3 col_b : source_color = vec3(0.55, 0.85, 1.0);
uniform float open = 1.0;       // 0 = fermé, 1 = ouvert
uniform float instab = 0.0;     // 1 = sur le point de se briser

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }

void fragment() {
	vec2 p = (UV - 0.5) * vec2(2.0, 2.0);
	float r = length(p) * 1.12;                       // l'ovale suit les proportions du quad (plus haut que large)
	float ang = atan(p.y, p.x);
	float t = TIME * (0.35 + instab * 0.8);
	// spirale : on enroule les coordonnées autour du centre
	float sw = ang + r * 5.0 - t * 3.0;
	vec2 q = vec2(cos(sw), sin(sw)) * r * 3.0;
	float n = fbm(q + vec2(t, -t * 0.7));
	float n2 = fbm(p * 4.0 - vec2(0.0, t * 2.0));
	float rr = r / max(open, 0.001);
	float rim = smoothstep(1.0, 0.86, rr) * (1.0 - smoothstep(0.86, 0.6, rr));
	float body = smoothstep(1.0, 0.88, rr + (n2 - 0.5) * 0.08);
	vec3 c = mix(vec3(0.01, 0.015, 0.04), col_a * 0.9, smoothstep(0.15, 0.9, n) * (0.35 + 0.65 * rr));
	c += col_b * pow(n, 3.0) * 1.6 * rr;
	c += mix(col_b, vec3(1.0), 0.4) * rim * (2.2 + instab * 2.0 + 0.6 * sin(TIME * 7.0 + ang * 3.0));
	// étincelles au bord
	float sp = step(0.93, noise(vec2(ang * 9.0, t * 6.0))) * smoothstep(1.06, 0.95, rr) * smoothstep(0.88, 0.97, rr);
	c += vec3(1.0) * sp * 3.0;
	c = mix(col_b * 1.6, c, body);
	ALBEDO = c;
	float halo = smoothstep(1.25, 1.0, rr) * 0.35 * (1.0 - body);
	ALPHA = clamp(body + halo + sp, 0.0, 1.0);
}
