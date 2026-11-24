// Vitres réelles (rez-de-chaussée) : pièce factice + reflet du ciel.
shader_type spatial;
render_mode cull_back;
#include "res://shaders/interior.gdshaderinc"
uniform float lit_energy = 0.55;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 right = normalize(cross(-n, vec3(0.0, 1.0, 0.0)));
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 vts = vec3(dot(v, right), v.y, dot(v, n));
	vec3 room = fake_room(UV, vts, COLOR.rgb);
	ALBEDO = vec3(0.02);
	EMISSION = room * (COLOR.g > 0.5 ? lit_energy : lit_energy * 0.6);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
