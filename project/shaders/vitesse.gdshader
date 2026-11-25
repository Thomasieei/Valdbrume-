// traits de vitesse sur les bords de l'écran (free-run en pleine course)
shader_type canvas_item;
uniform float force = 0.0;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.78;
	float r = length(uv);
	float bord = smoothstep(0.42, 0.95, r);
	if (bord * force < 0.01) { discard; }
	float a = atan(uv.y, uv.x) / 6.2831853 + 0.5;
	float raie = floor(a * 180.0);
	float h = hash(raie);
	// chaque trait file vers l'extérieur, apparaît et disparaît vite
	float phase = fract(TIME * (1.6 + h * 2.2) + h * 9.0);
	float vivant = step(0.55, hash(raie + floor(TIME * 7.0 + h * 5.0) * 0.731));
	float le_long = smoothstep(phase - 0.25, phase, r * 1.1) * (1.0 - smoothstep(phase, phase + 0.05, r * 1.1));
	float fin = 1.0 - abs(fract(a * 180.0) - 0.5) * 2.0;
	float alpha = vivant * le_long * smoothstep(0.55, 1.0, fin) * bord * force * 0.5;
	COLOR = vec4(0.92, 0.95, 1.0, alpha);
}
