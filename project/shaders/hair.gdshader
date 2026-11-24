// Cheveux : texture de mèches teintée, reflet anisotrope approché.
shader_type spatial;
render_mode cull_disabled;
uniform sampler2D strands : source_color, filter_linear_mipmap;
uniform sampler2D strands_n : hint_normal, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.2, 0.12, 0.08);
void fragment() {
	vec3 s = texture(strands, UV).rgb;
	float l = dot(s, vec3(0.333));
	ALBEDO = tint * (0.55 + l * 0.9);
	NORMAL_MAP = texture(strands_n, UV).rgb;
	ROUGHNESS = 0.55;
	SPECULAR = 0.45;
}
