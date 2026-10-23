#!/usr/bin/env python3
"""Construit le référentiel des communes d'un département, à leur vraie place.

La carte pose chaque commune là où elle est (docs/COMMUNE.md). La Vienne est dans communes/vienne.json
(tools/vienne_communes.py) ; les autres départements que la carte sait montrer commune par commune
sont dans communes/departements/<code>.json (scripts/socle/departements.gd), au même format. Deux
sources publiques :
- la liste officielle des communes actuelles (code INSEE, nom, population, anciens codes des
  communes fusionnées), paquet npm @etalab/decoupage-administratif ;
- les contours des communes (IGN, via france-geojson), antérieurs aux fusions : le contour d'une
  commune nouvelle est l'union des contours de ses anciennes communes.

Usage : python3 tools/departement_communes.py 33 16 17 …   (sans code : la Nouvelle-Aquitaine hors Vienne)
        (demande shapely : python3 -m pip install shapely)
"""
import io
import json
import os
import subprocess
import sys
import tarfile
import tempfile
import time
import unicodedata
import urllib.request

from shapely.geometry import mapping, shape
from shapely.ops import unary_union

ETALAB = "@etalab/decoupage-administratif@6.0.0"
CONTOURS = "https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/departements/{dossier}/communes-{dossier}.geojson"
DOSSIER = os.path.join(os.path.dirname(__file__), "..", "communes")
# La Nouvelle-Aquitaine, la région de la Vienne : le car régional y va (scripts/carte.gd).
NOUVELLE_AQUITAINE = ["16", "17", "19", "23", "24", "33", "40", "47", "64", "79", "87"]
# Environ 10 m pour la Vienne, où l'on zoome jusqu'au bourg ; environ 50 m ailleurs, assez pour
# reconnaître chaque commune sans alourdir le jeu.
TOLERANCE = 0.0004
TOLERANCE_AILLEURS = 0.002


def etalab(fichier):
    """Un fichier de données du paquet npm d'Etalab (communes.json, departements.json, regions.json)."""
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["npm", "pack", ETALAB, "--silent"], cwd=d, check=True, capture_output=True)
        tgz = [f for f in os.listdir(d) if f.endswith(".tgz")][0]
        with tarfile.open(os.path.join(d, tgz)) as t:
            return json.load(io.TextIOWrapper(t.extractfile("package/data/" + fichier), "utf-8"))


def lire(url):
    """Un JSON public, avec quelques nouvelles tentatives : les serveurs coupent parfois."""
    for essai in range(5):
        try:
            with urllib.request.urlopen(url, timeout=120) as r:
                return json.load(r)
        except OSError:
            if essai == 4:
                raise
            time.sleep(2 ** essai)


def dossier(code, nom):
    """Le dossier de france-geojson : « 64-pyrenees-atlantiques »."""
    s = unicodedata.normalize("NFKD", nom).encode("ascii", "ignore").decode().lower()
    return "%s-%s" % (code, "-".join("".join(c if c.isalnum() else " " for c in s).split()))


def arrondir(o, n):
    if isinstance(o, float):
        return round(o, n)
    if isinstance(o, (list, tuple)):
        return [arrondir(x, n) for x in o]
    return o


def referentiel(code, communes, departements, tolerance=TOLERANCE, decimales=4):
    nom = next(d["nom"] for d in departements if d["code"] == code)
    url = CONTOURS.format(dossier=dossier(code, nom))
    formes = {f["properties"]["code"]: shape(f["geometry"]).buffer(0) for f in lire(url)["features"]}
    actuelles = [c for c in communes if c.get("departement") == code and c.get("type") == "commune-actuelle"]
    out = []
    manquants = []
    for c in sorted(actuelles, key=lambda c: c["code"]):
        codes = [c["code"]] + c.get("anciensCodes", [])
        parts = [formes[k] for k in codes if k in formes]
        if not parts:
            manquants.append(c["nom"])
            continue
        forme = unary_union(parts).simplify(tolerance, preserve_topology=True)
        centre = forme.representative_point() if not forme.centroid.within(forme) else forme.centroid
        geom = mapping(forme)
        polys = [geom["coordinates"]] if geom["type"] == "Polygon" else list(geom["coordinates"])
        out.append({
            "insee": c["code"],
            "nom": c["nom"],
            "population": c.get("population", 0),
            "centre": [round(centre.x, decimales), round(centre.y, decimales)],
            # Chaque polygone : son contour extérieur seul, [lon, lat] par point.
            "contour": [arrondir(p[0], decimales) for p in polys if len(p[0]) >= 4],
        })
    if manquants:
        sys.exit("%s : contours introuvables : %s" % (nom, ", ".join(manquants)))
    return {"departement": code, "nom": nom, "sources": [ETALAB, url], "communes": out}


def ecrire(chemin, data):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    with open(chemin, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("%s : %d communes écrites dans %s (%d Ko)" % (data["nom"], len(data["communes"]), os.path.normpath(chemin), os.path.getsize(chemin) // 1024))


def main():
    codes = sys.argv[1:] or NOUVELLE_AQUITAINE
    communes = etalab("communes.json")
    departements = etalab("departements.json")
    for code in codes:
        if code == "86":
            ecrire(os.path.join(DOSSIER, "vienne.json"), referentiel(code, communes, departements))
        else:
            ecrire(os.path.join(DOSSIER, "departements", code + ".json"),
                referentiel(code, communes, departements, TOLERANCE_AILLEURS, 3))


if __name__ == "__main__":
    main()
