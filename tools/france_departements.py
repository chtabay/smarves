#!/usr/bin/env python3
"""Construit communes/france.json : les 96 départements de la France métropolitaine, à leur vraie place.

Au-delà de la Vienne, la carte se dézoome sur la France (scripts/socle/france.gd) : la Vienne en or,
Smarves épinglée dedans, les autres départements en filigrane, avec quelques grandes villes pour se
repérer. Source publique : les contours des départements (IGN, via france-geojson, version simplifiée).

Usage : python3 tools/france_departements.py   (demande shapely : python3 -m pip install shapely)
"""
import json
import os
import urllib.request

from shapely.geometry import mapping, shape

CONTOURS = "https://raw.githubusercontent.com/gregoiredavid/france-geojson/master/departements-version-simplifiee.geojson"
SORTIE = os.path.join(os.path.dirname(__file__), "..", "communes", "france.json")
# Environ 1 km : assez fin pour la France entière à l'écran, léger dans le jeu.
TOLERANCE = 0.01
# Quelques grandes villes pour se repérer (longitude, latitude) : pas des destinations, des repères.
VILLES = [
    ["Paris", 2.3522, 48.8566], ["Lyon", 4.8357, 45.764], ["Marseille", 5.3698, 43.2965],
    ["Toulouse", 1.4442, 43.6047], ["Bordeaux", -0.5792, 44.8378], ["Nantes", -1.5536, 47.2184],
    ["Lille", 3.0573, 50.6292], ["Strasbourg", 7.7521, 48.5734], ["Nice", 7.262, 43.7102],
    ["Rennes", -1.6778, 48.1173], ["Limoges", 1.2611, 45.8336], ["Tours", 0.6848, 47.3941],
    ["La Rochelle", -1.1511, 46.1603],
]


def arrondir(o):
    if isinstance(o, float):
        return round(o, 3)
    if isinstance(o, (list, tuple)):
        return [arrondir(x) for x in o]
    return o


def main():
    with urllib.request.urlopen(CONTOURS) as r:
        geo = json.load(r)
    out = []
    for f in sorted(geo["features"], key=lambda f: f["properties"]["code"]):
        forme = shape(f["geometry"]).simplify(TOLERANCE, preserve_topology=True)
        centre = forme.representative_point() if not forme.centroid.within(forme) else forme.centroid
        geom = mapping(forme)
        polys = [geom["coordinates"]] if geom["type"] == "Polygon" else list(geom["coordinates"])
        out.append({
            "code": f["properties"]["code"],
            "nom": f["properties"]["nom"],
            "centre": [round(centre.x, 3), round(centre.y, 3)],
            # Chaque polygone : son contour extérieur seul, [lon, lat] par point ; les îlots minuscules
            # (moins de quatre points une fois simplifiés) ne se verraient pas.
            "contour": [arrondir(p[0]) for p in polys if len(p[0]) >= 4],
        })
    with open(SORTIE, "w", encoding="utf-8") as f:
        json.dump({"nom": "France", "sources": [CONTOURS], "departements": out, "villes": VILLES},
            f, ensure_ascii=False, separators=(",", ":"))
    print("%d départements écrits dans %s" % (len(out), os.path.normpath(SORTIE)))


if __name__ == "__main__":
    main()
