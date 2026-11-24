"""Façades imprimées : chaque module de mur des étages est rendu une fois, de
face, en orthographique (couleur, relief, normales, classes de teinte,
coordonnées de pièce pour les intérieurs). En jeu, un étage = 2 triangles par
module, avec le même aspect que le vrai module vu de la rue."""
import os, json, math, numpy as np
from PIL import Image
import bake
TEX = os.path.join(bake.ROOT, 'project', 'assets', 'city', 'textures') + '/'

PX = 112                     # pixels par mètre
PAD = 16                     # marge (contenu continu : modules répétés autour)
IMP = [  # (module, largeur, hauteur)
    ('Brick_Window_Trim_Single', 2, 3), ('Brick_Window_Trim', 2, 3), ('Brick_Window_Square_Single', 2, 3),
    ('Trim_Window', 2, 3), ('Metal_FullWindow', 2, 3), ('Metal_Window_Half', 2, 3),
    ('Brick_Plain_3', 2, 3), ('Trim_Plain_3', 2, 3), ('Metal_Plain_3', 2, 3),
    ('Trim_FirstFloor_Window_001', 2, 3), ('Metal_FirstFloor_Window', 2, 3), ('Metal_FirstFloor_Wall', 2, 3),
    ('DoorFrame_Trim', 2, 3), ('DoorFrame_Metal_Single', 2, 3), ('DoorFrame_Wooden', 2, 3), ('Brick_BottomTrim', 2, 3),
    ('Brick_Plain_1', 2, 1), ('Metal_FirstFloor_Wall_1', 2, 1), ('Metal_Plain_1', 2, 1),
    ('Brick_Inset_Window', 4, 3), ('Brick_Inset_Window_Curved', 4, 3), ('Brick_RedWhite_DoubleWindow', 4, 3),
    ('Brick_Inset_Window_Curved_Small', 4, 3), ('Metal_Window', 4, 3),
]
# classes de teinte : 1 = mur (brique), 2 = pierre/béton, 3 = accent (cadres, vitrines)
CLASS = {'MI_RedBrick': 1, 'MI_RedBrick_Pale': 1, 'MI_InteriorWall': 1,
         'MI_Trim': 2, 'MI_Trim_MetalConcrete': 2, 'MI_Ornaments': 0,
         'MI_Trim_Dark': 3, 'MI_Trim_Green': 3, 'MI_FakeInterior': 0, 'MI_Concrete': 2}
BASE = {'MI_RedBrick_Pale': (1.32, 1.22, 1.08), 'MI_InteriorWall': (0.55, 0.55, 0.55)}
TEXF = {'MI_RedBrick': 'T_RedBrick_BaseColor.png', 'MI_RedBrick_Pale': 'T_RedBrick_BaseColor.png',
        'MI_InteriorWall': 'T_RedBrick_BaseColor.png', 'MI_Trim': 'T_Trim_BaseColor.png',
        'MI_Trim_Dark': 'T_Trim_BaseColor.png', 'MI_Trim_Green': 'T_Trim_BaseColor.png',
        'MI_Trim_MetalConcrete': 'T_MetalConcrete_BaseColor.png', 'MI_Ornaments': 'T_Ornaments_BaseColor.png',
        'MI_Concrete': 'T_Concrete_BaseColor.png'}
def _raster(name, w, hh, cw, ch):
    """petit rasteriseur orthographique (numpy) : vue de face du module répété
    autour de lui. Renvoie albedo, relief z, normales, classe, intérieur, uv pièce."""
    alb = np.zeros((ch, cw, 3), np.float32); zb = np.full((ch, cw), -9.0, np.float32)
    nrm = np.zeros((ch, cw, 3), np.float32); nrm[..., 2] = 1
    cls = np.zeros((ch, cw), np.float32)
    inte = np.zeros((ch, cw), np.float32); room = np.zeros((ch, cw, 2), np.float32)
    texc = {}
    def tex(f):
        if f not in texc: texc[f] = np.asarray(Image.open(TEX + f).convert('RGB'), np.float32) / 255.0
        return texc[f]
    for dx in (-w, 0, w):
        for dy in (-hh, 0, hh):
            for mat, v, n, uv, f in bake.geo(name):
                V = v + np.array([dx, dy, 0], np.float32)
                px = (V[:, 0] + cw/PX/2) * PX - 0.5
                py = (hh/2 + ch/PX/2 - V[:, 1]) * PX - 0.5
                T = tex(TEXF[mat]) if mat in TEXF else None
                base = np.array(BASE.get(mat, (1, 1, 1)), np.float32)
                for t in f:
                    x0, x1, x2 = px[t]; y0, y1, y2 = py[t]
                    den = (y1-y2)*(x0-x2) + (x2-x1)*(y0-y2)
                    if abs(den) < 1e-9: continue
                    jmin = max(int(np.floor(min(x0, x1, x2))), 0); jmax = min(int(np.ceil(max(x0, x1, x2))), cw-1)
                    imin = max(int(np.floor(min(y0, y1, y2))), 0); imax = min(int(np.ceil(max(y0, y1, y2))), ch-1)
                    if jmin > jmax or imin > imax: continue
                    J, I = np.meshgrid(np.arange(jmin, jmax+1), np.arange(imin, imax+1))
                    l0 = ((y1-y2)*(J-x2) + (x2-x1)*(I-y2)) / den
                    l1 = ((y2-y0)*(J-x2) + (x0-x2)*(I-y2)) / den
                    l2 = 1 - l0 - l1
                    ins = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4)
                    if not ins.any(): continue
                    I, J, l0, l1, l2 = I[ins], J[ins], l0[ins], l1[ins], l2[ins]
                    z = l0*V[t[0], 2] + l1*V[t[1], 2] + l2*V[t[2], 2]
                    vis = z > zb[I, J]
                    if not vis.any(): continue
                    I, J, l0, l1, l2, z = I[vis], J[vis], l0[vis], l1[vis], l2[vis], z[vis]
                    zb[I, J] = z
                    nn = l0[:, None]*n[t[0]] + l1[:, None]*n[t[1]] + l2[:, None]*n[t[2]]
                    nrm[I, J] = nn / np.maximum(np.linalg.norm(nn, axis=1, keepdims=True), 1e-6)
                    u = l0[:, None]*uv[t[0]] + l1[:, None]*uv[t[1]] + l2[:, None]*uv[t[2]]
                    if mat == 'MI_FakeInterior':
                        alb[I, J] = (0.05, 0.05, 0.06); inte[I, J] = 1.0; cls[I, J] = 0
                        room[I, J] = np.clip(u, 0, 1)
                    else:
                        inte[I, J] = 0.0; cls[I, J] = CLASS.get(mat, 0)
                        if T is not None:
                            th, tw = T.shape[:2]
                            tx = (np.mod(u[:, 0], 1.0) * tw).astype(int) % tw
                            ty = (np.mod(1.0 - u[:, 1], 1.0) * th).astype(int) % th
                            alb[I, J] = T[ty, tx] * base
                        else:
                            alb[I, J] = 0.5 * base
    return alb, zb, nrm, cls, inte, room

def bake_atlas(out_dir):
    cells = {}
    W = 2048
    x = y = 0; rowh = 3*PX + 2*PAD
    for name, w, hh in IMP:
        cw = w*PX + 2*PAD
        if x + cw > W: x = 0; y += rowh
        cells[name] = dict(x=x+PAD, y=y+PAD, w=w*PX, h=hh*PX, width=w, height=hh)
        x += cw
    H = y + rowh; H = (H + 3)//4*4
    A = np.zeros((H, W, 4), np.uint8); N = np.zeros((H, W, 4), np.uint8); R = np.zeros((H, W, 4), np.uint8)
    for name, w, hh in IMP:
        c = cells[name]
        cw, ch = c['w'] + 2*PAD, c['h'] + 2*PAD
        alb, z, nrm, cls, inte, room = _raster(name, w, hh, cw, ch)
        z = np.where(z < -5, -0.3, z)
        ao = np.clip(1.0 + z*2.2, 0.45, 1.0)          # creux plus sombres
        sl = (slice(c['y']-PAD, c['y']-PAD+ch), slice(c['x']-PAD, c['x']-PAD+cw))
        a = np.zeros((ch, cw, 4), np.uint8)
        a[..., :3] = np.clip(alb * ao[..., None] * 255, 0, 255).astype(np.uint8)
        a[..., 3] = np.clip((z + 0.3)/0.6*255, 0, 255).astype(np.uint8)
        n = np.zeros((ch, cw, 4), np.uint8)
        n[..., 0] = np.clip((nrm[..., 0]*0.5+0.5)*255, 0, 255); n[..., 1] = np.clip((nrm[..., 1]*0.5+0.5)*255, 0, 255)
        n[..., 2] = (cls/3.0*255).astype(np.uint8); n[..., 3] = (inte*255).astype(np.uint8)
        rr = np.zeros((ch, cw, 4), np.uint8); rr[..., 0] = room[..., 0]*255; rr[..., 1] = room[..., 1]*255; rr[..., 3] = 255
        A[sl] = a; N[sl] = n; R[sl] = rr
    os.makedirs(out_dir, exist_ok=True)
    Image.fromarray(A).save(os.path.join(out_dir, 'facade_albedo.png'))
    Image.fromarray(N).save(os.path.join(out_dir, 'facade_normal.png'))
    Image.fromarray(R).save(os.path.join(out_dir, 'facade_room.png'))
    meta = dict(width=W, height=H, px_per_m=PX, cells=cells)
    json.dump(meta, open(os.path.join(out_dir, 'facade_atlas.json'), 'w'), indent=1)
    return meta

if __name__ == '__main__':
    import sys
    m = bake_atlas(sys.argv[1])
    print(m['width'], m['height'], len(m['cells']))
