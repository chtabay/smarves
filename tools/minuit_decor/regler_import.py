# Règle l'import Godot du décor (à lancer après un premier --import, puis réimporter) :
# textures sans perte avec mipmaps (les pièces des écrans sans) ; .glb sans tangentes, sans LOD, sans maillage d'ombre.
# Les grands atlas (2048 × 2048 et 2048 × 1024) sont ramenés à 1024 de grand côté à l'import : en mémoire de la carte
# graphique, sans compression, ils pesaient 21 Mo chacun (budget du socle 1.16, 96 Mo par lieu).
# Les surfaces unies (sols, ciels, façades, murs, métal) se compressent pour la carte graphique (S3TC ou ETC2,
# quatre à huit fois moins de mémoire, perte invisible sur ces aplats) ; les enseignes, les néons, le texte, les
# tapis et les roues restent sans perte. Les noms sont les empreintes de decor/tex/ : un nouvel export qui change
# une de ces images change son nom, à reporter ici. Les matières de la DA (bibliothèque) sont réglées de même.
import sys, glob, os, re, struct
decor = sys.argv[1]
GRAND = 1024
SURFACES = {
    '277307e1266fae43',  # façades et fenêtres du Strip
    '8506e9a546a4ecc8',  # rosace du sol de la rotonde
    'fcd5b91d8ed14532', '3c642ae31697b2cb', 'acb4200e7b4aaf5c', 'bd64cf087e9dee01',  # ciels peints et étoilés
    '549fa62bc56f8d09', '0e6d5484468688b5', 'e787e1ca5c1252c6', '7766c7795dcf4e39', '7507f002cac48bab',  # murs, asphalte
    'e9b37b84a90e4baf', '00dfa6675395df87', 'dff362ac9343a870', 'cb842982c50d5439', 'ae9ce8cad3210a7e',  # boiseries, sols
    '65ea34ca1677b397', '31b6143e546029bb', '2975cb5840ee3d72', 'c98199e197bbc287', 'a4aa0381941a94a4',  # métal, flammes
    '7612ef1b49c3ac60',  # halo
    'cf102cc367c92233',  # tapis de sol au logo du lobby
    '0367d9ad7b86f4a6',  # frise d'oiseaux dorés de la salle des grands joueurs
}


def taille_png(chemin):
    with open(chemin, 'rb') as f:
        tete = f.read(24)
    return struct.unpack('>II', tete[16:24])


for f in glob.glob(decor + '/tex/*.png.import'):
    t = open(f).read()
    mode = 2 if os.path.basename(f)[:-len('.png.import')] in SURFACES else 0
    t = re.sub(r'^compress/mode=\d', 'compress/mode=%d' % mode, t, flags=re.M)
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
