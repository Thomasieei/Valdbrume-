"""Fusion des modules placés en gros maillages par zone et par matériau.
Sortie : un .glb par zone (matériaux nommés, sans textures : Godot applique
les matériaux partagés), + données de rendu d'aperçu local."""
import json, math, struct, numpy as np, trimesh
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KIT = os.environ.get('KIT_DIR', os.path.join(ROOT, 'kit', 'downtown'))
_geo = {}
DROP = {'MI_Glass'}          # verre transparent supprimé : le shader d'intérieur s'en charge
WALL_MATS = {'MI_RedBrick', 'MI_RedBrick_Pale', 'MI_InteriorWall'}
STONE_MATS = {'MI_Trim', 'MI_Trim_MetalConcrete', 'MI_Concrete'}
ACCENT_MATS = {'MI_Trim_Dark', 'MI_Trim_Green'}
MAT_BASE = {'MI_RedBrick_Pale': (1.32, 1.22, 1.08), 'MI_InteriorWall': (0.55, 0.55, 0.55)}
ENC = 0.5        # les teintes (jusqu'à 2.0) sont stockées x0.5 dans les couleurs de sommets

FACADE_PREFIX = ('Brick_', 'Trim_', 'Metal_', 'Cornice_', 'Roof_Slate', 'DoorFrame_')
KEEP_BACK = ('Column', 'Corner', 'Stairs')

def _simplify(v, n, uv, f, ratio, err):
    """simplification topologique (positions) ; les coutures d'UV et bords sont
    verrouillés, donc textures et raccords entre modules restent intacts."""
    import meshoptimizer as mo
    if len(f) < 24: return f
    idx = np.ascontiguousarray(f.reshape(-1), np.uint32)
    dst = np.zeros_like(idx)
    k = mo.simplify(dst, idx, np.ascontiguousarray(v, np.float32),
                    target_index_count=max(3, int(len(idx)*ratio)//3*3), target_error=err,
                    options=mo.SIMPLIFY_LOCK_BORDER)
    return dst[:k].reshape(-1, 3).copy()

def geo(name, lite=False):
    """liste de (material, verts, normals, uvs, faces) pour un module.
    - supprime le verre transparent et les faces tournées vers l'intérieur
      du bâtiment (jamais visibles : on n'entre pas dans ces immeubles) ;
    - lite=True : version allégée (étages hauts, vus de plus loin)."""
    key = (name, lite)
    if key in _geo: return _geo[key]
    s = trimesh.load(f'{KIT}/{name}.gltf', force='scene')
    out = []
    facade = name.startswith(FACADE_PREFIX) and not any(k in name for k in KEEP_BACK)
    for node in s.graph.nodes_geometry:
        t, g = s.graph[node]
        m = s.geometry[g]
        mat = m.visual.material.name
        if mat in DROP: continue
        v = np.asarray(trimesh.transform_points(m.vertices, t), np.float32)
        n = np.asarray(trimesh.transform_points(m.vertex_normals, t, translate=False), np.float32)
        uv = np.array(m.visual.uv, dtype=np.float32) if getattr(m.visual, 'uv', None) is not None else np.zeros((len(v), 2), np.float32)
        f = np.asarray(m.faces, np.uint32)
        if facade:
            fn = np.cross(v[f[:, 1]]-v[f[:, 0]], v[f[:, 2]]-v[f[:, 0]])
            fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-9)
            f = f[fn[:, 2] > -0.5]
            if mat == 'MI_InteriorWall':
                f = f[fn[fn[:, 2] > -0.5][:, 2] < 0.5] if len(f) else f
        if lite and len(f):
            f = _simplify(v, n, uv, f, 0.35, 0.006)
        if len(f): out.append((mat, v, n, uv, f))
    _geo[key] = out
    return out

def rot(ry):
    c, s = math.cos(math.radians(ry)), math.sin(math.radians(ry))
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], np.float32)

def room_color(x, y, z):
    """paramètres de pièce pour le shader d'intérieur, dérivés de la position
    (déterministe) : r = type de pièce, g = allumée/éteinte, b = rideaux."""
    h = (int(round(x*7.1)) * 73856093) ^ (int(round(y*3.3)) * 19349663) ^ (int(round(z*7.7)) * 83492791)
    h &= 0xffffffff
    r = (h % 3) / 2.0
    g = 1.0 if (h >> 8) % 10 < 6 else 0.0
    b = ((h >> 16) % 5) / 4.0
    return (r, g, b)

class Bucket:
    def __init__(s): s.v=[]; s.n=[]; s.uv=[]; s.c=[]; s.f=[]; s.uv2=[]; s.count=0
    def add(s, v, n, uv, c, f, uv2=None):
        s.f.append(f + s.count); s.v.append(v); s.n.append(n); s.uv.append(uv); s.c.append(c)
        s.uv2.append(uv2 if uv2 is not None else np.zeros((len(v), 2), np.float32)); s.count += len(v)
    def arrays(s):
        return (np.concatenate(s.v), np.concatenate(s.n), np.concatenate(s.uv), np.concatenate(s.c), np.concatenate(s.f))
    def uv2s(s): return np.concatenate(s.uv2)

def place(buckets, name, x, y, z, ry, tint, lite=False):
    R = rot(ry); T = np.array([x, y, z], np.float32)
    if not isinstance(tint[0], tuple): tint = (tint, tint, tint)
    if len(tint) == 2: tint = (tint[0], tint[1], tint[1])
    tw, ts, ta = tint
    for mat, v, n, uv, f in geo(name, lite):
        V = v @ R.T + T; N = n @ R.T
        if mat.startswith('MI_FakeInterior'):
            cx, cy, cz = V.mean(0)
            col = np.tile(np.array(room_color(cx, cy, cz) + (1,), np.float32), (len(V), 1))
            mat = 'MI_FakeInterior'
        else:
            t = tw if mat in WALL_MATS else ts if mat in STONE_MATS else ta if mat in ACCENT_MATS else (1, 1, 1)
            t = np.array(t, np.float32) * np.array(MAT_BASE.get(mat, (1, 1, 1)), np.float32) * ENC
            col = np.tile(np.append(np.clip(t, 0, 1), 1.0).astype(np.float32), (len(V), 1))
            if mat in ACCENT_MATS: mat = 'MI_Trim'          # même texture : un seul matériau
        buckets.setdefault(mat, Bucket()).add(V, N, uv, col, f)

ATLAS = None
def impostor(buckets, name, x, y, z, ry, tint, pal_index):
    """façade imprimée : 2 triangles, UV dans l'atlas, teintes mur/pierre/accent."""
    c = ATLAS['cells'][name]; W, H = ATLAS['width'], ATLAS['height']
    w = c['width']
    R = rot(ry); T = np.array([x, y, z], np.float32)
    v = np.array([[-w/2, 0, 0], [w/2, 0, 0], [w/2, 3, 0], [-w/2, 3, 0]], np.float32) @ R.T + T
    n = np.tile(np.array([0, 0, 1], np.float32) @ R.T, (4, 1))
    u0, u1 = c['x']/W, (c['x']+c['w'])/W; v0, v1 = c['y']/H, (c['y']+c['h'])/H
    uv = np.array([[u0, v1], [u1, v1], [u1, v0], [u0, v0]], np.float32)
    tw, ts, ta = tint
    col = np.tile(np.append(np.clip(np.array(tw, np.float32)*ENC, 0, 1), 1.0).astype(np.float32), (4, 1))
    uv2 = np.tile(np.array([pal_index(ts) + 0.5, pal_index(ta) + 0.5], np.float32), (4, 1))
    f = np.array([[0, 1, 2], [0, 2, 3]], np.uint32)
    buckets.setdefault('MI_Facade', Bucket()).add(v, n, uv, col, f, uv2)

def quad(buckets, mat, cx, y, cz, w, d, uvscale, normal_up=True, color=(0.5, 0.5, 0.5)):
    v = np.array([[cx-w/2, y, cz-d/2], [cx+w/2, y, cz-d/2], [cx+w/2, y, cz+d/2], [cx-w/2, y, cz+d/2]], np.float32)
    n = np.tile(np.array([0, 1, 0], np.float32), (4, 1))
    uv = (v[:, [0, 2]] / uvscale).astype(np.float32)
    f = np.array([[0, 2, 1], [0, 3, 2]], np.uint32)
    c = np.tile(np.array(tuple(color) + (1,), np.float32), (4, 1))
    buckets.setdefault(mat, Bucket()).add(v, n, uv, c, f)

def write_glb(path, buckets, name='chunk'):
    """écrit un glb : un mesh, une primitive par matériau."""
    import pygltflib as G
    gl = G.GLTF2(); gl.scenes = [G.Scene(nodes=[0])]; gl.scene = 0
    gl.nodes = [G.Node(mesh=0, name=name)]
    blob = bytearray(); prims = []; mats = []
    def view(data, target):
        nonlocal blob
        while len(blob) % 4: blob.append(0)
        off = len(blob); blob += data
        gl.bufferViews.append(G.BufferView(buffer=0, byteOffset=off, byteLength=len(data), target=target))
        return len(gl.bufferViews) - 1
    for mat, b in sorted(buckets.items()):
        V, N, UV, C, F = b.arrays()
        nl = np.linalg.norm(N, axis=1, keepdims=True); N = N / np.maximum(nl, 1e-6)
        mi = len(mats); mats.append(G.Material(name=mat, doubleSided=False))
        acc = {}
        cols = [('POSITION', V, 'VEC3'), ('NORMAL', N.astype(np.float32), 'VEC3'), ('TEXCOORD_0', UV, 'VEC2'), ('COLOR_0', C, 'VEC4')]
        if mat == 'MI_Facade': cols.append(('TEXCOORD_1', b.uv2s(), 'VEC2'))
        for key, arr, typ in cols:
            arr = np.ascontiguousarray(arr, np.float32)
            bv = view(arr.tobytes(), G.ARRAY_BUFFER)
            a = G.Accessor(bufferView=bv, componentType=G.FLOAT, count=len(arr), type=typ)
            if key == 'POSITION': a.min = arr.min(0).tolist(); a.max = arr.max(0).tolist()
            gl.accessors.append(a); acc[key] = len(gl.accessors) - 1
        idx = np.ascontiguousarray(F.reshape(-1), np.uint32)
        bv = view(idx.tobytes(), G.ELEMENT_ARRAY_BUFFER)
        gl.accessors.append(G.Accessor(bufferView=bv, componentType=G.UNSIGNED_INT, count=len(idx), type='SCALAR'))
        prims.append(G.Primitive(attributes=G.Attributes(**acc), indices=len(gl.accessors)-1, material=mi))
    gl.meshes = [G.Mesh(primitives=prims, name=name)]
    gl.materials = mats
    gl.buffers = [G.Buffer(byteLength=len(blob))]
    gl.set_binary_blob(bytes(blob))
    gl.save_binary(path)

def stats(buckets):
    return sum(len(b.arrays()[4]) for b in buckets.values())
