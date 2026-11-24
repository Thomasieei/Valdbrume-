// Vêtements générés : découpe nette (ourlets, manches, ouverture de veste)
// en pose de repos, et détails cousus calculés : coutures, fermeture éclair,
// col, poignets, ceinture, poches, surpiqûres du jean, trame du tissu.
// Position de repos (pose en T) stockée dans la couleur de sommet.
shader_type spatial;
render_mode cull_disabled;
uniform vec3 color : source_color = vec3(0.5);
uniform int fabric = 0;          // 0 coton, 1 jean, 2 cuir, 3 laine, 4 toile, 5 nylon
uniform int garment = 0;         // 0 haut, 1 bas, 2 chaussures, 3 tablier, 4 sous-couche
uniform int style = 0;           // 0 simple, 1 veste, 2 costume, 3 blouse, 4 chemise, 5 pull, 6 combinaison, 7 bottes
uniform vec3 accent : source_color = vec3(0.1);
uniform float xmax = 9.0;
uniform float ymin = -9.0;
uniform float ymax = 9.0;
uniform float zmin = -9.0;
uniform float open_w = 0.0;
uniform float open_y = 9.0;
uniform float belt = 1.0;
varying vec3 rest;
void vertex() {
	rest = vec3(UV2.x, UV2.y, COLOR.b - 0.5);
}
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float band(float v, float c, float w) { return 1.0 - smoothstep(0.0, w, abs(v - c)); }
void fragment() {
	vec3 r = rest;
	float ax = abs(r.x);
	// découpe nette
	if (ax > xmax || r.y < ymin || r.y > ymax || r.z < zmin) discard;
	if (open_w > 0.0 && r.z > 0.0 && ax < open_w && r.y > open_y) discard;
	vec3 c = color;
	float rough = 0.85;
	float metal = 0.0;
	// trame du tissu (dans l'espace UV du corps)
	vec2 q = UV * vec2(900.0, 900.0);
	float weave = (sin(q.x) * sin(q.y)) * 0.5 + 0.5;
	float n = hash(floor(UV * 400.0));
	if (fabric == 1) {        // jean : diagonale + délavé
		float d = sin((UV.x + UV.y) * 1400.0) * 0.5 + 0.5;
		c *= 0.86 + 0.16 * d + 0.06 * n;
		c = mix(c, c * 1.35 + vec3(0.03), smoothstep(0.75, 1.0, hash(floor(UV * 30.0))) * 0.25);
	} else if (fabric == 2) { // cuir : grain + brillance
		c *= 0.9 + 0.12 * n; rough = 0.42;
	} else if (fabric == 3) { // laine : maille
		c *= 0.88 + 0.16 * weave; rough = 0.95;
	} else if (fabric == 5) { // nylon : léger brillant
		c *= 0.95 + 0.06 * weave; rough = 0.5;
	} else {
		c *= 0.93 + 0.08 * weave + 0.03 * n;
	}
	// coutures latérales et d'épaule
	float seam = 0.0;
	if (garment == 0 || garment == 4) {
		seam = max(band(r.z, 0.0, 0.0035) * step(ax, 0.22), band(r.y, 1.42, 0.003) * step(0.10, ax));
		// col / poignets / ourlet : bandes plus sombres
		float rib = max(band(r.y, ymax, 0.018), band(ax, xmax, 0.022));
		rib = max(rib, band(r.y, ymin, 0.02));
		c = mix(c, c * 0.72, rib * 0.85);
		if (style == 1 || style == 2) {    // veste : fermeture / revers
			float edge = band(ax, open_w, 0.012) * step(0.0, r.z) * step(open_y, r.y);
			c = mix(c, accent, edge);
			metal = edge * 0.6;
		}
		if (style == 4) {                   // chemise : patte de boutonnage + boutons
			float pl = band(r.x, 0.0, 0.012) * step(0.0, r.z);
			c = mix(c, c * 0.9, pl);
			float bt = pl * step(0.6, fract(r.y * 12.0)) * step(fract(r.y * 12.0), 0.75);
			c = mix(c, vec3(0.85), bt);
		}
		if (style == 6) {                   // combinaison : poche poitrine
			float pk = step(0.06, r.x) * step(r.x, 0.15) * step(1.30, r.y) * step(r.y, 1.38) * step(0.0, r.z);
			c = mix(c, c * 0.82, pk);
		}
	} else if (garment == 1) {
		seam = band(r.z, 0.0, 0.004);
		// ceinture
		float bl = step(belt - 0.035, r.y) * step(r.y, belt + 0.012);
		c = mix(c, vec3(0.07, 0.05, 0.04), bl);
		float buckle = bl * step(ax, 0.025) * step(0.0, r.z);
		c = mix(c, vec3(0.65, 0.6, 0.5), buckle); metal = buckle;
		rough = mix(rough, 0.5, bl);
		// poches arrière et braguette (jean)
		float pocket = step(0.04, ax) * step(ax, 0.14) * step(belt - 0.18, r.y) * step(r.y, belt - 0.06) * step(r.z, -0.02);
		c = mix(c, c * 0.85, pocket * 0.8);
		if (fabric == 1) c = mix(c, vec3(0.78, 0.55, 0.25), band(ax, 0.04, 0.002) * step(r.z, -0.02) * step(belt - 0.18, r.y) * step(r.y, belt - 0.06));
		c = mix(c, c * 0.75, band(r.y, ymin, 0.015));   // ourlet
	} else if (garment == 2) {
		// semelle claire / foncée, lacets
		float sole = step(r.y, 0.028);
		c = mix(c, style == 7 ? vec3(0.05) : vec3(0.92), sole);
		rough = mix(0.55, 0.8, sole);
		c = mix(c, c * 0.6, band(r.y, ymax, 0.012));
	} else if (garment == 3) {
		c = mix(c, c * 0.8, max(band(r.y, ymin, 0.01), band(ax, xmax, 0.01)));
	}
	c = mix(c, c * 0.6, seam);
	ALBEDO = c;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.3;
}
