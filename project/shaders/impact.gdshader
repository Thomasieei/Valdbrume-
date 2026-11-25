// Choc d'impact façon anime : étoile de traits fins + anneau, très bref, additif.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, depth_test_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float progress = 0.0;     // 0 -> 1
uniform float seed = 0.0;
uniform bool flat_ring = false;   // onde au sol
float h(float x) { return fract(sin(x * 91.7 + seed * 13.1) * 43758.5); }
void vertex() {
	if (!flat_ring) {
		// face toujours la caméra
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
	}
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float fade = 1.0 - smoothstep(0.55, 1.0, progress);
	float c = 0.0;
	if (flat_ring) {
		float rr = mix(0.15, 1.0, sqrt(progress));
		c = smoothstep(0.08, 0.0, abs(r - rr)) * fade * 0.9;
		c += smoothstep(rr, 0.0, r) * 0.12 * fade;
	} else {
		// traits rayonnants de longueurs variées
		float n = 14.0;
		float k = floor((a / 6.2831 + 0.5) * n);
		float len = mix(0.45, 1.0, h(k)) * mix(0.35, 1.0, sqrt(progress));
		float ang = abs(fract((a / 6.2831 + 0.5) * n) - 0.5);
		float spike = smoothstep(0.16 * (1.0 - r / max(len, 0.01)), 0.0, ang) * step(r, len) * step(0.12 + progress * 0.35, r);
		float ring = smoothstep(0.05, 0.0, abs(r - mix(0.2, 0.85, progress))) * 0.8;
		float core = smoothstep(0.35 * (1.0 - progress), 0.0, r) * 1.6;
		c = (spike + ring + core) * fade;
	}
	ALBEDO = color.rgb * c * 2.2;
}
