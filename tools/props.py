"""Mobilier urbain et obstacles de parkour, placés à la main rue par rue.

Modèles : voitures, camionnette, bennes, poubelles, sacs et abribus du pack
Cartoon City (palette de couleurs, très légers) ; séparateurs en béton (type
« Jersey ») et caisses de chantier modelés ici.

Chaque obstacle a une collision simple (boîtes) : le joueur s'y heurte et le
système de parkour lit leur hauteur et leur épaisseur pour choisir le
mouvement (passer par-dessus, vrille, escalade)."""
import math, os
import numpy as np
import trimesh

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CC = os.path.join(ROOT, 'vendor', 'cartoon_city')

# type -> (source, boîtes de collision locales [cx, cy, cz, sx, sy, sz])
TYPES = {
    'berline':   ('Car_13.glb', [[0, 0.5, 0.04, 2.05, 1.0, 4.5], [0, 1.15, -0.1, 1.75, 0.42, 2.2]]),
    'compacte':  ('Car_16.glb', [[0, 0.52, 0.04, 1.95, 1.04, 4.1], [0, 1.22, -0.05, 1.7, 0.5, 2.0]]),
    'citadine':  ('Car_19.glb', [[0, 0.55, -0.07, 1.75, 1.1, 3.6], [0, 1.35, -0.2, 1.6, 0.6, 1.9]]),
    'suv':       ('Car_06.glb', [[0, 0.6, 0.02, 2.3, 1.2, 3.65], [0, 1.45, -0.1, 2.1, 0.55, 2.4]]),
    'camionnette': ('Van.glb', [[0, 1.45, -0.27, 2.25, 2.9, 5.0]]),
    'benne':     ('Trash_Can_04.glb', [[0, 0.82, 0, 2.05, 1.64, 1.18]]),
    'benne_b':   ('Trash_Can_05.glb', [[0, 0.82, 0, 2.05, 1.64, 1.18]]),
    'poubelle':  ('Trash_02.glb', [[0, 0.44, 0, 0.5, 0.88, 0.5]]),
    'poubelle_b': ('Trash_04.glb', [[0, 0.44, 0, 0.5, 0.88, 0.5]]),
    'sacs':      ('Trash_06.glb', [[0, 0.3, 0, 2.0, 0.6, 0.55]]),
    'abribus':   ('Bus_Stop_02.glb', [[0, 1.25, -0.1, 4.6, 2.5, 0.25]]),
    'beton':     (None, [[0, 0.41, 0, 2.0, 0.82, 0.55]]),
    'caisse':    (None, [[0, 0.5, 0, 1.0, 1.0, 1.0]]),
    'caisses2':  (None, [[0, 0.5, 0, 2.0, 1.0, 1.0], [-0.5, 1.5, 0, 1.0, 1.0, 1.0]]),
}

# ------------------------------------------------------------------ modèles faits ici
def _box(c, s, col):
    m = trimesh.creation.box(extents=s); m.apply_translation(c)
    m.visual = trimesh.visual.ColorVisuals(m, face_colors=col)
    return m


def jersey():
    """séparateur de chantier en béton, profil en trapèze, rainure et logo peint"""
    prof = [(-0.30, 0.0), (0.30, 0.0), (0.30, 0.08), (0.12, 0.30), (0.08, 0.82), (-0.08, 0.82), (-0.12, 0.30), (-0.30, 0.08)]
    # prisme : profil (z, y) extrudé sur 2 m selon x (profil convexe)
    n = len(prof)
    v = [[-1.0, y, z] for (z, y) in prof] + [[1.0, y, z] for (z, y) in prof]
    f = []
    for i in range(n):
        j = (i + 1) % n
        f += [[i, j, n + j], [i, n + j, n + i]]
    for i in range(1, n - 1):
        f += [[0, i + 1, i], [n, n + i, n + i + 1]]
    m = trimesh.Trimesh(np.array(v), np.array(f), process=True)
    m.fix_normals()
    m.visual = trimesh.visual.ColorVisuals(m, face_colors=[168, 164, 156, 255])
    band = _box([0, 0.62, 0], [1.6, 0.12, 0.19], [214, 64, 40, 255])     # bande rouge et blanche
    band2 = _box([0, 0.62, 0], [0.5, 0.125, 0.195], [235, 232, 225, 255])
    return trimesh.util.concatenate([m, band, band2])


def crate(n=1):
    """caisse de chantier en planches (cadre foncé, panneaux clairs)"""
    parts = []
    for k in range(n):
        ox = -0.5 * (n - 1) + k
        parts.append(_box([ox, 0.5, 0], [0.96, 0.96, 0.96], [150, 108, 62, 255]))
        for (dx, dy, dz, sx, sy, sz) in [(0, 0.04, 0.49, 1.0, 0.08, 0.04), (0, 0.96, 0.49, 1.0, 0.08, 0.04), (0, 0.04, -0.49, 1.0, 0.08, 0.04), (0, 0.96, -0.49, 1.0, 0.08, 0.04),
                                         (0.49, 0.5, 0.49, 0.04, 1.0, 0.06), (-0.49, 0.5, 0.49, 0.04, 1.0, 0.06), (0.49, 0.5, -0.49, 0.04, 1.0, 0.06), (-0.49, 0.5, -0.49, 0.04, 1.0, 0.06),
                                         (0, 0.5, 0.495, 1.25, 0.07, 0.03)]:
            b = _box([ox + dx, dy, dz], [sx, sy, sz], [96, 66, 38, 255])
            if sx > 1.2: b.apply_transform(trimesh.transformations.rotation_matrix(math.atan2(0.92, 0.92), [0, 0, 1], [ox, 0.5, 0.495]))
            parts.append(b)
    return trimesh.util.concatenate(parts)


def build_meshes(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    jersey().export(os.path.join(out_dir, 'beton.glb'))
    crate(1).export(os.path.join(out_dir, 'caisse.glb'))
    two = crate(2); top = crate(1); top.apply_translation([-0.5, 1.0, 0])
    trimesh.util.concatenate([two, top]).export(os.path.join(out_dir, 'caisses2.glb'))
    return ['beton', 'caisse', 'caisses2']


# ------------------------------------------------------------------ placement (à la main)
# [type, x, z, rotation en degrés] — rues : voir streets.py (bord de chaussée du Grand
# Boulevard à |z| = 6, trottoir jusqu'à 12 ; ruelles de 6 m de large)
PLACES = [
    # Grand Boulevard, côté nord : voitures garées le long du trottoir, en épi de vie
    ['berline', -224.0, -4.9, 90], ['citadine', -214.5, -4.9, 90], ['suv', -196.0, -4.9, 90],
    ['compacte', -170.0, -4.9, 90], ['camionnette', -94.0, -4.7, 90], ['berline', -84.5, -4.9, 90],
    # côté sud
    ['compacte', -230.0, 4.9, 270], ['berline', -186.0, 4.9, 270], ['citadine', -176.5, 4.9, 270],
    ['suv', 84.0, 4.9, 270], ['berline', 94.0, 4.9, 270], ['camionnette', 186.0, 4.7, 270],
    ['compacte', 210.0, 4.9, 270], ['berline', 220.0, 4.9, 270],
    ['berline', 170.0, -4.9, 90], ['citadine', 232.0, -4.9, 90],
    # abribus et poubelles du boulevard (contre la façade, hors du passage des piétons)
    ['abribus', 60.0, 9.2, 180], ['poubelle', 64.0, 11.3, 0], ['poubelle_b', -62.0, -11.3, 0],
    ['poubelle', 118.0, 11.3, 0], ['poubelle_b', -118.0, -11.3, 0], ['poubelle', 236.0, -11.3, 0],
    # Avenue du Portail (nord de la place) : quelques voitures
    ['berline', 4.9, -150.0, 0], ['suv', 4.9, -140.5, 0], ['compacte', -4.9, -100.0, 180], ['citadine', -4.9, -91.0, 180],
    # Passage des Lanternes (x -203..-197) : bennes contre les murs, sacs, caisses
    ['benne', -202.35, -100.0, 90], ['sacs', -202.6, -103.6, 90], ['poubelle', -197.5, -95.0, 0],
    ['benne_b', -197.65, -86.0, 90], ['caisse', -197.75, -83.0, 0],
    ['benne', -202.35, -60.0, 90], ['caisses2', -202.25, -64.5, 90], ['poubelle_b', -202.6, -56.5, 0],
    ['sacs', -197.4, -40.0, 90],
    # Passage de la Bourse (x 199..205) : un chantier, terrain de jeu du parkour
    ['beton', 200.5, -104.0, 0], ['beton', 203.6, -96.0, 0], ['caisse', 200.2, -90.0, 0],
    ['caisses2', 203.7, -84.5, 90], ['beton', 200.5, -77.0, 0], ['benne', 203.65, -71.0, 90],
    ['beton', 200.5, -65.5, 0], ['beton', 203.6, -62.0, 0], ['caisse', 200.2, -53.0, 0], ['caisse', 200.2, -52.0, 0],
    ['caisses2', 203.75, -44.0, 90], ['beton', 200.5, -38.0, 0], ['beton', 202.5, -30.0, 0],
    # Rue de la Fontaine (z 62..68) : arrière-cours
    ['benne', -240.0, 62.65, 0], ['sacs', -236.0, 62.4, 0], ['poubelle', -233.5, 62.4, 0],
    ['benne_b', -180.0, 67.35, 180], ['caisse', -176.5, 67.4, 0], ['poubelle_b', -165.0, 62.4, 0],
    # Rue des Tanneurs (étroite) : séparateurs d'un petit chantier
    ['beton', -147.0, 40.0, 90], ['beton', -147.0, 44.0, 90], ['caisse', -144.6, 52.0, 0],
]


def boxes():
    """collisions monde : une ou deux boîtes par objet"""
    out = []
    for (t, x, z, r) in PLACES:
        a = math.radians(r)
        for (cx, cy, cz, sx, sy, sz) in TYPES[t][1]:
            wx = x + cx * math.cos(a) + cz * math.sin(a)
            wz = z - cx * math.sin(a) + cz * math.cos(a)
            # boîte alignée sur les axes du monde (les objets sont posés à 0/90/180/270°)
            if round(r) % 180 == 90: sx, sz = sz, sx
            out.append([round(wx, 3), cy, round(wz, 3), sx, sy, sz])
    return out


if __name__ == '__main__':
    print(build_meshes('/tmp/props'), len(PLACES), 'objets', len(boxes()), 'boîtes')
