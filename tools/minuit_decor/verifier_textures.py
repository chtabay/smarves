# Vérifie que les textures du décor de Casino Minuit (decor/tex/) sont celles de l'original, au pixel près.
# Usage : python3 -I verifier_textures.py <export des textures de l'original> <decor/tex> [materiaux.json]
# L'export de l'original vient d'exporter_textures.mjs (un PNG par texture canvas de la scène, graine fixe).
# Le glTF range les images tête-bêche (et ses UV aussi) : une image retournée verticalement est la même.
# Code de sortie : 0 si toute texture du décor est une texture de l'original ; la liste des textures de
# l'original absentes du décor est donnée avec les objets qui les portent (ce que le portage dessine lui-même).
import sys, os, glob, json, hashlib
from PIL import Image, ImageOps

orig_dir, decor_dir = sys.argv[1], sys.argv[2]
mats = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else []

def empreinte(im):
    return hashlib.sha1(im.size[0].to_bytes(4, 'little') + im.size[1].to_bytes(4, 'little') + im.convert('RGBA').tobytes()).hexdigest()

orig = {}
for f in glob.glob(os.path.join(orig_dir, '*.png')):
    im = Image.open(f)
    orig[empreinte(im)] = os.path.basename(f)[:-4]
decor, etrangeres = {}, []
for f in sorted(glob.glob(os.path.join(decor_dir, '*.png'))):
    im = Image.open(f)
    e1, e2 = empreinte(im), empreinte(ImageOps.flip(im))
    t = orig.get(e1) or orig.get(e2)
    if t:
        decor[t] = os.path.basename(f)
    else:
        etrangeres.append(os.path.basename(f))
porteurs = {}
for m in mats:
    porteurs.setdefault(m['tex'], set()).add((m['mat'] or '-') + ' @ ' + m['ex'])
print(f"original : {len(orig)} textures ; décor : {len(decor) + len(etrangeres)} ; identiques au pixel : {len(decor)}")
absentes = sorted(set(orig.values()) - set(decor), key=lambda s: int(s[1:]) if s[1:].isdigit() else 0)
if absentes:
    print(f"de l'original, pas dans le décor ({len(absentes)}) :")
    for t in absentes:
        print('  ', t, '; '.join(sorted(porteurs.get(t, {'?'}))[:3]))
if etrangeres:
    print(f"ÉCHEC : {len(etrangeres)} texture(s) du décor ne sont pas de l'original :", ', '.join(etrangeres))
    sys.exit(1)
print('ok : toute texture du décor est une texture de l\'original, au pixel près')
