"""Assembleur de la ville : bâtiments (lots), rues, trottoirs, place, accessoires.
Chaque bâtiment est décrit à la main dans layout.py (position, taille, étages,
style, rez-de-chaussée, couleurs). Ici on ne fait que traduire cette
description en modules du kit Downtown, sans aucun hasard."""
import math

# ---------------------------------------------------------------- palettes
# Teintes multipliées sur la texture (vertex color). Choisies à la main.
BRICK = {
    'rouge':   (1.00, 1.00, 1.00),
    'brun':    (0.78, 0.66, 0.60),
    'sombre':  (0.58, 0.52, 0.50),
    'creme':   (1.45, 1.32, 1.12),   # brique pâle / pierre crème
    'sable':   (1.30, 1.15, 0.92),
    'gris':    (1.02, 0.99, 0.95),   # gris chaud (pierre de taille)
    'ocre':    (1.20, 0.95, 0.70),
    'ivoire':  (1.22, 1.16, 1.04),
}
TRIM = {
    'pierre':  (1.00, 1.00, 1.00),
    'blanc':   (1.18, 1.18, 1.15),
    'gris':    (0.72, 0.74, 0.78),
    'sombre':  (0.38, 0.38, 0.40),
    'vert':    (0.45, 0.62, 0.50),
    'bordeaux':(0.70, 0.36, 0.34),
    'bleu':    (0.42, 0.50, 0.66),
}
FLOOR_H = 3.0

# Palette commune (index utilisés par le shader des façades imprimées)
PALETTE = list(dict.fromkeys(list(BRICK.values()) + list(TRIM.values())))
def pal_index(c): return PALETTE.index(tuple(c))

def lot_tints(l):
    """(mur, pierre, accent) selon le style : la pierre des immeubles 'pierre'
    et le béton des immeubles 'verre' prennent la couleur choisie pour le lot."""
    wall = BRICK[l.brick]
    stone = {'rouge': TRIM['pierre'], 'pale': TRIM['blanc']}.get(l.style, BRICK[l.brick])
    accent = TRIM[l.trim]
    return (wall, stone, accent)

class Lot:
    """Un bâtiment rectangulaire posé à la main.
    x0,z0,x1,z1 : emprise au sol (multiples de 2 m)
    floors      : nombre d'étages au-dessus du rez-de-chaussée
    style       : 'rouge' (brique classique), 'pale' (brique pâle à baies),
                  'pierre' (pierre à corniches), 'verre' (moderne métal/verre)
    ground      : 'boutique', 'vitrine', 'hall', 'brique'
    fronts      : faces sur rue, parmi 'N','S','E','O' (détaillées)
    brick/trim  : teintes (voir palettes)
    roof        : 'corniche', 'mansarde', 'plat'
    var         : variante de rythme de façade (0..3)
    """
    def __init__(s, x0, z0, x1, z1, floors, style, fronts, ground='boutique',
                 brick='rouge', trim='pierre', roof='corniche', var=0, name=''):
        assert (x1-x0) % 2 == 0 and (z1-z0) % 2 == 0, (name, x0, z0, x1, z1)
        s.x0, s.z0, s.x1, s.z1 = x0, z0, x1, z1
        s.floors, s.style, s.fronts, s.ground = floors, style, fronts, ground
        s.brick, s.trim, s.roof, s.var, s.name = brick, trim, roof, var, name
    @property
    def ground_h(s): return 4.0           # rez-de-chaussée 3 m + bandeau 1 m
    @property
    def top(s):  # hauteur du haut des murs (sans corniche)
        return s.ground_h + s.floors * FLOOR_H
    @property
    def height(s):
        return s.top + (3.0 if s.roof == 'mansarde' else 1.0)

# Faces : direction extérieure, axe le long de la façade.
# Pour chaque face on parcourt la façade de gauche à droite vue de la rue.
def faces(l):
    return {
        'S': dict(ry=0,   start=(l.x0, l.z1), dir=(1, 0),  length=l.x1-l.x0),
        'N': dict(ry=180, start=(l.x1, l.z0), dir=(-1, 0), length=l.x1-l.x0),
        'E': dict(ry=90,  start=(l.x1, l.z1), dir=(0, -1), length=l.z1-l.z0),
        'O': dict(ry=270, start=(l.x0, l.z0), dir=(0, 1),  length=l.z1-l.z0),
    }

# ------------------------------------------------------------- styles
# Chaque style donne les modules pour : mur plein, fenêtres (largeur 2 ou 4),
# pilastre, coin, corniche, haut / bas d'étage.
STYLES = {
 'rouge': dict(plain='Brick_Plain_3', band='Brick_Plain_1',
               wins=[('Brick_Window_Trim_Single', 2), ('Brick_Window_Trim', 2)],
               wide=None,
               pil=('Brick_HalfColumn_Bottom', 'Brick_HalfColumn_Center', 'Brick_HalfColumn_Top'),
               corner=('Brick_CornerColumn_Bottom', 'Brick_CornerColumn_Center', 'Brick_CornerColumn_Top', 'Brick_CornerColumn_Cap'),
               cornice=('Cornice_Trim_Center', 'Cornice_Trim_90Angle_L', 'Cornice_Trim_90Angle_R')),
 'pale':  dict(plain='Brick_Plain_3', band='Brick_Plain_1',
               wins=[('Brick_Window_Square_Single', 2)],
               wide=[('Brick_Inset_Window', 4), ('Brick_Inset_Window_Curved', 4), ('Brick_RedWhite_DoubleWindow', 4), ('Brick_Inset_Window_Curved_Small', 4)],
               pil=('Brick_HalfColumn_Bottom', 'Brick_HalfColumn_Center', 'Brick_HalfColumn_Top'),
               corner=('Brick_CornerColumn_Bottom', 'Brick_CornerColumn_Center', 'Brick_CornerColumn_Top', 'Brick_CornerColumn_Cap'),
               cornice=('Cornice_Trim_Center', 'Cornice_Trim_90Angle_L', 'Cornice_Trim_90Angle_R')),
 'pierre': dict(plain='Trim_Plain_3', band='Brick_Plain_1',
               wins=[('Trim_Window', 2)],
               wide=None,
               pil=('Trim_Column_Bottom', 'Trim_Column_Center', 'Trim_Column_Top'),
               corner=('Trim_Column_Bottom', 'Trim_Column_Center', 'Trim_Column_Top', None),
               cornice=('Cornice_Trim_Center', 'Cornice_Trim_90Angle_L', 'Cornice_Trim_90Angle_R')),
 'verre': dict(plain='Metal_Plain_3', band='Metal_Plain_1',
               wins=[('Metal_FullWindow', 2), ('Metal_Window_Half', 2)],
               wide=[('Metal_Window', 4)],
               pil=('Metal_Column_Small_Bottom', 'Metal_Column_Small_Center', 'Metal_Column_Small_Top'),
               corner=('Metal_Column_Bottom', 'Metal_Column_Center', 'Metal_Column_Top', None),
               cornice=('Cornice_Metal_Center', 'Cornice_Metal_90Angle_L', 'Cornice_Metal_90Angle_R')),
}

def _pos(f, d, along, out=0.0):
    """point sur la face f à 'along' m du début, décalé 'out' vers l'extérieur."""
    sx, sz = f['start']; dx, dz = f['dir']
    nx, nz = dz, -dx  # normale extérieure (droite de la direction)
    # vérification : face S : dir (1,0) -> normale (0,-1) ?  on veut +Z.
    nx, nz = -dz, dx
    return sx + dx*along + nx*out, sz + dz*along + nz*out

class City:
    def __init__(s):
        s.items = []      # (module, x, y, z, ry, tint, tag)
        s.lots = []
        s.boxes = []      # collisions (cx,cy,cz, sx,sy,sz)
        s.occluders = []
    def put(s, m, x, y, z, ry=0, tint=(1,1,1), tag='decor', sy=1.0):
        s.items.append((m, x, y, z, ry, tint, tag, sy))

    # ------------------------------------------------------ bâtiments
    def lot(s, l):
        s.lots.append(l)

    def build_lots(s):
        for l in s.lots:
            s._build(l)

    def _covered(s, l, fx, fz, face, y_top):
        """vrai si la portion de mur est cachée par un voisin collé au moins aussi haut."""
        eps = 0.05
        for o in s.lots:
            if o is l: continue
            if o.top + 0.01 < y_top: continue
            if face == 'S' and abs(o.z0 - l.z1) < eps and o.x0 - eps <= fx <= o.x1 + eps: return True
            if face == 'N' and abs(o.z1 - l.z0) < eps and o.x0 - eps <= fx <= o.x1 + eps: return True
            if face == 'E' and abs(o.x0 - l.x1) < eps and o.z0 - eps <= fz <= o.z1 + eps: return True
            if face == 'O' and abs(o.x1 - l.x0) < eps and o.z0 - eps <= fz <= o.z1 + eps: return True
        return False

    def _build(s, l):
        st = STYLES[l.style]
        tint = lot_tints(l)
        for fname, f in faces(l).items():
            front = fname in l.fronts
            n = f['length'] // 2
            # ----- rez-de-chaussée
            for i in range(n):
                a = i*2 + 1
                x, z = _pos(f, None, a)
                if s._covered(l, x, z, fname, l.ground_h): continue
                if front: s._ground_bay(l, st, x, z, f['ry'], i, n, tint)
                else:
                    s.put(st['plain'], x, 0, z, f['ry'], tint, 'back'); s.put(st['band'], x, 3, z, f['ry'], tint, 'back')
            # ----- étages
            for k in range(l.floors):
                y = l.ground_h + k*FLOOR_H
                i = 0
                while i < n:
                    a = i*2 + 1
                    x, z = _pos(f, None, a)
                    if s._covered(l, x, z, fname, y + FLOOR_H):
                        i += 1; continue
                    if front:
                        used = s._upper_bay(l, st, f, i, n, k, y, tint)
                        i += used
                    else:
                        # face arrière / côté : mur simple, quelques fenêtres
                        # simples pour les hauts bâtiments vus de loin
                        if l.floors >= 6 and i % 3 == 1:
                            s.put('Brick_Window_Square_Single' if l.style != 'verre' else 'Metal_Window_Half', x, y, z, f['ry'], tint, 'back')
                        else:
                            s.put(st['plain'], x, y, z, f['ry'], tint, 'back')
                        i += 1
            # pilastres : sur façades, tous les 'pitch' modules
            if front and f['length'] >= 8:
                pitch = [3, 4, 2, 5][l.var % 4] if l.style != 'verre' else [2, 3, 2, 4][l.var % 4]
                for i in range(pitch, n, pitch):
                    if n - i < 2: break
                    x, z = _pos(f, None, i*2)
                    if s._covered(l, x, z, fname, l.top): continue
                    for k in range(l.floors):
                        y = l.ground_h + k*FLOOR_H
                        m = st['pil'][0] if k == 0 else (st['pil'][2] if k == l.floors-1 else st['pil'][1])
                        s.put(m, x, y, z, f['ry'], tint)
            # ----- corniche / toit
            s._roofline(l, st, f, fname, front, tint)
        # coins : colonnes d'angle sur les coins où deux façades sur rue se rejoignent
        s._corners(l, st, tint)
        # toit plat (un seul quad géré au bake) + collisions + occulteur
        s.put('@roof', (l.x0+l.x1)/2, l.top, (l.z0+l.z1)/2, 0, ((l.x1-l.x0), (l.z1-l.z0)), tag='roof')
        h = l.height
        s.boxes.append(((l.x0+l.x1)/2, h/2, (l.z0+l.z1)/2, l.x1-l.x0, h, l.z1-l.z0))
        s.occluders.append(((l.x0+l.x1)/2, l.top/2, (l.z0+l.z1)/2, l.x1-l.x0-0.6, l.top, l.z1-l.z0-0.6))
        s._roof_props(l)

    def _ground_bay(s, l, st, x, z, ry, i, n, tint):
        g = l.ground
        mid = n // 2
        if g == 'boutique':     # devantures vertes / sombres, porte au milieu
            if i == mid:
                s.put('DoorFrame_Trim', x, 0, z, ry, tint)
            else:
                s.put('Trim_FirstFloor_Window_001', x, 0, z, ry, tint)
                s.put('Trim_Wall_Guard', x, 0, z, ry, tint)
            s.put('Brick_Plain_1' if l.style != 'verre' else 'Metal_FirstFloor_Wall_1', x, 3, z, ry, tint)
        elif g == 'vitrine':    # grandes vitrines métal
            if i == mid:
                s.put('DoorFrame_Metal_Single', x, 0, z, ry, tint)
                s.put('Door_2', x+0.0, 0, z, ry, tint, tag='door')
            else:
                s.put('Metal_FirstFloor_Window', x, 0, z, ry, tint)
            s.put('Metal_FirstFloor_Wall_1', x, 3, z, ry, tint)
        elif g == 'hall':       # entrée d'immeuble : porte bois + murs
            if i == mid:
                s.put('DoorFrame_Wooden', x, 0, z, ry, tint)
            elif i % 2 == 0:
                s.put('Brick_Window_Square_Single' if l.style != 'pierre' else 'Trim_Window', x, 0, z, ry, tint)
            else:
                s.put(st['plain'] if l.style != 'verre' else 'Metal_FirstFloor_Wall', x, 0, z, ry, tint)
            s.put(st['band'], x, 3, z, ry, tint)
        else:                   # 'brique' : rez fermé (arrières, entrepôts)
            s.put('Brick_BottomTrim' if l.style in ('rouge', 'pale') else st['plain'], x, 0, z, ry, tint)
            s.put(st['band'], x, 3, z, ry, tint)

    def _upper_bay(s, l, st, f, i, n, k, y, tint):
        """pose un ou deux modules d'étage, renvoie le nombre de modules 2 m consommés."""
        ry = f['ry']
        v = l.var
        # étages « nobles » : 1er étage et dernier étage traités différemment
        # (vraie hiérarchie de façade : socle, étage noble, corps, attique)
        feat = None
        if l.floors >= 3:
            if l.style == 'pierre':
                feat = 'Brick_Inset_Window_Curved' if k == 0 else ('Brick_Inset_Window_Curved_Small' if k == l.floors-1 else None)
            elif l.style == 'verre' and k == 0:
                feat = 'Metal_Window'
            elif l.style == 'rouge' and k == l.floors-1 and v % 2 == 0:
                feat = 'Brick_Inset_Window_Curved_Small'
        if feat and 1 <= i and i + 1 <= n - 2 and (i - 1) % 2 == 0:
            x, z = _pos(f, None, i*2 + 2)
            s.put(feat, x, y, z, ry, tint)
            return 2
        if l.style == 'rouge' and k == 0:
            x, z = _pos(f, None, i*2 + 1)
            if (i == 0 or i == n-1) and n >= 5: s.put(st['plain'], x, y, z, ry, tint)
            else: s.put('Brick_Window_Trim', x, y, z, ry, tint)
            return 1
        # baies larges (4 m) si le style en a et la place
        if st['wide'] and (l.style == 'pale' or v % 2 == 1) and i + 1 < n and (i % 2 == 0):
            m, w = st['wide'][(v + (1 if k == l.floors-1 else 0)) % len(st['wide'])]
            x, z = _pos(f, None, i*2 + 2)
            s.put(m, x, y, z, ry, tint)
            return 2
        x, z = _pos(f, None, i*2 + 1)
        # rythme : mur plein aux extrémités pour les styles classiques
        if l.style != 'verre' and (i == 0 or i == n-1) and n >= 5:
            s.put(st['plain'], x, y, z, ry, tint); return 1
        wins = st['wins']
        m = wins[(v + i//3) % len(wins)][0] if l.style != 'verre' else wins[(v + (k % 2)) % len(wins)][0] if v >= 2 else wins[0][0]
        s.put(m, x, y, z, ry, tint)
        return 1

    def _roofline(s, l, st, f, fname, front, tint):
        n = f['length'] // 2
        ry = f['ry']
        if l.roof == 'mansarde':
            for i in range(n):
                x, z = _pos(f, None, i*2 + 1)
                if s._covered(l, x, z, fname, l.top + 3): continue
                if i == 0 or i == n-1: continue   # coins posés à part
                if front and i % 2 == 1: m = 'Roof_SlateCornice_Window_1'
                else: m = 'Roof_SlateCornice_Center'
                s.put(m, x, l.top, z, ry, tint)
            return
        if l.roof == 'plat' and not front:
            return
        for i in range(n):
            x, z = _pos(f, None, i*2 + 1)
            if s._covered(l, x, z, fname, l.top + 1): continue
            s.put(st['cornice'][0] if front else ('Cornice_Brick_Center' if l.style != 'verre' else 'Cornice_Metal_Center'), x, l.top, z, ry, tint)

    def _corners(s, l, st, tint):
        # coin (x1,z1) : faces S et E ; ry=0 place la colonne en (+x,+z)
        cs = [((l.x1, l.z1), 0, 'S', 'E'), ((l.x0, l.z1), 270, 'O', 'S'),
              ((l.x0, l.z0), 180, 'N', 'O'), ((l.x1, l.z0), 90, 'E', 'N')]
        c = st['corner']
        for (cx, cz), ry, fa, fb in cs:
            if not (fa in l.fronts and fb in l.fronts): continue
            if l.roof == 'mansarde':
                s.put('Roof_SlateCornice_Corner', cx, l.top, cz, ry, tint)
            for k in range(-1, l.floors):
                y = 0 if k < 0 else l.ground_h + k*FLOOR_H
                m = c[0] if k < 0 else (c[2] if k == l.floors-1 else c[1])
                s.put(m, cx, y, cz, ry, tint)
            s.put(c[1], cx, 1.0, cz, ry, tint)   # raccord du bandeau (rez 4 m)
            if c[3] and l.roof != 'mansarde':
                s.put(c[3], cx, l.top - 2.0, cz, ry, tint)

    def _roof_props(s, l):
        # climatiseurs sur le toit (silhouette vue de loin), posés selon la taille
        if l.roof == 'mansarde': return
        w, d = l.x1 - l.x0, l.z1 - l.z0
        if w * d < 150: return
        cx, cz = (l.x0+l.x1)/2, (l.z0+l.z1)/2
        spots = [(-0.25, -0.2), (0.2, 0.15), (0.05, -0.3)][: 1 + (l.var % 3)]
        for fx, fz in spots:
            s.put('Prop_ACUnit', cx + fx*w, l.top - 0.2, cz + fz*d, 90*(l.var % 2), ((1,1,1),(1,1,1),(1,1,1)))
