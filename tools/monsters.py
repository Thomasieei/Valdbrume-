"""Prépare les monstres pour le mobile : maillage simplifié (les sommets, poids
de peau et UV ne bougent pas, seuls les triangles sont réduits), textures
ramenées à 1024 px, vernis (clearcoat) retiré (coûteux et invisible de loin).
usage : python3 monsters.py source.glb sortie.glb [triangles visés]"""
import json, struct, sys, io
import numpy as np
import meshoptimizer as mo
from PIL import Image

COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def load(path):
    b = open(path, 'rb').read()
    jl = struct.unpack('<I', b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    o = 20 + jl
    bl = struct.unpack('<I', b[o:o + 4])[0]
    return j, bytearray(b[o + 8:o + 8 + bl])


def acc_data(j, bin_, i):
    a = j['accessors'][i]
    bv = j['bufferViews'][a['bufferView']]
    dt = COMP[a['componentType']]
    n = NCOMP[a['type']]
    off = bv.get('byteOffset', 0) + a.get('byteOffset', 0)
    stride = bv.get('byteStride', 0)
    if stride and stride != n * np.dtype(dt).itemsize:
        raw = np.frombuffer(bin_, np.uint8, a['count'] * stride, off).reshape(a['count'], stride)
        return raw[:, :n * np.dtype(dt).itemsize].copy().view(dt).reshape(a['count'], n)
    return np.frombuffer(bin_, dt, a['count'] * n, off).reshape(a['count'], n).copy()


def main(src, dst, target=14000):
    j, bin_ = load(src)
    prims = [p for m in j['meshes'] for p in m['primitives'] if 'indices' in p]
    total = sum(j['accessors'][p['indices']]['count'] // 3 for p in prims)
    ratio = min(1.0, target / total)
    out = bytearray()
    views = []

    def add_view(data, target_kind=None):
        while len(out) % 4: out.append(0)
        views.append({'buffer': 0, 'byteOffset': len(out), 'byteLength': len(data)})
        if target_kind: views[-1]['target'] = target_kind
        out.extend(data)
        return len(views) - 1

    # on recopie toutes les vues existantes, puis on remplace les index
    remap = {}
    for i, bv in enumerate(j['bufferViews']):
        o = bv.get('byteOffset', 0)
        nv = dict(bv); data = bytes(bin_[o:o + bv['byteLength']])
        while len(out) % 4: out.append(0)
        nv['byteOffset'] = len(out); out.extend(data)
        views.append(nv); remap[i] = len(views) - 1
    after = 0
    for p in prims:
        pos = np.ascontiguousarray(acc_data(j, bin_, p['attributes']['POSITION']), np.float32)
        idx = np.ascontiguousarray(acc_data(j, bin_, p['indices']).reshape(-1), np.uint32)
        if ratio < 1.0 and len(idx) > 300:
            d = np.zeros_like(idx)
            k = mo.simplify(d, idx, pos, target_index_count=max(3, int(len(idx) * ratio) // 3 * 3),
                            target_error=0.02, options=mo.SIMPLIFY_LOCK_BORDER)
            idx = d[:k]
        after += len(idx) // 3
        big = pos.shape[0] > 65535
        data = idx.astype(np.uint32 if big else np.uint16).tobytes()
        v = add_view(data, 34963)
        j['accessors'].append({'bufferView': v, 'componentType': 5125 if big else 5123,
                               'count': int(len(idx)), 'type': 'SCALAR'})
        p['indices'] = len(j['accessors']) - 1
    # textures 1024 px max
    for im in j.get('images', []):
        bv = views[remap[im['bufferView']]]
        o = bv['byteOffset']
        img = Image.open(io.BytesIO(bytes(out[o:o + bv['byteLength']])))
        if max(img.size) > 1024:
            img.thumbnail((1024, 1024), Image.LANCZOS)
        buf = io.BytesIO(); img.convert('RGB').save(buf, 'JPEG', quality=88)
        im['bufferView'] = add_view(buf.getvalue())
        im['mimeType'] = 'image/jpeg'
    for a in j['accessors']:
        if 'bufferView' in a and a['bufferView'] in remap: a['bufferView'] = remap[a['bufferView']]
    for m in j.get('materials', []):
        m.pop('extensions', None)
    j.pop('extensionsUsed', None); j.pop('extensionsRequired', None)
    j['bufferViews'] = views
    j['buffers'] = [{'byteLength': len(out)}]
    # compacte : on retire les vues devenues inutiles en réécrivant tout
    used = set(a['bufferView'] for a in j['accessors'] if 'bufferView' in a) | set(i['bufferView'] for i in j.get('images', []))
    final = bytearray(); newidx = {}; nviews = []
    for i, bv in enumerate(views):
        if i not in used: continue
        while len(final) % 4: final.append(0)
        nb = dict(bv); o = bv['byteOffset']; nb['byteOffset'] = len(final)
        final.extend(out[o:o + bv['byteLength']]); newidx[i] = len(nviews); nviews.append(nb)
    for a in j['accessors']:
        if 'bufferView' in a: a['bufferView'] = newidx[a['bufferView']]
    for im in j.get('images', []): im['bufferView'] = newidx[im['bufferView']]
    j['bufferViews'] = nviews
    while len(final) % 4: final.append(0)
    j['buffers'] = [{'byteLength': len(final)}]
    js = json.dumps(j, separators=(',', ':')).encode()
    while len(js) % 4: js += b' '
    glb = struct.pack('<III', 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(final))
    glb += struct.pack('<II', len(js), 0x4E4F534A) + js + struct.pack('<II', len(final), 0x004E4942) + bytes(final)
    open(dst, 'wb').write(glb)
    print(f'{src.split("/")[-1]} : {total} -> {after} triangles, {len(glb)//1024} Ko')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], int(sys.argv[3]) if len(sys.argv) > 3 else 14000)
