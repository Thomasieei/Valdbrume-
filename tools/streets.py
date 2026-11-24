"""Rues, trottoirs, carrefours, marquages et place du Portail (posés explicitement)."""
# Rues : (nom, axe, centre, demi-chaussée, largeur trottoir, début, fin)
# axe 'z' = rue nord-sud (court le long de z), 'x' = rue est-ouest.
STREETS = [
    ("Av. de l'Ouest",     'z', -258, 6, 3, -210, 210),
    ('Rue des Tanneurs',   'z', -147, 3, 3, -210, 210),
    ('Av. du Portail',     'z',    0, 6, 3, -210, 210),
    ('Rue des Arches',     'z',  147, 3, 3, -210, 210),
    ("Av. de l'Est",       'z',  258, 6, 3, -210, 210),
    ('Av. du Nord',        'x', -129, 6, 3, -375, 375),
    ('Grand Boulevard',    'x',    0, 6, 6, -375, 375),
    ('Av. du Sud',         'x',  129, 6, 3, -375, 375),
]
PLAZA = (-45, -48, 45, 48)          # x0, z0, x1, z1
SIDEWALK_Y = 0.0
ROAD_Y = -0.15
DECAL_Y = -0.13                     # au-dessus de l'asphalte (pas de scintillement)

def _in_plaza(x, z, m=0.0):
    x0, z0, x1, z1 = PLAZA
    return x0 - m < x < x1 + m and z0 - m < z < z1 + m

def crossings():
    ns = [s for s in STREETS if s[1] == 'z']
    ew = [s for s in STREETS if s[1] == 'x']
    return [(a, b) for a in ns for b in ew]

def build_streets(c, quad):
    """c : City ; quad(mat, cx, y, cz, w, d, uvscale) ajoute un quad au sol."""
    ns = [s for s in STREETS if s[1] == 'z']
    ew = [s for s in STREETS if s[1] == 'x']

    # ---------------------------------------------------- chaussées
    for (n, ax, cx, ah, sw, a, b) in ns:
        # coupée par la place
        segs = [(a, b)]
        if cx == 0: segs = [(a, PLAZA[1]), (PLAZA[3], b)]
        for s0, s1 in segs:
            quad('MI_Asphalt', cx, ROAD_Y, (s0+s1)/2, ah*2, s1-s0, 6.0)
    for (n, ax, cz, ah, sw, a, b) in ew:
        # entre les rues nord-sud (pas de double chaussée aux carrefours)
        cuts = sorted([(s[2]-s[3], s[2]+s[3]) for s in ns])
        if cz == 0: cuts.append((PLAZA[0], PLAZA[2])); cuts.sort()
        p = a
        for c0, c1 in cuts + [(b, b)]:
            if c0 > p: quad('MI_Asphalt', (p+c0)/2, ROAD_Y, cz, c0-p, ah*2, 6.0)
            p = max(p, c1)

    # ---------------------------------------------------- trottoirs
    def tile(m, x, z, ry, tag='ground'):
        c.put(m, x, SIDEWALK_Y, z, ry, ((1, 1, 1), (1, 1, 1)), tag)
    # bandes de trottoir des rues nord-sud (côté ouest puis est)
    for (n, ax, cx, ah, sw, a, b) in ns:
        stops = []
        for e in ew:
            stops.append((e[2]-e[3]-e[4], e[2]+e[3]+e[4]))
        if cx == 0: stops.append((PLAZA[1], PLAZA[3]))
        for side in (-1, 1):
            x_in = cx + side*(ah + sw)     # bord côté bâtiments
            for row in range(sw // 3):
                x = cx + side*(ah + 1.5 + 3*row)
                curb = row == 0
                z = a + 1.5
                while z < b:
                    if not any(s0 < z < s1 for s0, s1 in stops):
                        if curb: tile('Sidewalk_Straight_3m', x, z, 270 if side > 0 else 90)
                        else: tile('Sidewalk_NoCurb_3m', x, z, 0)
                    z += 3
    for (n, ax, cz, ah, sw, a, b) in ew:
        stops = []
        for s in ns:
            stops.append((s[2]-s[3]-s[4], s[2]+s[3]+s[4]))
        if cz == 0: stops.append((PLAZA[0], PLAZA[2]))
        for side in (-1, 1):
            for row in range(sw // 3):
                z = cz + side*(ah + 1.5 + 3*row)
                curb = row == 0
                x = a + 1.5
                while x < b:
                    if not any(s0 < x < s1 for s0, s1 in stops):
                        if curb: tile('Sidewalk_Straight_3m', x, z, 180 if side > 0 else 0)
                        else: tile('Sidewalk_NoCurb_3m', x, z, 0)
                    x += 3

    # ---------------------------------------------------- carrefours (angles)
    # tuile d'angle arrondi : ry selon la direction du coin vers l'extérieur
    RY = {(-1, 1): 0, (1, 1): 90, (1, -1): 180, (-1, -1): 270}
    for s, e in crossings():
        cx, ah_s, sw_s = s[2], s[3], s[4]
        cz, ah_e, sw_e = e[2], e[3], e[4]
        if cx == 0 and cz == 0: continue      # remplacé par la place
        for sx in (-1, 1):
            for sz in (-1, 1):
                # le coin du carrefour (côté chaussée) est vers (-sx, -sz)
                for i in range(sw_s // 3):
                    for j in range(sw_e // 3):
                        x = cx + sx*(ah_s + 1.5 + 3*i)
                        z = cz + sz*(ah_e + 1.5 + 3*j)
                        if i == 0 and j == 0: tile('Sidewalk_Corner_Round_3m', x, z, RY[(-sx, -sz)])
                        elif i == 0: tile('Sidewalk_Straight_3m', x, z, 90 if -sx > 0 else 270)
                        elif j == 0: tile('Sidewalk_Straight_3m', x, z, 0 if -sz > 0 else 180)
                        else: tile('Sidewalk_NoCurb_3m', x, z, 0)
        # passages piétons sur les 4 branches
        for d in (-1, 1):
            # traverser la rue nord-sud (branche nord/sud du carrefour)
            zc = cz + d*(ah_e + sw_e + 2.6)
            if not (cx == 0 and _in_plaza(cx, zc, 2)):
                c.put('Decal_Crosswalk_Wide' if ah_s == 6 else 'Decal_Crosswalk', cx, 0.02, zc, 90, ((1, 1, 1), (1, 1, 1)), 'decal')
            xc = cx + d*(ah_s + sw_s + 2.6)
            if not (cz == 0 and _in_plaza(xc, cz, 2)):
                c.put('Decal_Crosswalk_Wide' if ah_e == 6 else 'Decal_Crosswalk', xc, 0.02, cz, 0, ((1, 1, 1), (1, 1, 1)), 'decal')

    # ---------------------------------------------------- marquages au sol
    def line_marks(ax, cc, ah, a, b, stops):
        # 4 voies : double jaune au centre + pointillés ; 2 voies : pointillés
        k = a + 3
        while k + 3 <= b:
            if not any(s0 - 6 < k < s1 + 6 for s0, s1 in stops):
                pos = [(0, 'Decal_DoubleYellow_Straight')] if ah == 6 else [(0, 'Decal_BrokenLine_Straight')]
                if ah == 6 and (int(k) // 6) % 2 == 0:
                    pos += [(-3, 'Decal_BrokenLine_Straight'), (3, 'Decal_BrokenLine_Straight')]
                if ah == 3 and (int(k) // 6) % 2 == 1: pos = []
                for off, m in pos:
                    if ax == 'z': c.put(m, cc + off, 0.0, k, 90, ((1, 1, 1), (1, 1, 1)), 'decal')
                    else: c.put(m, k, 0.0, cc + off, 0, ((1, 1, 1), (1, 1, 1)), 'decal')
            k += 6
    for (n, ax, cx, ah, sw, a, b) in ns:
        stops = [(e[2]-e[3]-e[4]-6, e[2]+e[3]+e[4]+6) for e in ew]
        if cx == 0: stops.append((PLAZA[1], PLAZA[3]))
        line_marks('z', cx, ah, a, b, stops)
    for (n, ax, cz, ah, sw, a, b) in ew:
        stops = [(s[2]-s[3]-s[4]-6, s[2]+s[3]+s[4]+6) for s in ns]
        if cz == 0: stops.append((PLAZA[0], PLAZA[2]))
        line_marks('x', cz, ah, a, b, stops)

    # ---------------------------------------------------- détails de chaussée
    # bouches d'égout le long des trottoirs, plaques dans les voies
    for (n, ax, cc, ah, sw, a, b) in STREETS:
        k = a + 9
        i = 0
        while k < b - 6:
            for side in (-1, 1):
                off = side*(ah - 0.45)
                pos = (cc + off, k) if ax == 'z' else (k, cc + off)
                if not _in_plaza(pos[0], pos[1], 8) and not _near_cross(pos, 14):
                    if i % 2 == 0: c.put('Prop_Drain', pos[0], ROAD_Y, pos[1], 0 if ax == 'x' else 90, ((1, 1, 1), (1, 1, 1)), 'decal')
            if i % 3 == 1:
                off = 1.5 if ah == 6 else 0.0
                pos = (cc + off, k) if ax == 'z' else (k, cc + off)
                if not _in_plaza(pos[0], pos[1], 8) and not _near_cross(pos, 14):
                    c.put('Prop_ManholeCover', pos[0], ROAD_Y + 0.005, pos[1], 0, ((1, 1, 1), (1, 1, 1)), 'decal')
            k += 24; i += 1

    build_plaza(c, tile)

def _near_cross(p, m):
    x, z = p
    ns = [s for s in STREETS if s[1] == 'z']; ew = [s for s in STREETS if s[1] == 'x']
    for s in ns:
        for e in ew:
            if abs(x - s[2]) < s[3] + s[4] + m and abs(z - e[2]) < e[3] + e[4] + m: return True
    return False

def build_plaza(c, tile):
    """Place du Portail : dallage, bordures face aux chaussées, socle central
    (futur portail), jardinières et bornes. Tout est posé explicitement."""
    x0, z0, x1, z1 = PLAZA
    # dallage complet (tuiles 3 m) ; bordure côté chaussée aux 4 entrées
    x = x0 + 1.5
    while x < x1:
        z = z0 + 1.5
        while z < z1:
            road_n = abs(x) < 6 and z < z0 + 3
            road_s = abs(x) < 6 and z > z1 - 3
            road_o = abs(z) < 6 and x < x0 + 3
            road_e = abs(z) < 6 and x > x1 - 3
            if abs(x) < 12 and abs(z) < 12:
                pass                                   # sous le socle
            elif road_n: tile('Sidewalk_Straight_3m', x, z, 180)
            elif road_s: tile('Sidewalk_Straight_3m', x, z, 0)
            elif road_o: tile('Sidewalk_Straight_3m', x, z, 270)
            elif road_e: tile('Sidewalk_Straight_3m', x, z, 90)
            else: tile('Sidewalk_NoCurb_3m', x, z, 0)
            z += 3
        x += 3
    # socle central 24 x 24, 1 m de haut, escaliers au milieu de chaque côté
    T = ((1, 1, 1), (1, 1, 1))
    for i in range(12):
        for j in range(12):
            px, pz = -11 + 2*i, -11 + 2*j
            stair = (abs(px) < 4 and abs(pz) > 9) or (abs(pz) < 4 and abs(px) > 9)
            if not stair: c.put('Entrance_Concrete_2x2', px, 0, pz, 0, T, 'plinth')
    for k in (-3, -1, 1, 3):
        c.put('Stairs_Entrance_Concrete', k + 0.0, 0, 10, 0, T, 'plinth')      # vers le sud
        c.put('Stairs_Entrance_Concrete', k + 0.0, 0, -10, 180, T, 'plinth')   # vers le nord
        c.put('Stairs_Entrance_Concrete', 10, 0, k + 0.0, 90, T, 'plinth')     # vers l'est
        c.put('Stairs_Entrance_Concrete', -10, 0, k + 0.0, 270, T, 'plinth')   # vers l'ouest
    # jardinières en couronne autour du socle (8), bornes aux entrées de chaussée
    for (px, pz) in [(-20, -20), (20, -20), (-20, 20), (20, 20), (-20, 0), (20, 0), (0, -20), (0, 20)]:
        if px == 0 or pz == 0:
            # devant les escaliers : paire de jardinières de part et d'autre de l'axe
            if px == 0: c.put('Sidewalk_Planter', -7, 0, pz + (3 if pz > 0 else -3), 0, T); c.put('Sidewalk_Planter', 7, 0, pz + (3 if pz > 0 else -3), 0, T)
            else: c.put('Sidewalk_Planter', px + (3 if px > 0 else -3), 0, -7, 90, T); c.put('Sidewalk_Planter', px + (3 if px > 0 else -3), 0, 7, 90, T)
        else:
            c.put('Prop_Planter_Single', px, 0, pz, 0, T)
    for k in range(-5, 6, 2):
        c.put('Prop_Bollard', k, 0, z0 + 3.6, 0, T); c.put('Prop_Bollard', k, 0, z1 - 3.6, 0, T)
        c.put('Prop_Bollard', x0 + 3.6, 0, k, 0, T); c.put('Prop_Bollard', x1 - 3.6, 0, k, 0, T)
