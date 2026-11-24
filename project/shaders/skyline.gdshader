// Silhouettes lointaines : couleur de façade + fenêtres dessinées, sans éclairage
// (la brume atmosphérique s'en charge). Coût minimal.
shader_type spatial;
render_mode unshaded, cull_back;
uniform vec3 wall_a : source_color = vec3(0.30, 0.30, 0.33);
uniform vec3 wall_b : source_color = vec3(0.40, 0.37, 0.35);
uniform vec3 sun_side : source_color = vec3(1.08, 1.0, 0.9);
global uniform float nuit;
void fragment() {
	float jour = 1.0 - 0.86 * nuit;
	if (COLOR.b > 0.5) { ALBEDO = wall_a * 0.7 * jour; }
	else {
		vec3 wall = mix(wall_a, wall_b, COLOR.r);
		vec2 g = UV / vec2(2.4, 3.2);
		vec2 f = fract(g);
		float win = step(0.22, f.x) * step(f.x, 0.78) * step(0.25, f.y) * step(f.y, 0.85);
		float lit = step(0.86, fract(sin(dot(floor(g) + COLOR.r * 91.0, vec2(12.9898, 78.233))) * 43758.5453));
		vec3 glass = mix(vec3(0.13, 0.15, 0.19), vec3(0.55, 0.50, 0.40), lit * 0.4);
		vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float shade = 0.82 + 0.18 * clamp(dot(n, normalize(vec3(-0.5, 0.4, 0.6))), 0.0, 1.0);
		ALBEDO = mix(wall, glass, win * 0.85) * shade * mix(sun_side, vec3(0.35, 0.42, 0.6), nuit) * jour;
		ALBEDO += vec3(1.0, 0.72, 0.4) * win * step(0.62, fract(sin(dot(floor(g) + COLOR.r * 57.0, vec2(39.3, 11.1))) * 9631.7)) * nuit * 0.9;
	}
}
