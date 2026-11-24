// Marquages au sol (passages piétons, lignes) : mélange alpha, sans écriture de profondeur.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform sampler2D decal_tex : source_color, filter_linear_mipmap_anisotropic;
void fragment() {
	vec4 c = texture(decal_tex, UV);
	ALBEDO = c.rgb * 0.92;
	ALPHA = c.a * 0.95;
	ROUGHNESS = 0.75;
}
