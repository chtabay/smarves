#!/usr/bin/env python3
"""Construit communes/vienne.json : les communes actuelles de la Vienne, à leur vraie place.

La carte de la Vienne pose chaque commune là où elle est (docs/COMMUNE.md). Deux sources publiques :
- la liste officielle des communes actuelles (code INSEE, nom, population, anciens codes des
  communes fusionnées), paquet npm @etalab/decoupage-administratif ;
- les contours des communes (IGN, via france-geojson), antérieurs aux fusions de 2019 : le contour
  d'une commune nouvelle est l'union des contours de ses anciennes communes.

Usage : python3 tools/vienne_communes.py   (demande shapely : python3 -m pip install shapely)
"""
import io
import json
import os
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

from shapely.geometry import mapping, shape
from shapely.ops import unary_union

ETALAB = "@etalab/decoupage-administratif@6.0.0"
CONTOURS = "https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/departements/86-vienne/communes-86-vienne.geojson"
SORTIE = os.path.join(os.path.dirname(__file__), "..", "communes", "vienne.json")
# Environ 10 m : assez fin pour une carte du département, léger dans le jeu.
TOLERANCE = 0.0004


def communes_actuelles():
    with tempfile.TemporaryDirectory() as d:
        subprocess.run(["npm", "pack", ETALAB, "--silent"], cwd=d, check=True, capture_output=True)
        tgz = [f for f in os.listdir(d) if f.endswith(".tgz")][0]
        with tarfile.open(os.path.join(d, tgz)) as t:
            data = json.load(io.TextIOWrapper(t.extractfile("package/data/communes.json"), "utf-8"))
    return [c for c in data if c.get("departement") == "86" and c.get("type") == "commune-actuelle"]


def contours():
    with urllib.request.urlopen(CONTOURS) as r:
        geo = json.load(r)
    return {f["properties"]["code"]: shape(f["geometry"]) for f in geo["features"]}


def arrondir(o):
    if isinstance(o, float):
        return round(o, 4)
    if isinstance(o, (list, tuple)):
        return [arrondir(x) for x in o]
    return o


def main():
    actuelles = communes_actuelles()
    formes = contours()
    out = []
    manquants = []
    for c in sorted(actuelles, key=lambda c: c["code"]):
        codes = [c["code"]] + c.get("anciensCodes", [])
        parts = [formes[k] for k in codes if k in formes]
        if not parts:
            manquants.append(c["nom"])
            continue
        forme = unary_union(parts).simplify(TOLERANCE, preserve_topology=True)
        centre = forme.representative_point() if not forme.centroid.within(forme) else forme.centroid
        geom = mapping(forme)
        polys = [geom["coordinates"]] if geom["type"] == "Polygon" else list(geom["coordinates"])
        out.append({
            "insee": c["code"],
            "nom": c["nom"],
            "population": c.get("population", 0),
            "centre": [round(centre.x, 4), round(centre.y, 4)],
            # Chaque polygone : son contour extérieur seul, [lon, lat] par point.
            "contour": [arrondir(p[0]) for p in polys],
        })
    if manquants:
        sys.exit("contours introuvables : " + ", ".join(manquants))
    with open(SORTIE, "w", encoding="utf-8") as f:
        json.dump({"departement": "86", "nom": "Vienne", "sources": [ETALAB, CONTOURS], "communes": out},
            f, ensure_ascii=False, separators=(",", ":"))
    print("%d communes écrites dans %s" % (len(out), os.path.normpath(SORTIE)))


if __name__ == "__main__":
    main()
