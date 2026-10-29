#!/usr/bin/env python3
"""Peint la roche dans une carte de couverture (tools/couverture_reelle.py), d'après le relief réel
(tools/relief_lointain.py) et les rochers nommés de la BD TOPO (detail_orographique, « Rochers ») :
la roche est là où le versant se redresse au-delà de ce que tiennent les bois, et là où un pré (aucune
végétation recensée) s'accroche à une pente forte ; près d'un rocher nommé, le seuil baisse.

    python3 tools/roche_reelle.py <id> --couverture=relief/couverture --relief=relief/relief

La carte est réécrite sur place, la roche en classe 10 ; son .json reçoit la classe et le compte.
"""
import json
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from couverture_reelle import RACINE, telecharger  # noqa: E402

ROCHE = 10
## Les seuils de pente (en degrés) : sous le bois, en pré ou en lande, et le rabais près d'un rocher nommé.
SEUIL_BOIS = 42.0
SEUIL_NU = 33.0
RABAIS = 7.0
PRES_ROCHER = 350.0


def carte(dossier, nom):
    with open(os.path.join(dossier, nom + ".json"), encoding="utf-8") as f:
        meta = json.load(f)
    return meta, Image.open(os.path.join(dossier, nom + ".png"))


def main():
    if len(sys.argv) < 2 or sys.argv[1].startswith("--"):
        raise SystemExit(__doc__)
    ident = sys.argv[1]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
    dossier = os.path.join(RACINE, "communes", ident)
    if not os.path.isdir(dossier):
        dossier = os.path.join(RACINE, "tools", "paquet_essai", ident)
    cmeta, couv = carte(dossier, opts.get("couverture", "relief/couverture"))
    rmeta, rel = carte(dossier, opts.get("relief", "relief/relief"))
    rx0, rz0 = rmeta["cadre"][0], rmeta["cadre"][1]
    rp = float(rmeta["pas"])
    rw, rh = rel.size
    px = rel.convert("RGB").load()
    noir, blanc = float(rmeta["noir"]), float(rmeta["blanc"])
    alt = [[noir + (px[i, j][0] * 256 + px[i, j][1]) / 65535.0 * (blanc - noir) for i in range(rw)] for j in range(rh)]

    def h(x, z):
        fi = min(max((x - rx0) / rp, 0.0), rw - 1.001)
        fj = min(max((z - rz0) / rp, 0.0), rh - 1.001)
        i, j = int(fi), int(fj)
        fi -= i
        fj -= j
        a, b = alt[j][i], alt[j][i + 1]
        c, d = alt[j + 1][i], alt[j + 1][i + 1]
        return (a * (1 - fi) + b * fi) * (1 - fj) + (c * (1 - fi) + d * fi) * fj

    lon0, lat0 = cmeta["origine"]
    ml = 111320.0 * math.cos(math.radians(lat0))
    mt = 110574.0
    x0, z0, x1, z1 = cmeta["cadre"]
    bbox = (lat0 - z1 / mt, lon0 + x0 / ml, lat0 - z0 / mt, lon0 + x1 / ml)
    cache = os.path.join(RACINE, "build", "couverture_reelle", ident)
    os.makedirs(cache, exist_ok=True)
    rochers = []
    for f in telecharger("detail_orographique", bbox, cache):
        if (f["properties"].get("nature") or "") != "Rochers" or not f["geometry"]:
            continue
        c = f["geometry"]["coordinates"]
        lat, lon = (c[0], c[1]) if c[0] > c[1] else (c[1], c[0])
        rochers.append(((lon - lon0) * ml, -(lat - lat0) * mt))
    pas = float(cmeta["pas"])
    w, hh = couv.size
    cl = couv.load()
    d = max(rp, pas)
    peints = 0
    # Les rochers nommés, rangés par case de PRES_ROCHER pour les retrouver vite.
    cases = {}
    for r in rochers:
        cases.setdefault((int(r[0] // PRES_ROCHER), int(r[1] // PRES_ROCHER)), []).append(r)
    for j in range(hh):
        z = z0 + (j + 0.5) * pas
        for i in range(w):
            x = x0 + (i + 0.5) * pas
            c = cl[i, j]
            if c in (7, 8, ROCHE):
                continue
            # Seulement là où le relief donné couvre (une grille plus fine peut reprendre un morceau).
            if not (rx0 <= x <= rx0 + (rw - 1) * rp and rz0 <= z <= rz0 + (rh - 1) * rp):
                continue
            gx = (h(x + d, z) - h(x - d, z)) / (2 * d)
            gz = (h(x, z + d) - h(x, z - d)) / (2 * d)
            pente = math.degrees(math.atan(math.hypot(gx, gz)))
            seuil = SEUIL_BOIS if c in (1, 2, 5) else SEUIL_NU
            if pente < seuil - RABAIS:
                continue
            k = (int(x // PRES_ROCHER), int(z // PRES_ROCHER))
            pres = any(math.hypot(r[0] - x, r[1] - z) < PRES_ROCHER
                       for a in (-1, 0, 1) for b in (-1, 0, 1) for r in cases.get((k[0] + a, k[1] + b), ()))
            if pente >= seuil - (RABAIS if pres else 0.0):
                cl[i, j] = ROCHE
                peints += 1
    couv.save(os.path.join(dossier, opts.get("couverture", "relief/couverture") + ".png"))
    cmeta["classes"]["roche"] = ROCHE
    cmeta["roche"] = {"source": "pente RGE ALTI et rochers BD TOPO", "px": peints, "rochers": len(rochers)}
    with open(os.path.join(dossier, opts.get("couverture", "relief/couverture") + ".json"), "w", encoding="utf-8") as f:
        json.dump(cmeta, f, ensure_ascii=False, separators=(",", ":"))
    print("roche : %d px sur %d (%.2f %%), %d rochers nommés" % (peints, w * hh, 100.0 * peints / (w * hh), len(rochers)))


if __name__ == "__main__":
    main()
