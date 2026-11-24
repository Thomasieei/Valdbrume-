// Eau du bassin : opaque (aucun coût de transparence), vagues douces,
// reflets du ciel par le fresnel, teinte profonde.
shader_type spatial;
render_mode cull_back;
uniform vec3 deep : source_color = vec3(0.035, 0.10, 0.12);
uniform vec3 shallow : source_color = vec3(0.10, 0.24, 0.26);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	vec2 g = vec2(0.0);
	g += vec2(cos(p.x * 0.9 + t * 1.1), cos(p.y * 0.8 - t * 0.9)) * 0.06;
	g += vec2(cos((p.x + p.y) * 1.9 - t * 1.7), cos((p.x - p.y) * 2.1 + t * 1.4)) * 0.035;
	g += vec2(cos(p.y * 4.3 + t * 2.3), cos(p.x * 3.7 - t * 2.1)) * 0.015;
	vec3 nw = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	float edge = clamp(min(19.0 - abs(p.x), 19.0 - abs(p.y)) / 6.0, 0.0, 1.0);
	ALBEDO = mix(shallow, deep, edge * (0.5 + 0.5 * v.y));
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.55;
}
