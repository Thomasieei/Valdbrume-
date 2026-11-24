"""Construit toute la ville : bâtiments + rues -> zones fusionnées (.glb) + city.json"""
import sys, os, json, math, time
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from builder import City
import layout, streets, bake, impostor
from builder import pal_index

CHUNK = 48.0
IMP_FROM = 4.0         # tous les étages au-dessus du rez-de-chaussée : façades imprimées

def run(out_dir, preview_only=False, atlas_dir=None):
    t0 = time.time()
    bake.ATLAS = json.load(open(os.path.join(atlas_dir or out_dir, 'facade_atlas.json')))
    c = City()
    for l in layout.LOTS: c.lot(l)
    c.build_lots()
    ground_quads = []
    streets.build_streets(c, lambda *a: ground_quads.append(a))
    chunks = {}; far = {}
    def key(x, z): return (int(math.floor(x / CHUNK)), int(math.floor(z / CHUNK)))
    IMPS = {n for n, w, h in impostor.IMP}
    for (m, x, y, z, ry, t, tag, sy) in c.items:
        k = key(x, z)
        b = chunks.setdefault(k, {}); bf = far.setdefault(k, {})
        if m == '@roof':
            bake.quad(b, 'MI_Roof', x, y + 0.02, z, t[0], t[1], 4.0)
            bake.quad(bf, 'MI_Roof', x, y + 0.02, z, t[0], t[1], 4.0); continue
        if m == '@box':
            x0, y0, z0, x1, y1, z1, mat, uvs = t
            for tgt in (b, bf): bake.box(tgt, mat, x0, y0, z0, x1, y1, z1, uvs)
            continue
        if m == '@quad':
            mat, w, d, uvs, col = t
            for tgt in (b, bf): bake.quad(tgt, mat, x, y, z, w, d, uvs, color=col)
            continue
        if m == '@door':
            bake.door_back(b, x, y, z, ry); continue
        if m == '@water':
            for tgt in (b, bf): bake.quad(tgt, 'MI_Water', x, y, z, t[0], t[1], 8.0)
            continue
        if tag == 'plinth':
            bake.place(b, m, x, y, z, ry, t, remap={'MI_Trim_MetalConcrete': 'MI_Concrete'}, sy=sy)
            bake.place(bf, m, x, y, z, ry, t, remap={'MI_Trim_MetalConcrete': 'MI_Concrete'}, sy=sy); continue
        if m in IMPS:
            bake.impostor(bf, m, x, y, z, ry, t, pal_index)       # loin : toujours imprimé
            if y >= IMP_FROM or tag == 'back' or m.endswith('_1'):
                bake.impostor(b, m, x, y, z, ry, t, pal_index); continue
        elif tag == 'ground':
            bake.quad(bf, 'MI_Concrete', x, 0.0, z, 3.0, 3.0, 6.0, color=(0.56, 0.56, 0.56))
        bake.place(b, m, x, y, z, ry, t, lite=(y >= 10.0 and tag != 'ground'), sy=sy)
    # chaussées : découpées par zone pour la culture de visibilité
    for (mat, cx, y, cz, w, d, uvs) in ground_quads:
        x0, x1, z0, z1 = cx - w/2, cx + w/2, cz - d/2, cz + d/2
        gx0 = math.floor(x0 / CHUNK); gx1 = math.ceil(x1 / CHUNK)
        gz0 = math.floor(z0 / CHUNK); gz1 = math.ceil(z1 / CHUNK)
        for gx in range(gx0, gx1):
            for gz in range(gz0, gz1):
                a0, a1 = max(x0, gx*CHUNK), min(x1, (gx+1)*CHUNK)
                b0, b1 = max(z0, gz*CHUNK), min(z1, (gz+1)*CHUNK)
                if a1 - a0 > 0.01 and b1 - b0 > 0.01:
                    for tgt in (chunks, far):
                        bake.quad(tgt.setdefault((gx, gz), {}), mat, (a0+a1)/2, y, (b0+b1)/2, a1-a0, b1-b0, uvs)
    total = 0
    meta = {'chunks': [], 'boxes': c.boxes, 'occluders': c.occluders,
            'lots': [dict(x0=l.x0, z0=l.z0, x1=l.x1, z1=l.z1, h=l.height, name=l.name) for l in c.lots]}
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    total_far = 0
    for (gx, gz), b in sorted(chunks.items()):
        tris = bake.stats(b); total += tris
        bf = far.get((gx, gz), {}); tf = bake.stats(bf) if bf else 0; total_far += tf
        name = f'z_{gx}_{gz}'.replace('-', 'm')
        origin = ((gx + 0.5) * CHUNK, 0.0, (gz + 0.5) * CHUNK)
        if out_dir and not preview_only:
            bake.write_glb(os.path.join(out_dir, name + '.glb'), b, 'proche', origin, extra=[('loin', bf)] if bf else [])
        meta['chunks'].append(dict(name=name, gx=gx, gz=gz, tris=tris, tris_far=tf))
    print(f'version lointaine : {total_far/1e6:.2f} M triangles')
    print(f'{len(c.lots)} bâtiments, {len(c.items)} modules, {len(chunks)} zones, {total/1e6:.2f} M triangles, {time.time()-t0:.0f}s')
    if out_dir:
        json.dump(meta, open(os.path.join(out_dir, 'city.json'), 'w'))
    return chunks, c

if __name__ == '__main__':
    run(sys.argv[1] if len(sys.argv) > 1 else None)
