#!/usr/bin/env python3
"""Dessine la couverture réelle du sol d'un grand cadre : les bois, les vignes et vergers, les haies, l'eau
(fleuves, canaux, plans d'eau) et les routes, d'après la BD TOPO de l'IGN, en une image de classes. C'est le
complément de bourg_reel.py (le bourg, au mètre) pour ce qui l'entoure (une colline, une vallée, un fleuve).

Source : la BD TOPO de l'IGN (service WFS de la Géoplateforme, Licence Ouverte 2.0) : zone_de_vegetation,
surface_hydrographique, troncon_de_route.

Sortie, dans le dossier de la commune :
- couverture.png : une image en niveaux de gris, le nord en haut, un pixel par pas ; la valeur est la classe
  (CLASSES ci-dessous) ;
- couverture.json : l'origine, le cadre en mètres (ouest, nord, est, sud ; x vers l'est, z vers le sud), le
  pas, les classes, et les routes en lignes (x, z en mètres, largeur, nature, nom) pour que la scène les pose.

Usage : python3 -I tools/couverture_reelle.py <id> --cadre=-1600,-2600,8000,2400 --pas=5
  --nom=couverture   le nom des deux fichiers (couverture_lointaine pour un horizon)
  --sans-routes=1    sans les routes (un horizon de 36 km en compte des dizaines de milliers)
L'origine est celle de bourg.json (ou --centre=lon,lat). Les téléchargements sont gardés dans
build/couverture_reelle/<id>/. Demande Pillow.
"""
import json
import math
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image, ImageDraw

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
WFS = "https://data.geopf.fr/wfs/ows"
AGENT = "Smarves/1.0 (jeu ; https://github.com/chtabay/smarves)"
## Les classes de l'image, dans l'ordre où elles se peignent (la dernière gagne).
CLASSES = {"pre": 0, "foret": 1, "bosquet": 2, "haie": 3, "vigne": 4, "verger": 5, "lande": 6, "eau": 7, "route": 8}
## La nature BD TOPO de la végétation vers la classe.
VEGETATION = {
    "Forêt fermée de feuillus": "foret", "Forêt fermée mixte": "foret", "Forêt fermée de conifères": "foret",
    "Forêt ouverte": "bosquet", "Bois": "foret", "Peupleraie": "bosquet", "Bosquet": "bosquet",
    "Haie": "haie", "Vigne": "vigne", "Verger": "verger", "Lande ligneuse": "lande",
}


def telecharger(couche, bbox, cache):
    """Toutes les entités de la couche dans bbox (lat_s, lon_o, lat_n, lon_e), page après page."""
    tout, debut = [], 0
    while True:
        chemin = os.path.join(cache, "%s_%s_%06d.json" % (couche, "_".join("%.3f" % v for v in bbox), debut))
        if not os.path.exists(chemin):
            q = urllib.parse.urlencode({
                "SERVICE": "WFS", "VERSION": "2.0.0", "REQUEST": "GetFeature", "TYPENAMES": "BDTOPO_V3:" + couche,
                "OUTPUTFORMAT": "application/json", "COUNT": 5000, "STARTINDEX": debut,
                "BBOX": "%.5f,%.5f,%.5f,%.5f,urn:ogc:def:crs:EPSG::4326" % bbox})
            req = urllib.request.Request(WFS + "?" + q, headers={"User-Agent": AGENT})
            for essai in range(6):
                try:
                    with urllib.request.urlopen(req, timeout=240) as r:
                        contenu = r.read()
                    break
                except (urllib.error.URLError, ConnectionError, TimeoutError):
                    if essai == 5:
                        raise
                    time.sleep(2 ** (essai + 1))
            with open(chemin, "wb") as f:
                f.write(contenu)
        with open(chemin, "rb") as f:
            page = json.loads(f.read())["features"]
        tout += page
        if len(page) < 5000:
            return tout
        debut += 5000


def anneaux(geo):
    """Les anneaux extérieurs et les trous d'une géométrie surfacique : [(exterieur, [trous])]."""
    if geo is None:
        return []
    if geo["type"] == "Polygon":
        return [(geo["coordinates"][0], geo["coordinates"][1:])]
    if geo["type"] == "MultiPolygon":
        return [(p[0], p[1:]) for p in geo["coordinates"]]
    return []


def lignes(geo):
    if geo is None:
        return []
    if geo["type"] == "LineString":
        return [geo["coordinates"]]
    if geo["type"] == "MultiLineString":
        return geo["coordinates"]
    return []


def main():
    if len(sys.argv) < 2 or sys.argv[1].startswith("--"):
        raise SystemExit(__doc__)
    ident = sys.argv[1]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
    dossier = os.path.join(RACINE, "communes", ident)
    if not os.path.isdir(dossier):
        dossier = os.path.join(RACINE, "tools", "paquet_essai", ident)
    if "centre" in opts:
        lon0, lat0 = (float(v) for v in opts["centre"].split(","))
    else:
        with open(os.path.join(dossier, "bourg.json"), encoding="utf-8") as f:
            lon0, lat0 = json.load(f)["origine"]
    x0, z0, x1, z1 = (float(v) for v in opts.get("cadre", "-1600,-2600,8000,2400").split(","))
    pas = float(opts.get("pas", "5"))
    ml = 111320.0 * math.cos(math.radians(lat0))
    mt = 110574.0
    bbox = (lat0 - z1 / mt, lon0 + x0 / ml, lat0 - z0 / mt, lon0 + x1 / ml)
    nom = opts.get("nom", "couverture")
    avec_routes = opts.get("sans-routes", "0") in ("0", "")
    cache = os.path.join(RACINE, "build", "couverture_reelle", ident)
    os.makedirs(cache, exist_ok=True)
    w, h = int(round((x1 - x0) / pas)), int(round((z1 - z0) / pas))

    def px(c):
        # Le service rend [lat, lon] en EPSG:4326 (l'ordre des axes du code) ; on accepte les deux.
        lat, lon = (c[0], c[1]) if c[0] > c[1] else (c[1], c[0])
        return (((lon - lon0) * ml - x0) / pas, (-(lat - lat0) * mt - z0) / pas)

    def metres(c):
        lat, lon = (c[0], c[1]) if c[0] > c[1] else (c[1], c[0])
        return [round((lon - lon0) * ml, 2), round(-(lat - lat0) * mt, 2)]

    image = Image.new("L", (w, h), CLASSES["pre"])
    dessin = ImageDraw.Draw(image)
    vegetation = telecharger("zone_de_vegetation", bbox, cache)
    natures = {}
    for classe in ("foret", "bosquet", "lande", "verger", "vigne", "haie"):
        for f in vegetation:
            nature = f["properties"].get("nature") or ""
            natures[nature] = natures.get(nature, 0) + 1
            if VEGETATION.get(nature) != classe:
                continue
            for ext, trous in anneaux(f["geometry"]):
                dessin.polygon([px(c) for c in ext], fill=CLASSES[classe])
                for t in trous:
                    dessin.polygon([px(c) for c in t], fill=CLASSES["pre"])
    eau = telecharger("surface_hydrographique", bbox, cache)
    for f in eau:
        for ext, trous in anneaux(f["geometry"]):
            dessin.polygon([px(c) for c in ext], fill=CLASSES["eau"])
            for t in trous:
                dessin.polygon([px(c) for c in t], fill=CLASSES["pre"])
    routes = []
    for f in (telecharger("troncon_de_route", bbox, cache) if avec_routes else []):
        p = f["properties"]
        if p.get("position_par_rapport_au_sol") not in (None, "0", 0):
            pass
        largeur = p.get("largeur_de_chaussee") or {"Route à 2 chaussées": 14, "Route à 1 chaussée": 6, "Bretelle": 5,
                                                  "Chemin": 3, "Sentier": 1.5, "Route empierrée": 3.5}.get(p.get("nature"), 4)
        for l in lignes(f["geometry"]):
            routes.append({"p": [metres(c) for c in l], "l": float(largeur), "nature": p.get("nature"),
                           "nom": p.get("nom_collaboratif_gauche") or p.get("cpx_numero") or "",
                           "sol": p.get("position_par_rapport_au_sol")})
            if p.get("nature") not in ("Sentier", "Escalier"):
                dessin.line([px(c) for c in l], fill=CLASSES["route"], width=max(1, int(round(float(largeur) / pas))))
    image.save(os.path.join(dossier, nom + ".png"))
    meta = {"format": 1, "source": "BD TOPO, IGN (Licence Ouverte 2.0)", "origine": [lon0, lat0],
            "cadre": [x0, z0, x1, z1], "pas": pas, "taille": [w, h], "classes": CLASSES, "routes": routes}
    with open(os.path.join(dossier, nom + ".json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, separators=(",", ":"))
    print(nom + " : %d × %d px ; %d zones de végétation, %d surfaces d'eau, %d tronçons de route" % (w, h, len(vegetation), len(eau), len(routes)))
    print("natures : " + ", ".join("%s %d" % kv for kv in sorted(natures.items(), key=lambda kv: -kv[1])))


if __name__ == "__main__":
    main()
