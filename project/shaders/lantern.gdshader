// Verre des lanternes : laiteux le jour, chaude lumière la nuit (paramètre global « nuit »).
shader_type spatial;
render_mode cull_disabled;
global uniform float nuit;
void fragment() {
	ALBEDO = vec3(0.85, 0.82, 0.74);
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
	EMISSION = vec3(1.0, 0.72, 0.42) * (0.05 + 5.0 * nuit);
}
