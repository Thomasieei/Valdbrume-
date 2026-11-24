// Sol (chaussée, trottoirs) : filtrage anisotrope pour les angles rasants.
// Matériau des modules du kit : texture + ORM + normal map, teinte par sommet.
shader_type spatial;
render_mode cull_back;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 base_tint = vec3(1.0);
uniform float vertex_tint = 1.0;      // 1 : teinte stockée x0.5 dans la couleur
uniform float normal_strength = 1.0;
uniform float roughness_mul = 1.0;
void fragment() {
	vec3 t = mix(vec3(1.0), COLOR.rgb * 2.0, vertex_tint);
	ALBEDO = texture(albedo_tex, UV).rgb * t * base_tint;
	vec3 orm = texture(orm_tex, UV).rgb;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.5;
	ROUGHNESS = clamp(orm.g * roughness_mul, 0.0, 1.0);
	METALLIC = orm.b;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
