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
    # tas de sacs poubelle : réception du saut de la foi (dessus mou à ~0.95 m)
    'tas_sacs':  (None, [[0, 0.45, 0, 2.3, 0.9, 1.9]]),
    # équipements de toit (posés à la main sur les toits praticables)
    'chateau_eau': (None, [[0, 3.55, 0, 2.7, 2.7, 2.7]] + [[sx * 1.0, 1.1, sz * 1.0, 0.22, 2.2, 0.22] for sx in (-1, 1) for sz in (-1, 1)]),
    'cheminee':  (None, [[0, 0.85, 0, 1.0, 1.7, 0.7]]),
    'ventilation': (None, [[0, 0.45, 0, 0.6, 0.9, 0.6]]),
    'clim_toit': (None, [[0, 0.6, 0, 1.6, 1.2, 1.1]]),
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


def bag(rng, size, col):
    """sac poubelle : sphère déformée (posé, tassé, plis), nœud torsadé au sommet"""
    m = trimesh.creation.icosphere(subdivisions=2, radius=1.0)
    v = m.vertices.copy()
    # plis du plastique : bruit à basse fréquence, plus fort sur les flancs
    k = rng.normal(size=(6, 3)); ph = rng.uniform(0, 6.28, 6)
    bump = sum(0.06 * np.sin(v @ k[i] * 2.2 + ph[i]) for i in range(6))
    v *= (1.0 + bump)[:, None]
    # tassé sous son poids : bas aplati et élargi, haut pincé vers le nœud
    y = v[:, 1]
    wide = 1.0 + 0.18 * np.clip(-y, 0, 1) - 0.32 * np.clip(y - 0.35, 0, 1) ** 1.5
    v[:, 0] *= wide; v[:, 2] *= wide
    v[:, 1] = np.where(y < -0.35, -0.35 - (-0.35 - y) * 0.35, y)
    v *= np.array(size) * 0.5
    v[:, 1] -= v[:, 1].min()
    m.vertices = v
    # reflets du plastique : plus clair sur le dessus, plus sombre dessous
    n = m.vertex_normals
    shade = np.clip(0.72 + 0.38 * n[:, 1] + 0.12 * rng.normal(size=len(v)) * 0.3, 0.45, 1.15)
    vc = np.clip(np.array(col)[None, :3] * shade[:, None], 0, 255)
    m.visual = trimesh.visual.ColorVisuals(m, vertex_colors=np.hstack([vc, np.full((len(v), 1), 255)]).astype(np.uint8))
    top = v[:, 1].max()
    cx, cz = v[v[:, 1] > top - 0.05][:, [0, 2]].mean(axis=0)
    knot = trimesh.creation.cone(radius=size[0] * 0.09, height=size[1] * 0.22, sections=7)
    knot.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [1, 0, 0]))     # pointe vers le bas
    knot.apply_translation([cx, top + size[1] * 0.16, cz])
    ear = trimesh.creation.icosphere(subdivisions=1, radius=size[0] * 0.07)
    ear.apply_scale([1.6, 0.7, 0.9]); ear.apply_translation([cx + size[0] * 0.06, top + size[1] * 0.2, cz])
    for p in (knot, ear):
        p.visual = trimesh.visual.ColorVisuals(p, face_colors=[int(col[0] * 0.8), int(col[1] * 0.8), int(col[2] * 0.8), 255])
    return trimesh.util.concatenate([m, knot, ear])


def bag_pile():
    """tas de sacs poubelle (noirs, gris, un vert, un bleu de tri), une caisse en carton écrasée"""
    rng = np.random.default_rng(11)
    noir, gris, vert, bleu = (44, 47, 53), (82, 86, 92), (44, 74, 52), (46, 82, 140)
    # [x, z, y, largeur, hauteur, profondeur, couleur, rotation]
    sacs = [(-0.75, -0.55, 0.0, 0.95, 0.8, 0.85, noir, 10), (0.2, -0.6, 0.0, 1.0, 0.85, 0.9, gris, -25),
            (0.85, 0.05, 0.0, 0.9, 0.75, 0.85, noir, 40), (-0.8, 0.45, 0.0, 0.9, 0.8, 0.9, vert, -5),
            (0.1, 0.55, 0.0, 1.0, 0.8, 0.9, noir, 70), (-0.25, -0.05, 0.38, 1.0, 0.75, 0.95, noir, 15),
            (0.55, -0.25, 0.32, 0.8, 0.65, 0.75, bleu, -50), (-0.55, 0.15, 0.34, 0.75, 0.62, 0.7, gris, 120),
            (0.35, 0.4, 0.3, 0.75, 0.6, 0.7, noir, 200)]
    parts = []
    for (x, z, y, w, h, d, col, r) in sacs:
        b = bag(rng, (w, h, d), col)
        b.apply_transform(trimesh.transformations.rotation_matrix(math.radians(r), [0, 1, 0]))
        b.apply_translation([x, y, z])
        parts.append(b)
    carton = _box([1.0, 0.18, 0.75], [0.6, 0.36, 0.5], [158, 120, 78, 255])
    carton.apply_transform(trimesh.transformations.rotation_matrix(0.35, [0, 1, 0], [1.0, 0, 0.75]))
    parts.append(carton)
    return trimesh.util.concatenate(parts)


def _cyl(r, h, y0, col, sec=16, x=0.0, z=0.0):
    c = trimesh.creation.cylinder(radius=r, height=h, sections=sec)       # axe z → axe y
    c.apply_transform(trimesh.transformations.rotation_matrix(-math.pi / 2, [1, 0, 0]))
    c.apply_translation([x, y0 + h / 2, z])
    c.visual = trimesh.visual.ColorVisuals(c, face_colors=col)
    return c


def water_tower():
    """château d'eau de toit new-yorkais : cuve en douelles de bois cerclée de fer,
    toit conique, sur un châssis d'acier à croisillons, avec son échelle"""
    parts = []
    acier, bois_c, bois_f, fer, toit = [58, 60, 64, 255], [150, 104, 64, 255], [118, 80, 48, 255], [44, 44, 46, 255], [70, 58, 50, 255]
    y0, h, r = 2.2, 2.7, 1.3
    # douelles : 24 planches verticales légèrement différentes
    n = 24
    for i in range(n):
        a = 2 * math.pi * i / n
        b = _box([0, 0, 0], [2 * math.pi * r / n * 1.02, h, 0.08], bois_c if i % 3 else bois_f)
        b.apply_transform(trimesh.transformations.rotation_matrix(-a, [0, 1, 0]))
        b.apply_translation([r * math.sin(a), y0 + h / 2, r * math.cos(a)])
        parts.append(b)
    parts.append(_cyl(r - 0.05, 0.1, y0, bois_f, 20))                       # fond
    for hy in (0.25, 0.95, 1.65, 2.35):                                    # cerclages
        parts.append(_cyl(r + 0.05, 0.06, y0 + hy, fer, 24))
    cone = trimesh.creation.cone(radius=r + 0.18, height=1.0, sections=24)
    cone.apply_transform(trimesh.transformations.rotation_matrix(-math.pi / 2, [1, 0, 0]))   # pointe vers le haut
    cone.apply_translation([0, y0 + h, 0]); cone.visual = trimesh.visual.ColorVisuals(cone, face_colors=toit)
    parts.append(cone)
    parts.append(_cyl(0.06, 0.35, y0 + h + 0.9, fer, 8))                    # évent
    # châssis : 4 pieds, poutres et croisillons
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(_box([sx * 1.0, y0 / 2, sz * 1.0], [0.16, y0, 0.16], acier))
    for k in (-1, 1):
        parts.append(_box([0, y0 - 0.08, k * 1.0], [2.16, 0.16, 0.16], acier))
        parts.append(_box([k * 1.0, y0 - 0.08, 0], [0.16, 0.16, 2.16], acier))
        for diag in (1, -1):
            d = _box([0, 0, 0], [math.hypot(2.0, y0 - 0.2), 0.07, 0.07], acier)
            d.apply_transform(trimesh.transformations.rotation_matrix(diag * math.atan2(y0 - 0.2, 2.0), [0, 0, 1]))
            d.apply_translation([0, (y0 - 0.2) / 2 + 0.05, k * 1.0]); parts.append(d)
            d2 = _box([0, 0, 0], [0.07, 0.07, math.hypot(2.0, y0 - 0.2)], acier)
            d2.apply_transform(trimesh.transformations.rotation_matrix(diag * math.atan2(y0 - 0.2, 2.0), [1, 0, 0]))
            d2.apply_translation([k * 1.0, (y0 - 0.2) / 2 + 0.05, 0]); parts.append(d2)
    # échelle le long de la cuve
    for sx in (-0.2, 0.2):
        parts.append(_box([sx, (y0 + h) / 2 + 0.3, r + 0.18], [0.04, y0 + h - 0.2, 0.04], fer))
    y = 0.5
    while y < y0 + h:
        parts.append(_box([0, y, r + 0.18], [0.4, 0.03, 0.03], fer)); y += 0.3
    return trimesh.util.concatenate(parts)


def chimney():
    """souche de cheminée en brique, chaperon de pierre et deux mitrons en terre cuite"""
    rng = np.random.default_rng(3)
    parts = []
    # briques : rangs alternés de teintes proches
    for i in range(10):
        c = [int(146 + rng.integers(-14, 14)), int(66 + rng.integers(-8, 8)), int(50 + rng.integers(-6, 6)), 255]
        parts.append(_box([0, 0.08 + i * 0.16, 0], [0.94 + (0.02 if i % 2 else 0), 0.155, 0.64 + (0.02 if i % 2 else 0)], c))
    parts.append(_box([0, 1.65, 0], [1.04, 0.1, 0.74], [178, 170, 156, 255]))
    for x in (-0.22, 0.22):
        parts.append(_cyl(0.11, 0.42, 1.7, [176, 92, 58, 255], 10, x=x))
        parts.append(_cyl(0.135, 0.06, 2.08, [160, 82, 52, 255], 10, x=x))
    return trimesh.util.concatenate(parts)


def vent():
    """aérateur de toit : extracteur à turbine galvanisé sur sa gaine"""
    gal, sombre = [150, 156, 160, 255], [96, 100, 104, 255]
    parts = [_box([0, 0.06, 0], [0.56, 0.12, 0.56], sombre), _cyl(0.16, 0.45, 0.12, gal, 12)]
    t = trimesh.creation.icosphere(subdivisions=2, radius=0.27)
    t.vertices[:, 1] *= 0.75
    # ailettes de la turbine : bandes sombres
    t.apply_translation([0, 0.74, 0])
    cols = np.array([gal if (int((math.atan2(v[2], v[0]) + math.pi) / (2 * math.pi) * 16) % 2) else sombre for v in t.vertices], dtype=np.uint8)
    t.visual = trimesh.visual.ColorVisuals(t, vertex_colors=cols)
    parts.append(t)
    parts.append(_cyl(0.04, 0.08, 0.92, sombre, 8))
    return trimesh.util.concatenate(parts)


def roof_ac():
    """gros climatiseur de toit : caisson, grilles, deux ventilateurs sur le dessus"""
    cais, grille, sombre = [196, 198, 194, 255], [120, 124, 126, 255], [52, 54, 58, 255]
    parts = [_box([0, 0.06, 0], [1.66, 0.12, 1.16], sombre), _box([0, 0.62, 0], [1.6, 1.0, 1.1], cais)]
    for x in (-0.4, 0.4):
        parts.append(_cyl(0.33, 0.06, 1.12, grille, 16, x=x))
        parts.append(_cyl(0.07, 0.08, 1.15, sombre, 8, x=x))
        for k in range(3):
            pale = _box([0, 0, 0], [0.56, 0.015, 0.09], sombre)
            a = k * math.pi / 3
            pale.vertices = pale.vertices @ np.array([[math.cos(a), 0, -math.sin(a)], [0, 1, 0], [math.sin(a), 0, math.cos(a)]]) + np.array([x, 1.17, 0])
            parts.append(pale)
    for z in (-0.556, 0.556):
        for i in range(6):
            parts.append(_box([0, 0.3 + i * 0.1, z], [1.4, 0.035, 0.012], grille))
    parts.append(_box([0.86, 0.35, 0.25], [0.12, 0.12, 0.12], sombre))          # boîtier électrique
    parts.append(_cyl(0.04, 0.6, 0.0, sombre, 8, x=0.86, z=-0.3))              # conduit
    return trimesh.util.concatenate(parts)


def build_meshes(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    jersey().export(os.path.join(out_dir, 'beton.glb'))
    crate(1).export(os.path.join(out_dir, 'caisse.glb'))
    two = crate(2); top = crate(1); top.apply_translation([-0.5, 1.0, 0])
    trimesh.util.concatenate([two, top]).export(os.path.join(out_dir, 'caisses2.glb'))
    bag_pile().export(os.path.join(out_dir, 'tas_sacs.glb'))
    water_tower().export(os.path.join(out_dir, 'chateau_eau.glb'))
    chimney().export(os.path.join(out_dir, 'cheminee.glb'))
    vent().export(os.path.join(out_dir, 'ventilation.glb'))
    roof_ac().export(os.path.join(out_dir, 'clim_toit.glb'))
    return ['beton', 'caisse', 'caisses2', 'tas_sacs', 'chateau_eau', 'cheminee', 'ventilation', 'clim_toit']


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
