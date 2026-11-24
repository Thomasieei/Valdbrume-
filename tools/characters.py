"""Les 11 personnages : le héros (joueur) et 10 habitants de la ville.

Base : Universal Base Characters (Quaternius, CC0), même squelette que les
254 animations UAL1/UAL2. Les vêtements sont générés à partir du corps :
chaque vêtement est une « peau » épousant les zones du corps qu'il couvre
(décalée de quelques millimètres le long des normales), avec les mêmes poids
de squelette : il suit donc exactement chaque mouvement. Les parties du corps
cachées sous les vêtements sont retirées (pas de transpercement, moins de
triangles). Chaque personnage est décrit à la main ci-dessous."""
import os, sys, json, copy, numpy as np
import pygltflib as G

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, 'vendor', 'quaternius', 'base_characters')
OUT = os.path.join(ROOT, 'project', 'assets', 'characters', 'gen')

# ----------------------------------------------------------------- distribution
# Chaque personnage : corps, coiffure, couleurs, tenue (haut, bas, chaussures,
# extra), taille. Histoire et rôle : utilisés par le système de vie en jeu.
CAST = [
 dict(id='heros', nom='Le Chasseur', corps='M', role='joueur',
      cheveux='Hair_SimpleParted', c_cheveux=(0.10, 0.08, 0.07), barbe=False, peau=1.0, yeux=(0.35, 0.25, 0.18), taille=1.0,
      haut=dict(type='veste', couleur=(0.10, 0.11, 0.13), tissu='cuir', manches='longues', col=(0.75, 0.12, 0.10)),
      sous=dict(type='tshirt', couleur=(0.16, 0.17, 0.19), tissu='coton'),
      bas=dict(type='pantalon', couleur=(0.14, 0.15, 0.16), tissu='toile'),
      pieds=dict(type='bottes', couleur=(0.07, 0.06, 0.06)),
      histoire="Un chasseur de rang E qui vient d'arriver en ville. Personne ne le connaît encore."),
 dict(id='lea', nom='Léa Moreau', corps='F', role='boulangère',
      cheveux='Hair_Buns', c_cheveux=(0.42, 0.22, 0.10), peau=1.08, yeux=(0.25, 0.45, 0.30), taille=0.96,
      haut=dict(type='tshirt', couleur=(0.78, 0.55, 0.18), tissu='coton', manches='courtes'),
      bas=dict(type='pantalon', couleur=(0.22, 0.27, 0.40), tissu='jean'),
      pieds=dict(type='baskets', couleur=(0.90, 0.90, 0.88)),
      extra=dict(type='tablier', couleur=(0.93, 0.90, 0.84)),
      histoire="Tient la boulangerie du Vieux Quartier depuis la mort de sa mère. Se lève à 4 h, connaît tout le monde."),
 dict(id='hugo', nom='Hugo Laurent', corps='M', role='coursier',
      cheveux='Hair_Buzzed', c_cheveux=(0.20, 0.13, 0.08), barbe=False, peau=0.92, yeux=(0.30, 0.22, 0.15), taille=0.97,
      haut=dict(type='veste', couleur=(0.95, 0.55, 0.10), tissu='nylon', manches='longues', col=(0.15, 0.15, 0.15)),
      sous=dict(type='tshirt', couleur=(0.12, 0.12, 0.12), tissu='coton'),
      bas=dict(type='short', couleur=(0.15, 0.16, 0.18), tissu='toile'),
      pieds=dict(type='baskets', couleur=(0.20, 0.55, 0.85)),
      histoire="Coursier à vélo, toujours en retard. Rêve de devenir chasseur et s'entraîne en cachette."),
 dict(id='ines', nom='Inès Diallo', corps='F', role='pharmacienne',
      cheveux='Hair_Long', c_cheveux=(0.05, 0.04, 0.04), peau=0.55, yeux=(0.20, 0.14, 0.10), taille=1.02,
      haut=dict(type='blouse', couleur=(0.95, 0.96, 0.97), tissu='coton', manches='longues'),
      sous=dict(type='tshirt', couleur=(0.45, 0.70, 0.72), tissu='coton'),
      bas=dict(type='pantalon', couleur=(0.18, 0.20, 0.25), tissu='toile'),
      pieds=dict(type='baskets', couleur=(0.95, 0.95, 0.95)),
      histoire="Étudiante en médecine, travaille à la pharmacie de l'avenue du Portail. Un don de soin latent."),
 dict(id='marc', nom='Marc Duval', corps='M', role='gardien',
      cheveux='Hair_Buzzed', c_cheveux=(0.55, 0.55, 0.55), barbe=True, peau=0.98, yeux=(0.40, 0.48, 0.55), taille=1.03,
      haut=dict(type='veste', couleur=(0.20, 0.24, 0.20), tissu='toile', manches='longues', col=(0.30, 0.25, 0.18)),
      sous=dict(type='pull', couleur=(0.45, 0.40, 0.34), tissu='laine'),
      bas=dict(type='pantalon', couleur=(0.26, 0.24, 0.22), tissu='toile'),
      pieds=dict(type='bottes', couleur=(0.25, 0.17, 0.10)),
      histoire="Ancien chasseur de rang B, devenu gardien de nuit à la gare. Une vieille blessure. Il en sait long sur les portails."),
 dict(id='sofia', nom='Sofia Rossi', corps='F', role='fleuriste',
      cheveux='Hair_Long', c_cheveux=(0.62, 0.30, 0.12), peau=1.12, yeux=(0.30, 0.50, 0.35), taille=0.95,
      haut=dict(type='pull', couleur=(0.80, 0.55, 0.60), tissu='laine', manches='longues'),
      bas=dict(type='pantalon', couleur=(0.85, 0.82, 0.72), tissu='toile'),
      pieds=dict(type='baskets', couleur=(0.40, 0.30, 0.25)),
      extra=dict(type='tablier', couleur=(0.25, 0.42, 0.28)),
      histoire="Fleuriste sur la place du Portail. Rieuse, curieuse, elle remarque Karim chaque matin."),
 dict(id='karim', nom='Karim Benali', corps='M', role='mécanicien',
      cheveux='Hair_SimpleParted', c_cheveux=(0.07, 0.05, 0.04), barbe=True, peau=0.78, yeux=(0.22, 0.15, 0.10), taille=1.01,
      haut=dict(type='combinaison', couleur=(0.18, 0.28, 0.45), tissu='toile', manches='courtes'),
      bas=dict(type='pantalon', couleur=(0.18, 0.28, 0.45), tissu='toile'),
      pieds=dict(type='bottes', couleur=(0.12, 0.10, 0.09)),
      histoire="Mécanicien au garage de la rue des Arches. Endetté auprès d'une bande du quartier."),
 dict(id='chloe', nom='Chloé Martin', corps='F', role='journaliste',
      cheveux='Hair_BuzzedFemale', c_cheveux=(0.85, 0.75, 0.55), peau=1.05, yeux=(0.35, 0.45, 0.65), taille=1.0,
      haut=dict(type='veste', couleur=(0.55, 0.45, 0.30), tissu='toile', manches='longues', col=(0.45, 0.36, 0.24)),
      sous=dict(type='tshirt', couleur=(0.10, 0.10, 0.12), tissu='coton'),
      bas=dict(type='pantalon', couleur=(0.12, 0.13, 0.16), tissu='jean'),
      pieds=dict(type='bottes', couleur=(0.10, 0.08, 0.07)),
      histoire="Journaliste indépendante. Enquête sur les portails qui s'ouvrent en ville et sur ce que la mairie cache."),
 dict(id='theo', nom='Théo Girard', corps='M', role='serveur',
      cheveux='Hair_SimpleParted', c_cheveux=(0.75, 0.55, 0.25), barbe=False, peau=1.10, yeux=(0.30, 0.50, 0.70), taille=0.95,
      haut=dict(type='chemise', couleur=(0.96, 0.96, 0.96), tissu='coton', manches='longues'),
      bas=dict(type='pantalon', couleur=(0.08, 0.08, 0.09), tissu='toile'),
      pieds=dict(type='chaussures', couleur=(0.06, 0.05, 0.05)),
      extra=dict(type='tablier', couleur=(0.10, 0.10, 0.11)),
      histoire="Serveur au café du boulevard, 19 ans. Timide, admire les chasseurs. Facile à intimider."),
 dict(id='nadia', nom='Nadia Kovač', corps='F', role='policière',
      cheveux='Hair_Buns', c_cheveux=(0.12, 0.09, 0.07), peau=1.0, yeux=(0.40, 0.35, 0.25), taille=1.03,
      haut=dict(type='veste', couleur=(0.10, 0.14, 0.26), tissu='toile', manches='longues', col=(0.85, 0.80, 0.30)),
      sous=dict(type='chemise', couleur=(0.55, 0.65, 0.80), tissu='coton'),
      bas=dict(type='pantalon', couleur=(0.10, 0.14, 0.26), tissu='toile'),
      pieds=dict(type='chaussures', couleur=(0.05, 0.05, 0.05)),
      histoire="Lieutenante de police. Méfiante envers les chasseurs, qui font la loi à sa place."),
 dict(id='victor', nom='Victor Lemaire', corps='M', role="homme d'affaires",
      cheveux='Hair_SimpleParted', c_cheveux=(0.30, 0.28, 0.26), barbe=False, peau=1.02, yeux=(0.45, 0.45, 0.42), taille=1.04,
      haut=dict(type='costume', couleur=(0.13, 0.14, 0.17), tissu='laine', manches='longues', col=(0.55, 0.10, 0.12)),
      sous=dict(type='chemise', couleur=(0.92, 0.93, 0.96), tissu='coton'),
      bas=dict(type='pantalon', couleur=(0.13, 0.14, 0.17), tissu='laine'),
      pieds=dict(type='chaussures', couleur=(0.08, 0.05, 0.04)),
      histoire="Dirige une société de « gestion des portails » à la Tour Valdbrume. Charmant en public."),
]
FIGURANTS = [
 dict(id='voyou1', nom='Le Balafré', corps='M', role='voyou', cheveux='Hair_Buzzed', c_cheveux=(0.05, 0.05, 0.05), barbe=True, peau=0.85, yeux=(0.2, 0.15, 0.1), taille=1.05,
      haut=dict(type='veste', couleur=(0.05, 0.05, 0.06), tissu='cuir', manches='longues', col=(0.5, 0.5, 0.5)),
      sous=dict(type='tshirt', couleur=(0.55, 0.08, 0.08), tissu='coton'),
      bas=dict(type='pantalon', couleur=(0.10, 0.10, 0.11), tissu='jean'), pieds=dict(type='bottes', couleur=(0.05, 0.05, 0.05)),
      histoire="Encaisse les dettes pour une bande du quartier."),
 dict(id='voyou2', nom='Le Rouquin', corps='M', role='voyou', cheveux='Hair_SimpleParted', c_cheveux=(0.55, 0.22, 0.08), barbe=False, peau=1.12, yeux=(0.3, 0.4, 0.3), taille=0.98,
      haut=dict(type='veste', couleur=(0.18, 0.20, 0.16), tissu='nylon', manches='longues', col=(0.1, 0.1, 0.1)),
      sous=dict(type='tshirt', couleur=(0.85, 0.85, 0.85), tissu='coton'),
      bas=dict(type='pantalon', couleur=(0.25, 0.25, 0.27), tissu='toile'), pieds=dict(type='baskets', couleur=(0.9, 0.9, 0.9)),
      histoire="Suit le Balafré partout."),
]

# ----------------------------------------------------------------- géométrie
def _landmarks(g, jn):
    """positions de repos des articulations (pose en T), depuis les matrices de liaison inverses."""
    ibm = _acc(g, g.skins[0].inverseBindMatrices).reshape(-1, 4, 4)
    L = {}
    for i, n in enumerate(jn):
        M = np.linalg.inv(ibm[i].T)      # glTF : colonnes
        L[n] = M[:3, 3]
    return L

def clip_for(kind, spec, L, belt):
    """découpe nette d'un vêtement (en pose de repos) : x max (manches),
    y min / y max, z min (devant seulement), ouverture devant."""
    sh = abs(L['upperarm_l'][0]); el = abs(L['lowerarm_l'][0]); wr = abs(L['hand_l'][0])
    neck = L['neck_01'][1]; hip = L['thigh_l'][1]; knee = L['calf_l'][1]; ank = L['foot_l'][1]
    t = spec['type']
    c = dict(xmax=9.0, ymin=-9.0, ymax=9.0, zmin=-9.0, open_w=0.0, open_y=9.0, belt=belt)
    if kind in ('haut', 'sous'):
        c['ymax'] = neck - (0.035 if t in ('tshirt', 'pull') else 0.015)
        c['xmax'] = sh + 0.42*(el - sh) if spec.get('manches', 'longues') == 'courtes' else wr - 0.025
        c['ymin'] = {'veste': hip - 0.03, 'costume': hip - 0.06, 'blouse': hip - 0.16, 'combinaison': belt - 0.02}.get(t, belt - 0.05)
        if t in ('veste', 'costume', 'blouse') and spec.get('ouverte', True):
            c['open_w'] = 0.07 if t != 'costume' else 0.055; c['open_y'] = belt - 0.10 if t == 'costume' else -9.0
    elif kind == 'bas':
        c['ymax'] = belt + 0.012
        c['ymin'] = knee + 0.07 if t == 'short' else ank + 0.05
    elif kind == 'pieds':
        c['ymax'] = ank + {'bottes': 0.20, 'baskets': 0.055, 'chaussures': 0.035}.get(t, 0.05)
    elif kind == 'extra':
        c['zmin'] = 0.035; c['ymin'] = knee + 0.10; c['ymax'] = neck - 0.20; c['xmax'] = 0.19
    return c

def _inside(P, c, m=0.0):
    """m > 0 : marge vers l'intérieur (corps caché seulement bien à l'intérieur)."""
    ok = (np.abs(P[:, 0]) <= c['xmax'] - m) & (P[:, 1] >= c['ymin'] + m) & (P[:, 1] <= c['ymax'] - m) & (P[:, 2] >= c['zmin'] + m)
    if c['open_w'] > 0:
        ok &= ~((P[:, 2] > 0) & (np.abs(P[:, 0]) < c['open_w'] + m) & (P[:, 1] > c['open_y'] - m))
    return ok

def _smooth_shell(Ps, Ns, Fs_local, eps, iters):
    """lissage laplacien de la peau du vêtement (le tissu ne colle plus aux
    muscles), puis on la repousse hors du corps (jamais à l'intérieur)."""
    n = len(Ps)
    nb = [[] for _ in range(n)]
    for a, b, c in Fs_local:
        nb[a] += [b, c]; nb[b] += [a, c]; nb[c] += [a, b]
    # sommets aux mêmes positions (coutures d'UV) : moyenne commune
    key = np.round(Ps / 1e-4).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    Q = Ps + Ns * eps
    for _ in range(iters):
        avg = np.array([Q[l].mean(0) if l else Q[i] for i, l in enumerate(nb)])
        Q = Q * 0.45 + avg * 0.55
        # fusionne les doublons
        acc = np.zeros((inv.max()+1, 3)); cnt = np.zeros(inv.max()+1)
        np.add.at(acc, inv, Q); np.add.at(cnt, inv, 1); Q = acc[inv] / cnt[inv, None]
        d = ((Q - Ps) * Ns).sum(1)
        Q += Ns * np.maximum(eps - d, 0)[:, None]
    return Q.astype(np.float32)

EPS = {'sous': 0.006, 'haut': 0.011, 'bas': 0.007, 'pieds': 0.013, 'extra': 0.018}

def _acc(g, i):
    """lit un accesseur glTF -> numpy."""
    a = g.accessors[i]; bv = g.bufferViews[a.bufferView]
    data = g.binary_blob() if g.buffers[0].uri is None else None
    if data is None:
        data = open(os.path.join(BASE, g.buffers[0].uri), 'rb').read()
    comp = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[a.componentType]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a.type]
    off = (bv.byteOffset or 0) + (a.byteOffset or 0)
    stride = bv.byteStride or n * np.dtype(comp).itemsize
    if stride == n * np.dtype(comp).itemsize:
        arr = np.frombuffer(data, comp, a.count * n, off).reshape(a.count, n)
    else:
        raw = np.frombuffer(data, np.uint8, stride * a.count, off).reshape(a.count, stride)
        arr = raw[:, :n*np.dtype(comp).itemsize].copy().view(comp).reshape(a.count, n)
    if a.normalized and comp in (np.uint8, np.uint16):
        arr = arr.astype(np.float32) / np.iinfo(comp).max
    return arr.copy()

def _regions(jn, J, W, P):
    """zone de chaque sommet selon l'os dominant (et la hauteur pour le bassin)."""
    dom = np.array([jn[J[i, np.argmax(W[i])]] for i in range(len(J))])
    y = P[:, 1]
    reg = np.full(len(J), 'peau', object)
    def has(*names): return np.isin(dom, names)
    torso = has('spine_01', 'spine_02', 'spine_03', 'clavicle_l', 'clavicle_r')
    reg[torso] = 'torse'
    reg[has('upperarm_l', 'upperarm_r')] = 'bras_haut'
    reg[has('lowerarm_l', 'lowerarm_r')] = 'avant_bras'
    reg[has('thigh_l', 'thigh_r')] = 'cuisse'
    reg[has('calf_l', 'calf_r')] = 'mollet'
    reg[has('foot_l', 'foot_r', 'ball_l', 'ball_r', 'ball_leaf_l', 'ball_leaf_r')] = 'pied'
    pel = has('pelvis')
    belt = BELT
    reg[pel & (y >= belt)] = 'taille'
    reg[pel & (y < belt)] = 'bassin'
    return reg

BELT = 1.0       # recalculé par corps (hauteur de ceinture)

def _covers(kind, part, spec):
    """zones couvertes par un vêtement."""
    m = spec.get('manches', 'longues')
    if kind in ('haut', 'sous'):
        z = {'torse', 'taille', 'bras_haut'}
        if m == 'longues': z |= {'avant_bras'}
        if spec['type'] in ('veste', 'blouse', 'costume', 'combinaison'): z |= {'bassin'} if spec['type'] in ('blouse', 'combinaison') else set()
        return z
    if kind == 'bas':
        z = {'bassin', 'cuisse'} if spec['type'] == 'short' else {'bassin', 'cuisse', 'mollet'}
        return z
    if kind == 'pieds':
        return {'pied'}
    if kind == 'extra':   # tablier : devant du bassin, des cuisses et du torse bas
        return {'taille', 'bassin', 'cuisse', 'torse'}
    return set()

def build(ch):
    src = os.path.join(BASE, f"Superhero_{'Male' if ch['corps'] == 'M' else 'Female'}_FullBody.gltf")
    g = G.GLTF2().load(src)
    blob = open(os.path.join(BASE, g.buffers[0].uri), 'rb').read()
    g.buffers[0].uri = None
    g.set_binary_blob(blob)
    jn = [g.nodes[j].name for j in g.skins[0].joints]
    body_mi = [i for i, m in enumerate(g.meshes) if g.materials[m.primitives[0].material].name.startswith('MI_Superhero')][0]
    prim = g.meshes[body_mi].primitives[0]
    A = prim.attributes
    P = _acc(g, A.POSITION); N = _acc(g, A.NORMAL); UV = _acc(g, A.TEXCOORD_0)
    J = _acc(g, A.JOINTS_0).astype(np.uint16); W = _acc(g, A.WEIGHTS_0).astype(np.float32)
    F = _acc(g, prim.indices).reshape(-1, 3).astype(np.uint32)
    global BELT
    # ceinture : un peu sous le haut des os du bassin (hauteur relative du corps)
    BELT = P[:, 1].max() * (0.555 if ch['corps'] == 'M' else 0.565)
    reg = _regions(jn, J, W, P)
    L = _landmarks(g, jn)
    freg = reg[F]
    covered = np.zeros(len(F), bool)
    garments = []
    for kind in ('sous', 'haut', 'bas', 'pieds', 'extra'):
        spec = ch.get(kind)
        if not spec: continue
        zones = list(_covers(kind, None, spec))
        if kind == 'pieds': zones += ['mollet']
        if kind in ('haut', 'sous') and spec['type'] in ('blouse', 'veste', 'costume', 'combinaison'): zones += ['bassin', 'cuisse']
        c = clip_for(kind, spec, L, BELT)
        inzone = np.all(np.isin(freg, zones + ['taille']), axis=1) if kind != 'pieds' else np.all(np.isin(freg, zones), axis=1)
        vin = _inside(P, c, -0.03)                     # marge vers l'extérieur
        sel = inzone & np.any(vin[F], axis=1)
        if not sel.any(): continue
        vcov = _inside(P, c, 0.025)
        cov = inzone & np.all(vcov[F], axis=1)
        if kind != 'extra': covered |= cov
        garments.append((kind, spec, F[sel], c))
    keep = ~covered
    newF_body = F[keep]
    # écrit les nouvelles primitives
    blob = bytearray(g.binary_blob())
    def add(arr, target, comp, typ, minmax=False, normalized=False):
        nonlocal blob
        while len(blob) % 4: blob.append(0)
        off = len(blob); b = np.ascontiguousarray(arr).tobytes(); blob += b
        g.bufferViews.append(G.BufferView(buffer=0, byteOffset=off, byteLength=len(b), target=target))
        acc = G.Accessor(bufferView=len(g.bufferViews)-1, componentType=comp, count=len(arr), type=typ, normalized=normalized)
        if minmax: acc.min = arr.min(0).tolist(); acc.max = arr.max(0).tolist()
        g.accessors.append(acc); return len(g.accessors) - 1
    prim.indices = add(newF_body.reshape(-1).astype(np.uint32), G.ELEMENT_ARRAY_BUFFER, G.UNSIGNED_INT, 'SCALAR')
    mats = {}
    clips = {}
    for kind, spec, Fs, c in garments:
        used = np.unique(Fs)
        remap = -np.ones(len(P), np.int64); remap[used] = np.arange(len(used))
        eps = EPS[kind] * (1.6 if spec.get('type') in ('veste', 'costume', 'blouse', 'pull') else 1.0)
        if kind == 'pieds': eps = 0.016 if spec['type'] in ('bottes',) else 0.011
        iters = {'haut': 6, 'sous': 3, 'bas': 4, 'pieds': 2, 'extra': 10}[kind]
        if ch['corps'] == 'F' and kind in ('haut', 'sous', 'extra'): iters += 4
        Pv = _smooth_shell(P[used], N[used], remap[Fs], eps, iters)
        if kind == 'extra': Pv = Pv + np.array([0, 0, 0.01], np.float32)
        name = f'CL_{kind}'
        mi = len(g.materials); g.materials.append(G.Material(name=name, doubleSided=True)); mats[name] = spec
        clips[name] = {k: float(v) for k, v in c.items()}
        rest = P[used]
        col = np.stack([rest[:, 0]*0.5+0.5, rest[:, 1]*0.5, rest[:, 2]+0.5, np.ones(len(rest))], 1).astype(np.float32)
        newp = G.Primitive(attributes=G.Attributes(
            POSITION=add(Pv.astype(np.float32), G.ARRAY_BUFFER, G.FLOAT, 'VEC3', True),
            NORMAL=add(N[used].astype(np.float32), G.ARRAY_BUFFER, G.FLOAT, 'VEC3'),
            TEXCOORD_0=add(UV[used].astype(np.float32), G.ARRAY_BUFFER, G.FLOAT, 'VEC2'),
            COLOR_0=add(np.clip(col, 0, 1), G.ARRAY_BUFFER, G.FLOAT, 'VEC4'),
            TEXCOORD_1=add(rest[:, :2].astype(np.float32), G.ARRAY_BUFFER, G.FLOAT, 'VEC2'),
            JOINTS_0=add(J[used].astype(np.uint16), G.ARRAY_BUFFER, G.UNSIGNED_SHORT, 'VEC4'),
            WEIGHTS_0=add(W[used].astype(np.float32), G.ARRAY_BUFFER, G.FLOAT, 'VEC4')),
            indices=add(remap[Fs].reshape(-1).astype(np.uint32), G.ELEMENT_ARRAY_BUFFER, G.UNSIGNED_INT, 'SCALAR'),
            material=mi)
        g.meshes[body_mi].primitives.append(newp)
    g.buffers[0].byteLength = len(blob)
    g.set_binary_blob(bytes(blob))
    # textures intégrées (fichier unique)
    for im in g.images:
        if im.uri:
            data = open(os.path.join(BASE, im.uri), 'rb').read()
            blob2 = bytearray(g.binary_blob())
            while len(blob2) % 4: blob2.append(0)
            off = len(blob2); blob2 += data
            g.bufferViews.append(G.BufferView(buffer=0, byteOffset=off, byteLength=len(data)))
            im.bufferView = len(g.bufferViews) - 1; im.mimeType = 'image/png'; im.uri = None
            g.buffers[0].byteLength = len(blob2); g.set_binary_blob(bytes(blob2))
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, ch['id'] + '.glb')
    g.save_binary(path)
    tris = len(newF_body) + sum(len(f) for _, _, f, _ in garments)
    return path, tris, clips

def main():
    info = []
    for ch in CAST + FIGURANTS:
        p, tris, clips = build(ch)
        d = {k: v for k, v in ch.items()}
        d['fichier'] = os.path.basename(p); d['triangles'] = int(tris); d['decoupes'] = clips
        info.append(d)
        print(f"{ch['id']:8s} {ch['nom']:16s} {tris} triangles")
    json.dump(info, open(os.path.join(OUT, 'cast.json'), 'w'), ensure_ascii=False, indent=1)

if __name__ == '__main__':
    main()
