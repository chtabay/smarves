#!/usr/bin/env python3
"""Relève les routes réelles d'une commune hors du bourg (BD TOPO de l'IGN, couche troncon_de_route, Licence
Ouverte 2.0), pour qu'elles soient maillées en rubans posés sur le sol, avec leur marquage, au lieu d'être peintes
en pixels dans la couverture.

    python3 tools/routes_reelles.py <id> --cadre=x0,z0,x1,z1 [--hors=x0,z0,x1,z1] [--sortie=relief/routes]

Le cadre est en mètres dans le repère de la commune (celui de relief/couverture.json) ; « hors » écarte un cadre
(le bourg, dont les rues sont déjà maillées). Écrit <sortie>.json : une liste de routes, chacune
{"l": largeur de chaussée, "g": genre (0 route, 1 route empierrée, 2 chemin), "m": marquage (0 rien, 1 axe en
tirets et rives), "p": [x, z, x, z, ...]} ; les tunnels sont omis.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from couverture_reelle import RACINE, telecharger  # noqa: E402

GENRES = {"Route à 1 chaussée": 0, "Route à 2 chaussées": 0, "Bretelle": 0, "Rond-point": 0, "Type autoroutier": 0,
          "Route empierrée": 1, "Chemin": 2}
LARGEUR = {0: 5.0, 1: 3.0, 2: 2.4}


def simplifier(pts, tol):
    """Douglas-Peucker : les points qui s'écartent de moins de tol de la corde tombent."""
    if len(pts) < 3:
        return pts
    a, b = pts[0], pts[-1]
    dx, dz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dz) or 1e-9
    k, dmax = 0, -1.0
    for i in range(1, len(pts) - 1):
        d = abs((pts[i][0] - a[0]) * dz - (pts[i][1] - a[1]) * dx) / n
        if d > dmax:
            k, dmax = i, d
    if dmax < tol:
        return [a, b]
    return simplifier(pts[:k + 1], tol)[:-1] + simplifier(pts[k:], tol)


def main():
    if len(sys.argv) < 2 or sys.argv[1].startswith("--"):
        raise SystemExit(__doc__)
    ident = sys.argv[1]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
    dossier = os.path.join(RACINE, "communes", ident)
    if not os.path.isdir(dossier):
        dossier = os.path.join(RACINE, "tools", "paquet_essai", ident)
    with open(os.path.join(dossier, "relief", "couverture.json"), encoding="utf-8") as f:
        lon0, lat0 = json.load(f)["origine"]
    x0, z0, x1, z1 = (float(v) for v in opts["cadre"].split(","))
    hors = [float(v) for v in opts["hors"].split(",")] if "hors" in opts else None
    ml = 111320.0 * math.cos(math.radians(lat0))
    mt = 110574.0
    bbox = (lat0 - z1 / mt, lon0 + x0 / ml, lat0 - z0 / mt, lon0 + x1 / ml)
    cache = os.path.join(RACINE, "build", "couverture_reelle", ident)
    os.makedirs(cache, exist_ok=True)
    routes = []
    longueur = 0.0
    for f in telecharger("troncon_de_route", bbox, cache):
        pr = f["properties"]
        g = GENRES.get(pr.get("nature") or "")
        if g is None or not f["geometry"] or str(pr.get("position_par_rapport_au_sol") or "0").startswith("-"):
            continue
        if pr.get("fictif"):
            continue
        lignes = f["geometry"]["coordinates"]
        if f["geometry"]["type"] == "LineString":
            lignes = [lignes]
        for ligne in lignes:
            pts = []
            for c in ligne:
                lat, lon = (c[0], c[1]) if c[0] > c[1] else (c[1], c[0])
                pts.append(((lon - lon0) * ml, -(lat - lat0) * mt))
            # Hors du cadre ou dans le bourg : coupé en morceaux qui restent dedans.
            morceaux, cur = [], []
            for p in pts:
                dedans = x0 <= p[0] <= x1 and z0 <= p[1] <= z1
                if hors and hors[0] <= p[0] <= hors[2] and hors[1] <= p[1] <= hors[3]:
                    dedans = False
                if dedans:
                    cur.append(p)
                else:
                    if len(cur) > 1:
                        morceaux.append(cur)
                    cur = []
            if len(cur) > 1:
                morceaux.append(cur)
            for m in morceaux:
                m = simplifier(m, 0.6)
                l = float(pr.get("largeur_de_chaussee") or 0.0) or LARGEUR[g]
                if g == 0:
                    l = max(l, 3.5)
                marque = 1 if g == 0 and l >= 5.0 else 0
                routes.append({"l": round(l, 1), "g": g, "m": marque,
                               "p": [round(v, 1) for q in m for v in q]})
                longueur += sum(math.hypot(m[i + 1][0] - m[i][0], m[i + 1][1] - m[i][1]) for i in range(len(m) - 1))
    sortie = os.path.join(dossier, opts.get("sortie", "relief/routes") + ".json")
    with open(sortie, "w", encoding="utf-8") as f:
        json.dump({"source": "IGN BD TOPO, troncon_de_route (Licence Ouverte 2.0)", "routes": routes}, f,
                  ensure_ascii=False, separators=(",", ":"))
    print("%d tronçons, %.1f km, écrits dans %s" % (len(routes), longueur / 1000.0, sortie))


if __name__ == "__main__":
    main()
