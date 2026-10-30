#!/usr/bin/env python3
"""Les volumes de toute une ville, pour voir au loin ce qui n'est pas encore bâti (cartes/lyon/VILLE.md).

Tire de la BD TOPO de l'IGN le rectangle de chaque bâtiment d'un grand cadre (comme bourg_reel.py, par
tuiles de moins de 10 000 bâtiments), dans le repère de la commune (origine, x vers l'est, z vers le sud,
mètres), et l'écrit compact pour que quartiers/_ville/volumes.gd dessine la ville en boîtes là où aucun
quartier n'est encore livré.

  python3 tools/volumes_ville.py lyon --cadre=-900,-700,1700,2400 [--aire=60]

Écrit tools/paquet_essai/<id>/quartiers/_ville/volumes.json.gz : {"v": [[x, z, l, p, angle, h, toit], ...]}
avec x, z le centre du rectangle, l et p ses côtés, l'angle du grand côté (radians), h la hauteur des
murs (mètres), toit 0 tuile, 1 ardoise, 2 zinc, 3 plat ; tout en mètres au demi-mètre, sol lu dans le
relief de la ville au moment du dessin. Les réponses de l'IGN sont gardées dans tools/cache/<id>/.
"""
import gzip
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bourg_reel as br  # noqa: E402

TUILE = 700.0  # mètres de côté d'une tuile de requête


def main(argv):
    ident, cadre, aire_min = "", None, 60.0
    for a in argv:
        if a.startswith("--cadre="):
            cadre = [float(v) for v in a[len("--cadre="):].split(",")]
        elif a.startswith("--aire="):
            aire_min = float(a[len("--aire="):])
        elif not a.startswith("--"):
            ident = a
    if ident == "" or cadre is None or len(cadre) != 4:
        print(__doc__)
        return 2
    dossier = os.path.join(br.RACINE, "tools", "paquet_essai", ident)
    bourg = br.lire_json(os.path.join(dossier, "bourg.json"))
    proj = br.Projection(bourg["origine"])
    cache = os.path.join(br.RACINE, "tools", "cache", ident)
    os.makedirs(cache, exist_ok=True)
    x0, z0, x1, z1 = cadre
    volumes, vus = [], set()
    nxt = int(math.ceil((x1 - x0) / TUILE))
    nzt = int(math.ceil((z1 - z0) / TUILE))
    for j in range(nzt):
        for i in range(nxt):
            tx0, tz0 = x0 + i * TUILE, z0 + j * TUILE
            tx1, tz1 = min(x1, tx0 + TUILE), min(z1, tz0 + TUILE)
            lon_o, lat_s = proj.lonlat(tx0, tz1)
            lon_e, lat_n = proj.lonlat(tx1, tz0)
            wfs = ("https://data.geopf.fr/wfs/ows?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature"
                   "&TYPENAMES=BDTOPO_V3:batiment&OUTPUTFORMAT=application/json&SRSNAME=EPSG:4326&COUNT=10000"
                   "&BBOX=%.5f,%.5f,%.5f,%.5f,urn:ogc:def:crs:EPSG::4326" % (lat_s, lon_o, lat_n, lon_e))
            feats = json.loads(br.telecharger(wfs, cache, "ville_bati_%d_%d.json" % (i, j)))["features"]
            if len(feats) >= 10000:
                print("tuile %d,%d : 10 000 bâtiments, la tuile est trop grande" % (i, j), file=sys.stderr)
            for f in feats:
                fid = f.get("id") or f["properties"].get("cleabs")
                if fid in vus:
                    continue
                vus.add(fid)
                g = f["geometry"]
                if g is None:
                    continue
                pr = f["properties"]
                polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
                for poly in polys:
                    anneau = [proj.metres(c[0], c[1]) for c in poly[0]]
                    if anneau[0] == anneau[-1]:
                        anneau = anneau[:-1]
                    if len(anneau) < 3:
                        continue
                    c = br.centre(anneau)
                    if not (x0 <= c[0] <= x1 and z0 <= c[1] <= z1):
                        continue
                    if abs(br.aire(anneau)) < aire_min:
                        continue
                    haut = pr.get("hauteur")
                    if not haut:
                        etages = pr.get("nombre_d_etages") or 2
                        haut = 2.6 + 2.8 * etages
                    mat = (pr.get("materiaux_de_la_toiture") or "")
                    toit = 1 if "2" in mat else (2 if "3" in mat else (3 if "4" in mat else 0))
                    centre_m, lu, lv, ang, _ = br.rectangle(anneau)
                    volumes.append([round(centre_m[0] * 2) / 2, round(centre_m[1] * 2) / 2, round(lu * 2) / 2,
                                    round(lv * 2) / 2, round(ang, 2), round(min(haut, 60.0) * 2) / 2, toit])
        print("  rangée %d / %d : %d volumes" % (j + 1, nzt, len(volumes)), file=sys.stderr)
    sortie = os.path.join(dossier, "quartiers", "_ville")
    os.makedirs(sortie, exist_ok=True)
    chemin = os.path.join(sortie, "volumes.json.gz")
    with gzip.open(chemin, "wt", encoding="utf-8") as f:
        json.dump({"format": 1, "commune": ident, "origine": bourg["origine"], "cadre": cadre, "aire_min": aire_min,
                   "sources": "IGN, BD TOPO (Licence Ouverte 2.0)", "v": volumes}, f, separators=(",", ":"))
    print("%s : %d volumes de plus de %g m², %s (%.2f Mo)" % (ident, len(volumes), aire_min, chemin, os.path.getsize(chemin) / 1048576.0))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
