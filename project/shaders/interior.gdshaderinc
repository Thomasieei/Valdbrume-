// Intérieurs factices (« interior mapping » à partir d'une seule image) :
// la fenêtre montre une vraie pièce en perspective qui bouge avec le regard.
uniform sampler2D room_lit_a : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D room_lit_b : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D room_dark : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D curtains : source_color, filter_linear_mipmap, repeat_disable;
uniform float back_scale = 0.58;      // taille relative du mur du fond dans l'image
uniform float room_depth = 0.9;       // profondeur de la pièce (unités de largeur)

// uv : coordonnées sur la vitre (0..1, v vers le bas) ; vts : direction
// surface -> caméra dans le repère de la façade (x droite, y haut, z dehors).
// p : (type 0..1, allumée 0/1, rideaux 0..1). Renvoie rgb (pièce + rideau).
vec3 fake_room(vec2 uv, vec3 vts, vec3 p) {
	vec3 o = vec3(uv.x, 1.0 - uv.y, 0.0);
	vec3 d = -normalize(vts);
	d.z = min(d.z, -0.32);           // évite l'étirement aux angles rasants
	d.x = abs(d.x) < 1e-4 ? 1e-4 : d.x;
	d.y = abs(d.y) < 1e-4 ? 1e-4 : d.y;
	vec3 inv = 1.0 / d;
	float tx = d.x > 0.0 ? (1.0 - o.x) * inv.x : -o.x * inv.x;
	float ty = d.y > 0.0 ? (1.0 - o.y) * inv.y : -o.y * inv.y;
	float tz = -room_depth * inv.z;
	float t = min(min(tx, ty), tz);
	vec3 h = o + d * t;
	float s = clamp(-h.z / room_depth, 0.0, 1.0);
	float k = 1.0 / (1.0 + s * (1.0 / back_scale - 1.0));
	vec2 img = 0.5 + (h.xy - 0.5) * k;
	img.y = 1.0 - img.y;
	img = clamp(img, vec2(0.002), vec2(0.998));
	vec3 c;
	if (p.y > 0.5) {
		c = p.x < 0.34 ? texture(room_lit_a, img).rgb : (p.x < 0.67 ? texture(room_lit_b, img).rgb : texture(room_lit_a, vec2(1.0 - img.x, img.y)).rgb);
	} else {
		c = texture(room_dark, img).rgb * 0.55;
	}
	// rideaux / stores (sur la vitre) : 0 = aucun
	if (p.z > 0.2) {
		vec2 q = uv * 0.5 + vec2(0.0, p.z > 0.6 ? 0.5 : 0.0);   // rideaux ouverts / panneaux
		vec4 cu = texture(curtains, q);
		c = mix(c, cu.rgb * (p.y > 0.5 ? 1.25 : 0.6), cu.a);
	}
	return c;
}

float hash12(vec2 q) {
	vec3 p3 = fract(vec3(q.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}
