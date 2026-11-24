// Peau des personnages : texture d'origine, teinte de carnation, léger
// éclairage de diffusion (transmission) pour un rendu moins « plastique ».
shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap;
uniform vec3 tone = vec3(1.0);
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	ALBEDO = clamp(c * tone, 0.0, 1.0);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	ROUGHNESS = clamp(texture(rough_tex, UV).r * 1.05, 0.35, 1.0);
	SPECULAR = 0.35;
	BACKLIGHT = vec3(0.35, 0.12, 0.08) * 0.6;
	SSS_STRENGTH = 0.0;
}
