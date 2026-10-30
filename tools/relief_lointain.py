#!/usr/bin/env python3
"""Tire le relief d'une commune en grandes grilles, pour ce que bourg_reel.py ne couvre pas : le relief
proche d'un lieu plus grand que le bourg (une colline, une vallée, un fleuve) et les montagnes lointaines
qui ferment l'horizon, à leur vraie direction et à leur vraie hauteur.

Source : le RGE ALTI de l'IGN (service d'altimétrie de la Géoplateforme, Licence Ouverte 2.0).

Sortie, dans le dossier de la commune :
- <nom>.png : une carte des hauteurs sur 16 bits, le nord en haut, un pixel par pas : l'octet haut dans le
  rouge, l'octet bas dans le vert (Godot lit les PNG en 8 bits par canal ; garder l'image sans perte dans
  emballage.json) ;
- <nom>.json : ce qu'il faut pour la lire : l'origine (longitude, latitude), le cadre en mètres autour
  d'elle (ouest, nord, est, sud ; x vers l'est, z vers le sud, comme bourg.json), le pas, et les altitudes
  du noir et du blanc.

Usage : python3 -I tools/relief_lointain.py <id> --nom=lointain --centre=5.68615,45.76076 --cadre=-18000,-18000,18000,18000 --pas=75
Le dossier de la commune est communes/<id>/, sinon tools/paquet_essai/<id>/. Sans --centre, l'origine est
celle de bourg.json. Les téléchargements sont gardés dans build/relief_lointain/<id>/<nom>/ : relancer
l'outil ne réinterroge pas le service. Demande Pillow.
"""
import json
import math
import os
import sys
import time
import urllib.error
import urllib.request

from PIL import Image

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SERVICE = "https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json"
AGENT = "Smarves/1.0 (jeu ; https://github.com/chtabay/smarves)"
LOT = 400  # points par requête


def lire_options(args):
    opts = {}
    for a in args:
        if not a.startswith("--") or "=" not in a:
            raise SystemExit(__doc__)
        k, v = a[2:].split("=", 1)
        opts[k] = v
    return opts


def demander(points, cache, cle):
    chemin = os.path.join(cache, cle)
    if not os.path.exists(chemin):
        corps = json.dumps({
            "lon": "|".join("%.6f" % p[0] for p in points),
            "lat": "|".join("%.6f" % p[1] for p in points),
            "resource": "ign_rge_alti_wld", "zonly": "true",
        }).encode()
        req = urllib.request.Request(SERVICE, data=corps, headers={"Content-Type": "application/json", "User-Agent": AGENT})
        for essai in range(6):
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    contenu = r.read()
                break
            except (urllib.error.URLError, ConnectionError, TimeoutError):
                if essai == 5:
                    raise
                time.sleep(2 ** (essai + 1))
        with open(chemin, "wb") as f:
            f.write(contenu)
    with open(chemin, "rb") as f:
        return json.loads(f.read())["elevations"]


def main():
    if len(sys.argv) < 2 or sys.argv[1].startswith("--"):
        raise SystemExit(__doc__)
    ident = sys.argv[1]
    opts = lire_options(sys.argv[2:])
    dossier = os.path.join(RACINE, "communes", ident)
    if not os.path.isdir(dossier):
        dossier = os.path.join(RACINE, "tools", "paquet_essai", ident)
    nom = opts.get("nom", "lointain")
    if "centre" in opts:
        lon0, lat0 = (float(v) for v in opts["centre"].split(","))
    else:
        with open(os.path.join(dossier, "bourg.json"), encoding="utf-8") as f:
            lon0, lat0 = json.load(f)["origine"]
    x0, z0, x1, z1 = (float(v) for v in opts.get("cadre", "-18000,-18000,18000,18000").split(","))
    pas = float(opts.get("pas", "75"))
    ml = 111320.0 * math.cos(math.radians(lat0))
    mt = 110574.0
    nx = int(round((x1 - x0) / pas)) + 1
    nz = int(round((z1 - z0) / pas)) + 1
    cache = os.path.join(RACINE, "build", "relief_lointain", ident, nom)
    os.makedirs(cache, exist_ok=True)
    points = [(lon0 + (x0 + i * pas) / ml, lat0 - (z0 + j * pas) / mt) for j in range(nz) for i in range(nx)]
    alt = []
    for k in range(0, len(points), LOT):
        alt += demander(points[k:k + LOT], cache, "%d_%d_%07d.json" % (nx, nz, k))
        if k // LOT % 50 == 0:
            print("%s : %d / %d points" % (nom, k, len(points)), flush=True)
    # Les rares trous du service (-99999) prennent la valeur d'un voisin.
    for i, h in enumerate(alt):
        if h < -1000:
            alt[i] = alt[i - 1] if i > 0 else 0.0
    bas, haut = math.floor(min(alt)), math.ceil(max(alt))
    image = Image.new("RGB", (nx, nz))
    valeurs = [int(round((h - bas) / (haut - bas) * 65535)) for h in alt]
    image.putdata([(v >> 8, v & 255, 0) for v in valeurs])
    image.save(os.path.join(dossier, nom + ".png"))
    meta = {"format": 1, "source": "RGE ALTI, IGN (Licence Ouverte 2.0)", "origine": [lon0, lat0],
            "cadre": [x0, z0, x1, z1], "pas": pas, "taille": [nx, nz], "noir": bas, "blanc": haut}
    with open(os.path.join(dossier, nom + ".json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
    print("%s : %d × %d points, de %d à %d m" % (nom, nx, nz, bas, haut))


if __name__ == "__main__":
    main()
