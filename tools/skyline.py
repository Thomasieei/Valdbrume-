"""Silhouettes lointaines autour de la ville jouable (hors limites) : la ville
semble continuer à perte de vue. Hauteurs choisies à la main, rangée par
rangée ; rendues avec un shader très léger (fenêtres dessinées, brume)."""
# Chaque rangée : (côté, distance au bord, profondeur, début, pas, largeurs, hauteurs)
# côté N/S : rangée le long de X ; côté O/E : le long de Z.
ROWS = [
 # ---- proche (juste derrière les fonds de rue), immeubles moyens
 ('N', 30, 24, -600, 36, [30, 26, 32, 28, 34, 24], [34, 28, 40, 31, 46, 26, 38, 52, 30, 36, 44, 29, 33, 58, 41, 27, 35, 48, 30, 39, 26, 44, 37, 31, 50, 28, 36, 42, 33, 29, 40, 35, 47, 30]),
 ('S', 30, 24, -590, 36, [28, 32, 26, 34, 30, 24], [30, 42, 27, 36, 49, 33, 28, 40, 55, 31, 37, 26, 45, 34, 29, 52, 38, 30, 43, 27, 36, 48, 32, 39, 28, 46, 35, 30, 41, 33, 26, 38, 44, 31]),
 ('O', 30, 24, -380, 36, [30, 26, 34, 28], [32, 44, 28, 37, 50, 30, 41, 27, 35, 46, 31, 39, 29, 43, 33, 48, 30, 36, 40, 28, 45, 34]),
 ('E', 30, 24, -370, 36, [28, 32, 26, 34], [48, 62, 40, 55, 71, 44, 58, 39, 66, 52, 45, 74, 41, 57, 63, 46, 52, 69, 43, 56, 60, 47]),
 # ---- lointain : grandes tours (plus hautes côté affaires, à l'est)
 ('N', 170, 40, -900, 70, [44, 36, 52, 40], [60, 48, 82, 55, 71, 95, 52, 66, 88, 58, 74, 102, 61, 79, 54, 92, 68, 57, 85, 63, 76, 98, 59, 70, 87, 53]),
 ('S', 170, 40, -880, 70, [40, 48, 36, 52], [55, 72, 61, 90, 50, 68, 84, 57, 96, 64, 75, 53, 88, 70, 59, 104, 66, 81, 58, 93, 62, 77, 86, 56, 71, 60]),
 ('O', 190, 40, -700, 70, [44, 36, 50], [50, 64, 45, 72, 58, 48, 66, 54, 80, 47, 61, 70, 52, 59, 75, 49, 63, 56, 68, 51, 57]),
 ('E', 190, 40, -690, 70, [42, 50, 38], [92, 118, 86, 132, 105, 96, 140, 88, 124, 110, 98, 150, 101, 126, 93, 137, 108, 120, 90, 114, 128]),
]
CITY = (-375, -210, 375, 210)

def boxes():
    out = []
    x0, z0, x1, z1 = CITY
    for side, dist, depth, start, step, widths, heights in ROWS:
        for i, h in enumerate(heights):
            w = widths[i % len(widths)]
            a = start + i*step
            if side == 'N': out.append((a, z0 - dist - depth/2, w, depth, h))
            if side == 'S': out.append((a, z1 + dist + depth/2, w, depth, h))
            if side == 'O': out.append((x0 - dist - depth/2, a, depth, w, h))
            if side == 'E': out.append((x1 + dist + depth/2, a, depth, w, h))
    return out   # (cx, cz, sx, sz, h)
