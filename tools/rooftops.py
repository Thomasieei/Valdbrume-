"""Parcours sur les toits du Passage des Lanternes (tracé à la main).

Montée par une échelle de secours sur la façade ouest, escalade de caisses
jusqu'au toit voisin plus haut (16 m), descente sur un toit plus bas, grand saut
par-dessus la ruelle avec rattrapage au parapet d'en face, et pour finir le
« saut de la foi » dans un tas de sacs, au fond de la ruelle.

Repères (layout.py) : façade ouest de la ruelle x = -203, façade est x = -197 ;
toits à 13 m : ouest z -104..-92 et -82..-70, est z -82..-58 ; toit à 16 m :
ouest z -92..-82."""
import math, os
import numpy as np
import trimesh

# échelles : [x du point d'accroche, z, bas, haut, direction du regard (degrés, vers le mur)]
ECHELLES = [
    [-202.55, -97.5, 0.0, 13.0, -90.0],
]
# objets posés sur les toits : [type, x, y, z, rotation]
OBJETS_TOITS = [
    ['caisses2', -209.5, 13.0, -93.0, 90],      # marches vers le toit à 16 m
    ['caisse', -213.0, 13.0, -100.5, 0],
    ['caisse', -205.5, 16.0, -86.0, 0],          # obstacle à franchir sur le toit haut
    ['caisse', -212.0, 13.0, -75.0, 0],
    ['tas_sacs', -199.6, 0.0, -64.6, 90],        # tas de sacs : réception du saut de la foi
    # équipements de toit, posés hors de la trajectoire du parcours
    ['cheminee', -215.8, 13.0, -102.6, 0], ['clim_toit', -206.0, 13.0, -102.8, 0], ['ventilation', -213.2, 13.0, -94.6, 0],
    ['chateau_eau', -214.6, 16.0, -85.0, 20], ['ventilation', -205.0, 16.0, -90.6, 0],
    ['cheminee', -215.6, 13.0, -71.2, 90], ['clim_toit', -206.0, 13.0, -71.5, 0],
    ['cheminee', -185.0, 13.0, -80.6, 0], ['ventilation', -193.5, 13.0, -80.8, 0],
    ['clim_toit', -185.5, 13.0, -60.0, 90], ['cheminee', -185.2, 13.0, -69.5, 90], ['ventilation', -192.8, 13.0, -59.6, 0],
]
# tas de sacs où l'on peut plonger depuis un toit (saut de la foi) : dessus du tas
RECEPTACLES = [[-199.6, 0.95, -64.6]]
# anneaux du défi chronométré : [x, y, z] — départ au pied de l'échelle, arrivée dans les sacs
ANNEAUX = [
    [-201.6, 1.2, -97.5],      # départ
    [-207.5, 14.3, -98.0],     # haut de l'échelle
    [-210.0, 17.3, -87.0],     # toit haut
    [-210.0, 14.3, -76.0],     # toit bas, avant le grand saut
    [-190.0, 14.3, -77.0],     # de l'autre côté de la ruelle
    [-190.0, 14.3, -64.0],     # bord du toit, au-dessus des sacs
    [-199.5, 1.6, -64.6],      # arrivée
]


def ladder_mesh(path, h=14.2):
    """échelle de secours en fer peint (montants, barreaux, crosse en haut)"""
    col = [74, 30, 26, 255]
    parts = []
    for sx in (-0.24, 0.24):
        r = trimesh.creation.box(extents=[0.05, h, 0.07]); r.apply_translation([sx, h / 2, 0])
        parts.append(r)
        # crosse : les montants se recourbent au-dessus du toit
        c = trimesh.creation.box(extents=[0.05, 0.05, 0.6]); c.apply_translation([sx, h, -0.3]); parts.append(c)
    y = 0.3
    while y < h - 0.2:
        b = trimesh.creation.cylinder(radius=0.018, height=0.48, sections=6)
        b.apply_transform(trimesh.transformations.rotation_matrix(math.pi / 2, [0, 0, 1]))
        b.apply_translation([0, y, 0]); parts.append(b)
        y += 0.32
    # pattes de fixation au mur tous les 2,5 m
    y = 1.0
    while y < h:
        for sx in (-0.24, 0.24):
            p = trimesh.creation.box(extents=[0.04, 0.04, 0.22]); p.apply_translation([sx, y, -0.12]); parts.append(p)
        y += 2.5
    m = trimesh.util.concatenate(parts)
    m.visual = trimesh.visual.ColorVisuals(m, face_colors=col)
    m.export(path)


def boxes():
    """collisions des objets posés sur les toits (mêmes boîtes que props.py)"""
    import props
    out = []
    for (t, x, y, z, r) in OBJETS_TOITS:
        a = math.radians(r)
        for (cx, cy, cz, sx, sy, sz) in props.TYPES[t][1]:
            wx = x + cx * math.cos(a) + cz * math.sin(a)
            wz = z - cx * math.sin(a) + cz * math.cos(a)
            if round(r) % 180 == 90: sx, sz = sz, sx
            out.append([round(wx, 3), y + cy, round(wz, 3), sx, sy, sz])
    return out
