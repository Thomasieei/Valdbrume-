"""Génère les ressources de la ville dans le projet Godot :
  project/assets/city/gen/  (non versionné, recréé à chaque construction)
    facade_*.png + facade_atlas.json   atlas des façades imprimées
    chunks/z_*.glb                     zones de 48 m fusionnées par matériau
    skyline.glb                        silhouettes lointaines + sol lointain
    city.json                          collisions, occulteurs, points de vue
Puis écrit les fichiers .import (compression, LOD, tangentes)."""
import os, sys, json, math, hashlib, shutil
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
import bake, impostor, build_city, streets, skyline, nav

ROOT = bake.ROOT
PROJ = os.path.join(ROOT, 'project')
GEN = os.path.join(PROJ, 'assets', 'city', 'gen')

def write_import_scene(path):
    open(path + '.import', 'w').write('''[remap]

importer="scene"
type="PackedScene"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=false
meshes/light_baking=0
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
import_script/path=""
_subresources={}
''')

def write_import_texture(path, normal=False, srgb_color=True, lossless=False):
    open(path + '.import', 'w').write(f'''[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode={0 if lossless else 2}
compress/high_quality=false
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/normal_map={1 if normal else 2}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
''')

def islands():
    """îlots surélevés (trottoirs + îlots bâtis) : tout ce qui n'est pas chaussée."""
    ns = sorted([(s[2]-s[3], s[2]+s[3]) for s in streets.STREETS if s[1] == 'z'])
    ew = sorted([(s[2]-s[3], s[2]+s[3]) for s in streets.STREETS if s[1] == 'x'])
    xs = [-380] + [v for iv in ns for v in iv] + [380]
    zs = [-215] + [v for iv in ew for v in iv] + [215]
    out = []
    for i in range(0, len(xs), 2):
        for j in range(0, len(zs), 2):
            a0, a1, b0, b1 = xs[i], xs[i+1], zs[j], zs[j+1]
            out.append(((a0+a1)/2, -0.5, (b0+b1)/2, a1-a0, 1.0, b1-b0))
    x0, z0, x1, z1 = streets.PLAZA
    out.append(((x0+x1)/2, -0.5, (z0+z1)/2, x1-x0, 1.0, z1-z0))      # place
    B, R, I, D, C = streets.BASIN, streets.RIM, streets.ISLAND, streets.DECK, streets.CAUSE
    H = 1.3                                                           # garde-corps invisibles
    for s in (-1, 1):
        # rebords du bassin (plus hauts en collision : on ne tombe pas dans l'eau)
        for a0, a1 in ((-B, -C), (C, B)):
            out.append(((a0+a1)/2, H/2, s*(B - R/2), a1-a0, H, R))
            out.append((s*(B - R/2), H/2, (a0+a1)/2, R, H, a1-a0))
        # passerelles (dessus à DECK) + garde-corps latéraux
        L = B - I
        out.append((0, D/2, s*(I + L/2), 2*C, D, L))
        out.append((s*(I + L/2), D/2, 0, L, D, 2*C))
        for t in (-1, 1):
            out.append((t*(C + 0.15), D + H/2, s*(I + L/2), 0.3, H, L - R))
            out.append((s*(I + L/2), D + H/2, t*(C + 0.15), L - R, H, 0.3))
        # bords de l'île hors passerelles
        for a0, a1 in ((-I, -C), (C, I)):
            out.append(((a0+a1)/2, D + H/2, s*(I - 0.15), a1-a0, H, 0.3))
            out.append((s*(I - 0.15), D + H/2, (a0+a1)/2, 0.3, H, a1-a0))
    out.append((0, D/2, 0, 2*I, D, 2*I))                              # île centrale
    return out

def ramps():
    """marches d'entrée des passerelles : rampes invisibles (0,5 m sur 2,5 m)."""
    B, D = streets.BASIN, streets.DECK
    ang = math.degrees(math.atan2(D, 2.5))
    L = math.hypot(D, 2.5)
    out = []
    for ry, (px, pz) in ((0, (0, B + 0.75)), (180, (0, -B - 0.75)), (90, (B + 0.75, 0)), (270, (-B - 0.75, 0))):
        out.append(dict(pos=[px, D/2 - 0.03, pz], size=[6, 0.06, L], rot_x=ang, rot_y=ry))
    return out

def build_skyline(path):
    B = {}
    for (cx, cz, sx, sz, h) in skyline.boxes():
        x0, x1, z0, z1 = cx-sx/2, cx+sx/2, cz-sz/2, cz+sz/2
        faces = [  # (coins, normale, longueur u)
            ([(x0, z1), (x1, z1)], (0, 0, 1), sx), ([(x1, z0), (x0, z0)], (0, 0, -1), sx),
            ([(x1, z1), (x1, z0)], (1, 0, 0), sz), ([(x0, z0), (x0, z1)], (-1, 0, 0), sz)]
        for (p, q), n, L in faces:
            v = np.array([[p[0], 0, p[1]], [q[0], 0, q[1]], [q[0], h, q[1]], [p[0], h, p[1]]], np.float32)
            uv = np.array([[0, 0], [L, 0], [L, h], [0, h]], np.float32)   # en mètres
            seed = (hash((round(cx), round(cz))) % 997) / 997.0
            col = np.tile(np.array([seed, h/160.0, 0, 1], np.float32), (4, 1))
            B.setdefault('MI_Skyline', bake.Bucket()).add(v, np.tile(np.array(n, np.float32), (4, 1)), uv, col, np.array([[0, 1, 2], [0, 2, 3]], np.uint32))
        v = np.array([[x0, h, z0], [x1, h, z0], [x1, h, z1], [x0, h, z1]], np.float32)
        B['MI_Skyline'].add(v, np.tile(np.array([0, 1, 0], np.float32), (4, 1)), np.zeros((4, 2), np.float32),
                            np.tile(np.array([0, 0, 1, 1], np.float32), (4, 1)), np.array([[0, 2, 1], [0, 3, 2]], np.uint32))
    # sol lointain (sous la ville et jusqu'à l'horizon)
    bake.quad(B, 'MI_Ground', 0, -0.5, 0, 4000, 4000, 8.0)
    bake.write_glb(path, B, 'skyline')

def viewpoints():
    """points de vue des captures de contrôle (œil du joueur ~1,7 m)."""
    return [
        dict(name='01_place_portail_sud', eye=[0, 1.7, 44], at=[0, 9, 0]),
        dict(name='02_place_vers_ouest', eye=[30, 1.7, 30], at=[-40, 8, -10]),
        dict(name='03_boulevard_ouest', eye=[-60, 1.7, 8], at=[-200, 10, 2]),
        dict(name='04_boulevard_est', eye=[60, 1.7, -8], at=[220, 14, -2]),
        dict(name='05_avenue_portail_nord', eye=[3, 1.7, -60], at=[0, 12, -200]),
        dict(name='06_vieux_quartier_rue', eye=[-145, 1.7, -60], at=[-147, 6, -180]),
        dict(name='07_vieux_quartier_carrefour', eye=[-245, 1.7, -112], at=[-275, 5, -140]),
        dict(name='08_affaires_avenue', eye=[255, 1.7, 100], at=[258, 22, -20]),
        dict(name='09_affaires_carrefour', eye=[146, 1.7, 112], at=[262, 18, 131]),
        dict(name='10_avenue_sud', eye=[-100, 1.7, 133], at=[80, 10, 129]),
        dict(name='11_fond_de_rue_nord', eye=[-258, 1.7, -150], at=[-258, 8, -230]),
        dict(name='12_trottoir_vitrines', eye=[-110, 1.7, 9.0], at=[-98, 3.5, 12.5]),
        dict(name='13_vue_haute_centre', eye=[120, 70, 160], at=[0, 0, 0]),
        dict(name='14_vue_haute_ouest', eye=[-150, 90, 260], at=[-200, 0, 0]),
        dict(name='15_fenetres_contreplongee', eye=[-30, 1.6, -15], at=[-35, 20, -14]),
        dict(name='16_rue_des_arches', eye=[150, 1.7, -100], at=[147, 8, 20]),
        dict(name='18_place_bassin', eye=[-30, 1.7, 30], at=[0, 1, 0]),
        dict(name='21_passage_lanternes', eye=[-200, 1.7, -16], at=[-200, 6, -110]),
        dict(name='22_gare_ouest', eye=[-330, 1.7, 0], at=[-390, 16, 0]),
        dict(name='23_tour_valdbrume', eye=[320, 1.7, -2], at=[390, 40, 0]),
        dict(name='24_hotel_de_ville', eye=[0, 1.7, -160], at=[0, 18, -225]),
        dict(name='25_rue_fontaine', eye=[-158, 1.7, 65], at=[-240, 6, 65]),
        dict(name='26_ile_du_portail', eye=[0, 2.2, 15.5], at=[0, 1, 0]),
        dict(name='19_vieux_quartier_mansardes', eye=[-300, 1.7, 126], at=[-340, 14, 118]),
        dict(name='20_boulevard_loin', eye=[-360, 1.7, -3], at=[0, 8, 0]),
    ]

def write_import_anim(path):
    open(path + '.import', 'w').write('''[remap]

importer="animation_library"
type="AnimationLibrary"

[params]

nodes/root_type=""
nodes/root_name=""
nodes/apply_root_scale=true
nodes/root_scale=1.0
meshes/ensure_tangents=false
meshes/generate_lods=false
meshes/create_shadow_meshes=false
skins/use_named_skins=true
animation/import=true
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
_subresources={}
gltf/naming_version=1
gltf/embedded_image_handling=1
''')

def build_characters():
    """personnages : génération des modèles habillés, copie des animations et coiffures."""
    import characters
    characters.main()
    cdir = os.path.join(PROJ, 'assets', 'characters')
    for f in os.listdir(characters.OUT):
        if f.endswith('.glb'):
            write_import_scene(os.path.join(characters.OUT, f))
    adir = os.path.join(cdir, 'anims'); os.makedirs(adir, exist_ok=True)
    for f in ('UAL1.glb', 'UAL2.glb'):
        shutil.copy(os.path.join(ROOT, 'vendor', 'quaternius', 'animations', f), os.path.join(adir, f))
        write_import_anim(os.path.join(adir, f))
    bdir = os.path.join(cdir, 'base'); os.makedirs(bdir, exist_ok=True)
    src = os.path.join(ROOT, 'vendor', 'quaternius', 'base_characters')
    for f in os.listdir(src):
        if f.startswith('Hair_') or (f.startswith('T_Hair') and not f.endswith('_png.png')):
            shutil.copy(os.path.join(src, f), os.path.join(bdir, f))
    # les coiffures référencent des normales « _png.png » : on garde aussi ces noms
    for f in os.listdir(src):
        if f.startswith('T_Hair') and f.endswith('_png.png'):
            shutil.copy(os.path.join(src, f), os.path.join(bdir, f))
    for f in os.listdir(bdir):
        if f.endswith('.gltf'): write_import_scene(os.path.join(bdir, f))
        if f.endswith('.png'): write_import_texture(os.path.join(bdir, f), normal=('Normal' in f))

def main():
    if os.path.isdir(GEN): shutil.rmtree(GEN)
    os.makedirs(os.path.join(GEN, 'chunks'), exist_ok=True)
    print('atlas des façades…'); impostor.bake_atlas(GEN)
    for f in ('facade_albedo.png',): write_import_texture(os.path.join(GEN, f))
    for f in ('facade_normal.png', 'facade_room.png'): write_import_texture(os.path.join(GEN, f), lossless=True)
    print('ville…')
    chunks, city = build_city.run(os.path.join(GEN, 'chunks'), atlas_dir=GEN)
    meta = json.load(open(os.path.join(GEN, 'chunks', 'city.json')))
    os.remove(os.path.join(GEN, 'chunks', 'city.json'))
    for ch in meta['chunks']: write_import_scene(os.path.join(GEN, 'chunks', ch['name'] + '.glb'))
    meta['islands'] = islands(); meta['ramps'] = ramps(); meta['views'] = viewpoints()
    meta['spawn'] = [0, 0.3, 34]
    meta['nav'] = nav.build()
    import lamps
    meta['lampes'] = lamps.positions()
    lamps.build_mesh(os.path.join(GEN, 'lampadaire.glb')); write_import_scene(os.path.join(GEN, 'lampadaire.glb'))
    for (x, z, _r) in meta['lampes']:
        meta['boxes'].append([x, 1.6, z, 0.3, 3.2, 0.3])     # le fût arrête le joueur
    meta['city'] = list(skyline.CITY)
    from builder import PALETTE
    meta['palette'] = [list(c) for c in PALETTE]
    json.dump(meta, open(os.path.join(GEN, 'city.json'), 'w'))
    build_skyline(os.path.join(GEN, 'skyline.glb')); write_import_scene(os.path.join(GEN, 'skyline.glb'))
    # textures statiques du kit
    tdir = os.path.join(PROJ, 'assets', 'city', 'textures')
    for f in os.listdir(tdir):
        if f.endswith('.png'):
            write_import_texture(os.path.join(tdir, f), normal=('Normal' in f))
    build_characters()
    print('ok', len(meta['chunks']), 'zones,', len(meta['boxes']), 'collisions,', len(meta['occluders']), 'occulteurs')

if __name__ == '__main__':
    main()
