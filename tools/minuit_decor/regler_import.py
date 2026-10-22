# Règle l'import Godot du décor (à lancer après un premier --import, puis réimporter) :
# textures sans perte avec mipmaps (les pièces des écrans sans) ; .glb sans tangentes, sans LOD, sans maillage d'ombre.
# Les grands atlas (2048 × 2048 et 2048 × 1024) sont ramenés à 1024 de grand côté à l'import : en mémoire de la carte
# graphique, sans compression, ils pesaient 21 Mo chacun (budget du socle 1.16, 96 Mo par lieu).
import sys, glob, re, struct
decor = sys.argv[1]
GRAND = 1024


def taille_png(chemin):
    with open(chemin, 'rb') as f:
        tete = f.read(24)
    return struct.unpack('>II', tete[16:24])


for f in glob.glob(decor + '/tex/*.png.import'):
    t = open(f).read()
    t = re.sub(r'^compress/mode=\d', 'compress/mode=0', t, flags=re.M)
    t = re.sub(r'^mipmaps/generate=\w+', 'mipmaps/generate=true', t, flags=re.M)
    t = re.sub(r'^detect_3d/compress_to=\d', 'detect_3d/compress_to=0', t, flags=re.M)
    w, h = taille_png(f[:-len('.import')])
    limite = GRAND if max(w, h) > GRAND and min(w, h) >= GRAND else 0
    t = re.sub(r'^process/size_limit=\d+', 'process/size_limit=%d' % limite, t, flags=re.M)
    open(f, 'w').write(t)
# Les pièces des écrans (decor/ecrans/) sont relues en image et recomposées : sans perte, sans mipmaps.
for f in glob.glob(decor + '/ecrans/*.png.import'):
    t = open(f).read()
    t = re.sub(r'^compress/mode=\d', 'compress/mode=0', t, flags=re.M)
    t = re.sub(r'^mipmaps/generate=\w+', 'mipmaps/generate=false', t, flags=re.M)
    t = re.sub(r'^detect_3d/compress_to=\d', 'detect_3d/compress_to=0', t, flags=re.M)
    open(f, 'w').write(t)
for f in glob.glob(decor + '/*.glb.import'):
    t = open(f).read()
    for k in ('meshes/ensure_tangents', 'meshes/generate_lods', 'meshes/create_shadow_meshes'):
        t = re.sub('^' + k + r'=\w+', k + '=false', t, flags=re.M)
    open(f, 'w').write(t)
