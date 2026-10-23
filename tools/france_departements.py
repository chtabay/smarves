#!/usr/bin/env python3
"""Construit communes/france.json : les 96 départements et les 13 régions de la France métropolitaine,
à leur vraie place.

Au-delà de la Vienne, la carte se dézoome sur la France (scripts/socle/france.gd) : la Vienne en or,
Smarves épinglée dedans, les régions cernées d'un trait plus franc, les autres départements en
filigrane, avec quelques grandes villes pour se repérer. Sources publiques : les contours des
départements (IGN, via france-geojson, version simplifiée) ; la région et le chef-lieu de chaque
département, et le nom des régions (paquet npm @etalab/decoupage-administratif, comme
tools/departement_communes.py). Le contour d'une région est l'union de ceux de ses départements.

Usage : python3 tools/france_departements.py   (demande shapely : python3 -m pip install shapely)
"""
import json
import os
import sys

from shapely.geometry import mapping, shape
from shapely.ops import unary_union

sys.path.insert(0, os.path.dirname(__file__))
from departement_communes import ETALAB, etalab, lire  # noqa: E402

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


def forme_et_centre(forme):
    centre = forme.representative_point() if not forme.centroid.within(forme) else forme.centroid
    geom = mapping(forme)
    polys = [geom["coordinates"]] if geom["type"] == "Polygon" else list(geom["coordinates"])
    # Chaque polygone : son contour extérieur seul, [lon, lat] par point ; les îlots minuscules
    # (moins de quatre points une fois simplifiés) ne se verraient pas.
    return [round(centre.x, 3), round(centre.y, 3)], [arrondir(p[0]) for p in polys if len(p[0]) >= 4]


def main():
    geo = lire(CONTOURS)
    deps = {d["code"]: d for d in etalab("departements.json")}
    region_de = {c: d["region"] for c, d in deps.items()}
    noms_regions = {r["code"]: r["nom"] for r in etalab("regions.json")}
    noms_communes = {c["code"]: c["nom"] for c in etalab("communes.json") if c.get("type") == "commune-actuelle"}
    out = []
    formes = {}
    for f in sorted(geo["features"], key=lambda f: f["properties"]["code"]):
        code = f["properties"]["code"]
        forme = shape(f["geometry"])
        formes[code] = forme.buffer(0)
        centre, contour = forme_et_centre(forme.simplify(TOLERANCE, preserve_topology=True))
        out.append({"code": code, "nom": f["properties"]["nom"], "region": region_de[code],
            "chef_lieu": noms_communes.get(deps[code]["chefLieu"], ""), "chef_lieu_insee": deps[code]["chefLieu"], "centre": centre, "contour": contour})
    regions = []
    for r in sorted(set(region_de[d["code"]] for d in out)):
        deps = [d["code"] for d in out if d["region"] == r]
        # Une union un peu épaissie puis rendue : les départements simplifiés ne se touchent pas tout à
        # fait, et l'union laisserait des fils entre eux.
        union = unary_union([formes[c] for c in deps]).buffer(0.02).buffer(-0.02)
        centre, contour = forme_et_centre(union.simplify(TOLERANCE * 2, preserve_topology=True))
        regions.append({"code": r, "nom": noms_regions[r], "departements": deps, "centre": centre, "contour": contour})
    with open(SORTIE, "w", encoding="utf-8") as f:
        json.dump({"nom": "France", "sources": [CONTOURS, ETALAB], "departements": out, "regions": regions, "villes": VILLES},
            f, ensure_ascii=False, separators=(",", ":"))
    print("%d départements et %d régions écrits dans %s" % (len(out), len(regions), os.path.normpath(SORTIE)))


if __name__ == "__main__":
    main()
