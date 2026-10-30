#!/usr/bin/env python3
"""Le relief d'une ville entière, pour ses quartiers (Lyon, cartes/lyon/VILLE.md).

Une commune bâtie par quartiers lit son relief par la fonction hauteur(x, z) de sa scène ; hors de la
grille fine du premier quartier, celle-ci délègue au relief de la ville, quartiers/_ville/relief.gd, une
grille plus lâche (10 m) sur toute la ville, tirée du RGE ALTI de l'IGN comme bourg_reel.py, dans le
même repère (origine, x vers l'est, z vers le sud, mètres) et avec le même zéro (altitude_zero du
bourg.json de la commune, le niveau de la rivière).

  python3 tools/relief_ville.py lyon --cadre=-900,-700,1700,2400 [--pas=10]

Écrit tools/paquet_essai/<id>/quartiers/_ville/relief.json.gz : {x0, z0, pas, nx, nz, zero, h} avec h en
décimètres entiers au-dessus du zéro (lecture par relief.gd). Les réponses de l'IGN sont gardées dans
le cache de bourg_reel (tools/cache/<id>/).
"""
import gzip
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bourg_reel as br  # noqa: E402


def main(argv):
    ident, cadre, pas = "", None, 10.0
    for a in argv:
        if a.startswith("--cadre="):
            cadre = [float(v) for v in a[len("--cadre="):].split(",")]
        elif a.startswith("--pas="):
            pas = float(a[len("--pas="):])
        elif not a.startswith("--"):
            ident = a
    if ident == "" or cadre is None or len(cadre) != 4:
        print(__doc__)
        return 2
    dossier = os.path.join(br.RACINE, "tools", "paquet_essai", ident)
    bourg = br.lire_json(os.path.join(dossier, "bourg.json"))
    origine, zero = bourg["origine"], bourg["altitude_zero"]
    proj = br.Projection(origine)
    cache = os.path.join(br.RACINE, "tools", "cache", ident)
    os.makedirs(cache, exist_ok=True)
    x0, z0, x1, z1 = cadre
    nx = int(round((x1 - x0) / pas)) + 1
    nz = int(round((z1 - z0) / pas)) + 1
    points = [proj.lonlat(x0 + i * pas, z0 + j * pas) for j in range(nz) for i in range(nx)]
    alt = []
    lot = 400
    for k in range(0, len(points), lot):
        part = points[k:k + lot]
        corps = json.dumps({"lon": "|".join("%.6f" % p[0] for p in part), "lat": "|".join("%.6f" % p[1] for p in part),
                            "resource": "ign_rge_alti_wld", "zonly": "true"}).encode()
        r = br.telecharger("https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json",
                           cache, "ville_%g_%d_%d_%05d.json" % (pas, nx, nz, k), corps)
        alt += json.loads(r)["elevations"]
        if (k // lot) % 20 == 0:
            print("  %d / %d points" % (min(k + lot, len(points)), len(points)), file=sys.stderr)
    for i, h in enumerate(alt):
        if h < -1000:
            alt[i] = alt[i - 1] if i > 0 else zero
    h = [int(round((a - zero) * 10.0)) for a in alt]
    sortie = os.path.join(dossier, "quartiers", "_ville")
    os.makedirs(sortie, exist_ok=True)
    with gzip.open(os.path.join(sortie, "relief.json.gz"), "wt", encoding="utf-8") as f:
        json.dump({"format": 1, "commune": ident, "origine": origine, "zero": zero, "unite": "decimetres au-dessus du zero",
                   "sources": "IGN, RGE ALTI (Licence Ouverte 2.0)",
                   "x0": x0, "z0": z0, "pas": pas, "nx": nx, "nz": nz, "h": h}, f, separators=(",", ":"))
    print("%s : relief %d × %d au pas de %g m, de %.1f à %.1f m au-dessus du zéro (%g m), %s"
          % (ident, nx, nz, pas, min(h) / 10.0, max(h) / 10.0, zero, os.path.join(sortie, "relief.json.gz")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
