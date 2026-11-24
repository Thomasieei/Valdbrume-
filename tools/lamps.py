"""Lampadaires de Valdbrume : un candélabre de fonte (style parisien simplifié,
~700 triangles) et leur emplacement, rue par rue, choisi à la main :
- avenues et rues : au bord du trottoir, en quinconce d'un côté à l'autre,
  jamais dans un carrefour ni devant l'entrée d'une ruelle ;
- Grand Boulevard : rythme plus serré (artère principale) ;
- place du Portail : aux angles et au milieu des côtés de l'anneau de marbre ;
- ruelles : lanternes rapprochées le long des murs (d'où le nom du passage)."""
import math
import numpy as np
import trimesh
from streets import STREETS, PLAZA, ALLEYS

METAL = (0.07, 0.09, 0.085)


def frustum(r0, r1, y0, y1, n=12, rot=0.0):
    a = np.linspace(0, 2 * math.pi, n, endpoint=False) + rot
    b = np.c_[r0 * np.cos(a), np.full(n, y0), r0 * np.sin(a)]
    t = np.c_[r1 * np.cos(a), np.full(n, y1), r1 * np.sin(a)]
    v = np.r_[b, t, [[0, y0, 0], [0, y1, 0]]]
    f = []
    for i in range(n):
        j = (i + 1) % n
        f += [[i, n + i, j], [j, n + i, n + j], [2 * n, i, j], [2 * n + 1, n + j, n + i]]
    return trimesh.Trimesh(v, np.array(f), process=False)


def build_mesh(path):
    metal = [
        frustum(0.24, 0.17, 0.0, 0.18, 8, math.pi / 8),       # socle
        frustum(0.17, 0.13, 0.18, 0.55, 8, math.pi / 8),
        frustum(0.16, 0.16, 0.55, 0.62, 12),                  # bague
        frustum(0.075, 0.058, 0.62, 3.72, 12),                # fût
        frustum(0.10, 0.10, 2.1, 2.16, 12),                   # anneau décoratif
        frustum(0.105, 0.09, 3.72, 3.80, 12),                 # collerette
        frustum(0.07, 0.13, 3.80, 3.88, 6),                   # coupelle sous la lanterne
        frustum(0.31, 0.06, 4.36, 4.62, 6),                   # toit de la lanterne
        frustum(0.05, 0.0, 4.62, 4.78, 6),                    # pointe
    ]
    # montants de la lanterne (6 arêtes fines)
    for k in range(6):
        a = k * math.pi / 3
        p0 = np.array([0.13 * math.cos(a), 3.88, 0.13 * math.sin(a)])
        p1 = np.array([0.27 * math.cos(a), 4.36, 0.27 * math.sin(a)])
        seg = trimesh.creation.cylinder(radius=0.012, segment=[p0, p1], sections=4)
        metal.append(seg)
    glass = frustum(0.125, 0.26, 3.88, 4.36, 6)
    sc = trimesh.Scene()
    m = trimesh.util.concatenate(metal)
    m.visual = trimesh.visual.ColorVisuals(m, face_colors=[int(c * 255) for c in METAL] + [255])
    g = glass
    m.visual = trimesh.visual.TextureVisuals(material=trimesh.visual.material.PBRMaterial(
        name='LampMetal', baseColorFactor=[*METAL, 1.0], metallicFactor=0.7, roughnessFactor=0.45))
    g.visual = trimesh.visual.TextureVisuals(material=trimesh.visual.material.PBRMaterial(
        name='LampGlass', baseColorFactor=[1.0, 0.85, 0.6, 1.0], metallicFactor=0.0, roughnessFactor=0.2))
    sc.add_geometry(m, geom_name='metal'); sc.add_geometry(g, geom_name='verre')
    sc.export(path)
    return len(m.faces) + len(g.faces)


def _crossing(axis, pos):
    """vrai si la position (le long d'une rue d'axe `axis`) tombe dans un carrefour"""
    other = [s for s in STREETS if s[1] != axis]
    return any(abs(pos - s[2]) < s[3] + s[4] + 3.0 for s in other)


def _plaza(x, z, m=1.0):
    x0, z0, x1, z1 = PLAZA
    return x0 - m < x < x1 + m and z0 - m < z < z1 + m


def _alley_mouth(x, z):
    for (x0, z0, x1, z1, _) in ALLEYS:
        if x0 - 4 < x < x1 + 4 and z0 - 4 < z < z1 + 4: return True
    return False


def positions():
    out = []
    for (name, axis, c, ah, sw, a, b) in STREETS:
        step = 20.0 if name == 'Grand Boulevard' else 24.0
        off = ah + (0.9 if sw >= 6 else 0.6)
        for side, phase in ((-1, 0.0), (1, step / 2)):
            t = a + 10.0 + phase
            while t < b - 6.0:
                if not _crossing(axis, t):
                    x, z = (c + side * off, t) if axis == 'z' else (t, c + side * off)
                    if not _plaza(x, z) and not _alley_mouth(x, z):
                        # la lanterne penche vers la chaussée : rot = direction de la rue
                        out.append([round(x, 2), round(z, 2), 0.0 if axis == 'z' else 90.0])
                t += step
    # place du Portail : anneau de marbre (angles et milieux, hors passerelles)
    for (x, z) in [(-25.5, -25.5), (25.5, -25.5), (-25.5, 25.5), (25.5, 25.5),
                   (-25.5, -12.5), (-25.5, 12.5), (25.5, -12.5), (25.5, 12.5),
                   (-12.5, -25.5), (12.5, -25.5), (-12.5, 25.5), (12.5, 25.5)]:
        out.append([x, z, 0.0])
    # ruelles : lanternes rapprochées le long des murs, en quinconce
    for (x0, z0, x1, z1, _) in ALLEYS:
        along_z = (z1 - z0) > (x1 - x0)
        n = 0
        if along_z:
            z = z0 + 7.0
            while z < z1 - 5.0:
                out.append([x0 + 0.55 if n % 2 == 0 else x1 - 0.55, round(z, 2), 0.0]); z += 11.0; n += 1
        else:
            x = x0 + 7.0
            while x < x1 - 5.0:
                out.append([round(x, 2), z0 + 0.55 if n % 2 == 0 else z1 - 0.55, 0.0]); x += 11.0; n += 1
    return out


if __name__ == '__main__':
    p = positions()
    print(len(p), 'lampadaires')
    print(build_mesh('/tmp/lamp.glb'), 'triangles')
