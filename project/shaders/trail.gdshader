// Traînée d'arme : ruban additif, brillant au bord tranchant, qui s'efface vers l'arrière.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.5, 0.8, 1.0, 1.0);
uniform float intensity = 2.2;

void fragment() {
	// UV.x : 0 = segment le plus récent, 1 = le plus ancien ; UV.y : 0 = garde, 1 = pointe
	float age = UV.x;
	float edge = smoothstep(0.15, 1.0, UV.y);
	float core = pow(edge, 3.0);
	float fade = (1.0 - age) * (1.0 - age);
	float streak = 0.75 + 0.25 * sin(UV.x * 40.0 - TIME * 30.0);
	vec3 c = mix(color.rgb, vec3(1.0), core * 0.7);
	float a = fade * edge * streak * COLOR.a;
	ALBEDO = c * a * intensity;
	ALPHA = 1.0;
}
