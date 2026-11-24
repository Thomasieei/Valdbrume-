"""Graphe de déplacement des habitants : milieu des trottoirs, angles de rue,
passages piétons, ruelles et place du Portail. Plus les lieux de vie
(domiciles, lieux de travail, bancs), choisis à la main."""
import math
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import streets

PLACES = {
 # nom : (x, z, orientation en degrés vers laquelle le personnage regarde, intérieur ?)
 'boulangerie':   (-250.5, -64.0, 90, False),     # devanture av. de l'Ouest (Léa)
 'pharmacie':     (-7.5, -96.0, 270, False),      # av. du Portail (Inès)
 'garage':        (151.5, 84.0, 90, False),       # rue des Arches (Karim)
 'cafe':          (-74.0, 10.5, 0, False),        # terrasse sur le Grand Boulevard (Théo)
 'fleuriste':     (-30.0, 30.0, 315, False),      # angle sud-ouest de la place (Sofia)
 'gare':          (-369.0, -9.0, 270, False),      # entrée de la Gare de l'Ouest (Marc)
 'redaction':     (66.0, 121.5, 180, False),      # av. du Sud (Chloé)
 'tour':          (369.0, 9.0, 90, False),       # pied de la Tour Valdbrume (Victor)
 'commissariat':  (-7.5, -205.0, 180, False),    # Hôtel de Ville (Nadia)
 'banc_place_s':  (-8.0, 19.55, 0, False),         # rebord du bassin, côté sud
 'banc_place_n':  (8.0, -19.55, 180, False),
 'entrainement':  (30.0, -32.0, 135, False),      # coin d'entraînement sur la place (Hugo)
 'passage_lanternes': (-200.0, -66.0, 0, False),  # milieu de la ruelle
 'rue_fontaine':  (-200.0, 65.0, 0, False),
 'dom_lea':       (-250.5, 96.0, 90, True),
 'dom_hugo':      (-147.0 + 4.5, -170.0, 270, True),
 'dom_ines':      (-262.5 + 13.5, 170.0, 90, True),
 'dom_marc':      (-250.5, -180.0, 270, True),
 'dom_sofia':     (-142.5, 100.0, 270, True),
 'dom_karim':     (151.5, 170.0, 90, True),
 'dom_chloe':     (100.0, 136.5, 0, True),
 'dom_theo':      (-200.0, -110.0, 0, True),      # au bout du Passage des Lanternes
 'dom_nadia':     (-60.0, -136.5, 0, True),
 'dom_victor':    (300.0, 136.5, 0, True),
}

def build():
    ns = [s for s in streets.STREETS if s[1] == 'z']
    ew = [s for s in streets.STREETS if s[1] == 'x']
    pts = {}; nodes = []; edges = set()
    def node(x, y, z):
        k = (round(x * 2), round(z * 2), round(y * 10))
        if k not in pts:
            pts[k] = len(nodes); nodes.append([round(x, 2), round(y, 2), round(z, 2)])
        return pts[k]
    def link(a, b):
        if a != b: edges.add((min(a, b), max(a, b)))
    px0, pz0, px1, pz1 = streets.PLAZA
    lines = []   # (axe, coordonnée fixe, liste des arrêts le long)
    for s in ns:
        for side in (-1, 1):
            x = s[2] + side * (s[3] + s[4] / 2.0)
            stops = [s[5] + 3, s[6] - 3]
            for e in ew: stops += [e[2] - e[3] - e[4] / 2.0, e[2] + e[3] + e[4] / 2.0]
            if s[2] == 0: stops += [pz0 - 1.5, pz1 + 1.5]
            lines.append(('z', x, stops, s))
    for e in ew:
        for side in (-1, 1):
            z = e[2] + side * (e[3] + e[4] / 2.0)
            stops = [e[5] + 3, e[6] - 3]
            for s in ns: stops += [s[2] - s[3] - s[4] / 2.0, s[2] + s[3] + s[4] / 2.0]
            if e[2] == 0: stops += [px0 - 1.5, px1 + 1.5]
            lines.append(('x', z, stops, e))
    # ruelles : jonctions avec les trottoirs
    alley_nodes = []
    for (x0, z0, x1, z1, name) in streets.ALLEYS:
        if x1 - x0 < z1 - z0:   # nord-sud
            xc = (x0 + x1) / 2.0
            alley_nodes.append(('z', xc, z0 - 1.5, z1 + 1.5))
        else:
            zc = (z0 + z1) / 2.0
            alley_nodes.append(('x', zc, x0 - 1.5, x1 + 1.5))
    for (ax, c, a, b) in alley_nodes:
        for L in lines:
            if L[0] != ax and min(abs(L[1] - a), abs(L[1] - b)) < 0.1 + 0.001:
                L[2].append(c)
    # lieux : rattachés au trottoir le plus proche
    place_stop = {}
    for name, (x, z, rot, inside) in PLACES.items():
        if streets._in_plaza(x, z, 0): continue
        best = None
        for i, L in enumerate(lines):
            d = abs((x if L[0] == 'z' else z) - L[1])
            along = z if L[0] == 'z' else x
            lo, hi = min(L[2]), max(L[2])
            if lo - 1 <= along <= hi + 1 and (best is None or d < best[0]): best = (d, i, along)
        if best and best[0] < 4.0:
            lines[best[1]][2].append(best[2]); place_stop[name] = (best[1], best[2])
    # construit les lignes (sans traverser la place)
    for i, (ax, c, stops, st) in enumerate(lines):
        stops = sorted(set(round(v, 2) for v in stops))
        prev = None
        for v in stops:
            x, z = (c, v) if ax == 'z' else (v, c)
            if streets._in_plaza(x, z, -0.5):
                prev = None; continue
            n = node(x, 0.0, z)
            if prev is not None: link(prev, n)
            prev = n
    # passages piétons (traversées) à chaque carrefour
    for s in ns:
        for e in ew:
            if s[2] == 0 and e[2] == 0: continue
            hs, he = s[3] + s[4] / 2.0, e[3] + e[4] / 2.0
            for sz in (-1, 1):   # traverser la rue nord-sud
                z = e[2] + sz * he
                a = node(s[2] - hs, 0, z); b = node(s[2] + hs, 0, z)
                m1 = node(s[2] - s[3] + 0.4, -0.15, z); m2 = node(s[2] + s[3] - 0.4, -0.15, z)
                link(a, m1); link(m1, m2); link(m2, b)
            for sx in (-1, 1):   # traverser la rue est-ouest
                x = s[2] + sx * hs
                a = node(x, 0, e[2] - he); b = node(x, 0, e[2] + he)
                m1 = node(x, -0.15, e[2] - e[3] + 0.4); m2 = node(x, -0.15, e[2] + e[3] - 0.4)
                link(a, m1); link(m1, m2); link(m2, b)
    # ruelles
    for (ax, c, a, b) in alley_nodes:
        n0 = node(c, 0, a) if ax == 'z' else node(a, 0, c)
        n1 = node(c, 0, b) if ax == 'z' else node(b, 0, c)
        mid = []
        for name, (x, z, rot, inside) in PLACES.items():
            if (ax == 'z' and abs(x - c) < 1 and a < z < b) or (ax == 'x' and abs(z - c) < 1 and a < x < b):
                mid.append(node(x, 0, z) if True else None)
                place_stop[name] = ('direct', mid[-1])
        seq = sorted([n0, n1] + mid, key=lambda i: nodes[i][2] if ax == 'z' else nodes[i][0])
        for i in range(len(seq) - 1): link(seq[i], seq[i + 1])
    # place du Portail : entrées, anneau, passerelles, île
    B = streets.BASIN
    ring = [node(x, 0, z) for (x, z) in [(-23, -23), (0, -23), (23, -23), (23, 0), (23, 23), (0, 23), (-23, 23), (-23, 0)]]
    for i in range(8): link(ring[i], ring[(i + 1) % 8])
    entries = {(-7.5, pz0 - 1.5): ring[0], (7.5, pz0 - 1.5): ring[2], (-7.5, pz1 + 1.5): ring[6], (7.5, pz1 + 1.5): ring[4],
               (px0 - 1.5, -9.0): ring[0], (px0 - 1.5, 9.0): ring[6], (px1 + 1.5, -9.0): ring[2], (px1 + 1.5, 9.0): ring[4]}
    for (x, z), r in entries.items():
        n = node(x, 0, z)
        mid = node((x + nodes[r][0]) / 2, 0, (z + nodes[r][2]) / 2)
        link(n, mid); link(mid, r)
    island = node(0, streets.DECK, 0)
    for (dx, dz), r in (((0, -1), ring[1]), ((1, 0), ring[3]), ((0, 1), ring[5]), ((-1, 0), ring[7])):
        a = node(dx * (B + 2.5), 0, dz * (B + 2.5)); b = node(dx * (B - 1), streets.DECK, dz * (B - 1))
        link(r, a); link(a, b); link(b, island)
    # lieux sur la place : reliés à l'anneau le plus proche
    for name, (x, z, rot, inside) in PLACES.items():
        if streets._in_plaza(x, z, 0) and name not in place_stop:
            n = node(x, streets.DECK if abs(x) < 8 and abs(z) < 8 else 0.0, z)
            r = min(ring, key=lambda i: (nodes[i][0] - x) ** 2 + (nodes[i][2] - z) ** 2)
            link(n, r); place_stop[name] = ('direct', n)
    places = {}
    for name, (x, z, rot, inside) in PLACES.items():
        st = place_stop.get(name)
        if st is None: continue
        if st[0] == 'direct': idx = st[1]
        else:
            L = lines[st[0]]
            xx, zz = (L[1], st[1]) if L[0] == 'z' else (st[1], L[1])
            idx = node(xx, 0.0, zz)
        places[name] = dict(node=idx, pos=[x, nodes[idx][1], z], rot=rot, interieur=inside)
    return dict(nodes=nodes, edges=[list(e) for e in sorted(edges)], places=places)

if __name__ == '__main__':
    g = build()
    print(len(g['nodes']), 'nœuds', len(g['edges']), 'liaisons', len(g['places']), 'lieux')
    missing = [p for p in PLACES if p not in g['places']]
    print('lieux non rattachés :', missing)
