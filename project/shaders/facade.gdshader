// Façades imprimées des étages : 2 triangles par module, aspect du vrai module.
// Atlas : albedo (+relief en alpha), normales xy + classe de teinte + vitre,
// coordonnées de pièce. Teintes : mur (couleur de sommet), pierre et accent
// (palette, index en UV2).
shader_type spatial;
render_mode cull_back;
#include "res://shaders/interior.gdshaderinc"
uniform sampler2D atlas_albedo : source_color, filter_linear_mipmap;
uniform sampler2D atlas_nc : filter_linear_mipmap;
uniform sampler2D atlas_room : filter_linear_mipmap;
uniform vec3 palette[16];
uniform float lit_energy = 0.7;
uniform vec2 relief_scale = vec2(0.0546, 0.09);   // pixels/m / taille de l'atlas
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 n0 = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 r0 = normalize(cross(-n0, vec3(0.0, 1.0, 0.0)));
	vec3 v0 = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 vt = vec3(dot(v0, r0), v0.y, dot(v0, n0));
	// relief : les moulures en saillie se décalent avec le regard (≤ 12 cm)
	float h = texture(atlas_albedo, UV).a * 0.6 - 0.3;
	vec2 off = clamp(vt.xy / max(vt.z, 0.35) * h, vec2(-0.12), vec2(0.12));
	vec2 uv = UV + vec2(off.x, -off.y) * relief_scale;
	vec4 a = texture(atlas_albedo, uv);
	vec4 nc = texture(atlas_nc, uv);
	float cls = nc.b * 3.0;
	vec3 tint = vec3(1.0);
	if (cls > 0.5 && cls < 1.5) tint = COLOR.rgb * 2.0;
	else if (cls >= 1.5 && cls < 2.5) tint = palette[int(UV2.x)];
	else if (cls >= 2.5) tint = palette[int(UV2.y)];
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 right = normalize(cross(-n, vec3(0.0, 1.0, 0.0)));
	vec2 nxy = nc.rg * 2.0 - 1.0;
	vec3 nw = normalize(right * nxy.x + vec3(0.0, 1.0, 0.0) * nxy.y + n * sqrt(max(0.0, 1.0 - dot(nxy, nxy))));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	float glass = smoothstep(0.35, 0.65, nc.a);
	vec3 col = a.rgb * tint;
	ROUGHNESS = mix(0.85, 0.07, glass);
	SPECULAR = mix(0.35, 0.6, glass);
	if (glass > 0.01) {
		vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
		vec3 vts = vec3(dot(v, right), v.y, dot(v, n));
		// une pièce par travée de 2 m et par étage : paramètres pseudo-aléatoires stables
		vec2 cell = vec2(floor(dot(wpos.xz, right.xz) / 2.0 + 0.5), floor(wpos.y / 3.0));
		float h = hash12(cell + floor(wpos.xz * 0.01) * 17.0);
		vec3 p = vec3(fract(h * 7.0), step(0.38, h), fract(h * 13.0) < 0.45 ? 0.0 : fract(h * 31.0));
		vec2 ruv = texture(atlas_room, uv).rg;
		vec3 room = fake_room(ruv, vts, p);
		EMISSION = room * glass * (p.y > 0.5 ? lit_energy : lit_energy * 0.6);
		col = mix(col, vec3(0.02), glass);
	}
	ALBEDO = col;
	AO = clamp(0.55 + a.a * 0.9, 0.0, 1.0);
	AO_LIGHT_AFFECT = 0.6;
}
