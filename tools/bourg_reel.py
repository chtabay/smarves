#!/usr/bin/env python3
"""Construit le plan réel d'un bourg pour une commune en paquet : rues, places, bâtiments à leur
place et à leur hauteur, rivières, bois, et le relief du terrain.

Trois sources ouvertes :
- OpenStreetMap (API 0.6, © les contributeurs d'OpenStreetMap, ODbL) : les rues, les ponts, les
  places, l'eau, les bois et les lieux remarquables ;
- la BD TOPO de l'IGN (service WFS de la Géoplateforme, Licence Ouverte 2.0) : l'emprise des
  bâtiments, l'altitude de leur sol, de leur gouttière et de leur faîtage, le matériau du toit ;
- le RGE ALTI de l'IGN (service d'altimétrie de la Géoplateforme) : le relief, une grille de 5 m.

Sortie, dans le dossier de la commune :
- bourg.json : tout ce que la scène construit, en unités du jeu (1 unité = 2,4 m, l'échelle de
  Smarves), x vers l'est, z vers le sud, y vers le haut, l'altitude la plus basse du cadre à y = 0 ;
- sol.png : la couverture du sol (herbe, prés, bois, places, eau), un pixel par mètre ;
- build/plan_<id>.png : le plan vu de dessus, pour comparer avec la carte.

Usage : python3 -I tools/bourg_reel.py <id> [options]
Le dossier de la commune est communes/<id>/ (celui du kit), sinon tools/paquet_essai/<id>/. Le code
INSEE suffit : il est lu dans le manifeste commune.json, et l'outil en tire le centre du bourg (le lieu
« village » d'OpenStreetMap qui porte le nom de la commune) et un cadre de 1 km de côté autour.
Les réglages se gardent dans bourg_reel.json, à côté du manifeste (voir celui d'Availles-Limouzine,
tools/paquet_essai/availles_limouzine/bourg_reel.json) ; une option de la ligne de commande passe
devant le fichier :
  --insee=86015              le code INSEE, s'il n'est pas dans le manifeste
  --centre=0.656,46.1215     le centre du bourg (longitude, latitude), origine du plan
  --cadre=-600,-330,460,420  le cadre en mètres autour du centre : ouest, nord, est, sud
  --rayon=500                ou un cadre carré de ce demi-côté
  --riviere="La Vienne"      le nom donné à l'eau qu'OpenStreetMap ne nomme pas
  --remarquables=lieux.json  les lieux remarquables : une liste de {"id", "nom", "genre", "osm"},
                             genre parmi monument, ouvrage, commerce, maison, lieu ; osm est
                             l'objet d'OpenStreetMap (way/64158647 ou node/4280211690), ou un
                             point lonlat/0.65725,46.1205 pour un lieu sans objet à lui ; "absorbe",
                             facultatif : des points [x, z] en unités du jeu, les bâtiments que la
                             silhouette du lieu couvre et que la scène ne dessine pas à part
  --dossier=chemin           un autre dossier de commune, relatif à la racine du dépôt
  --cache=dossier            le cache des téléchargements (build/bourg_reel/<id>/ par défaut)
Demande Pillow (python3 -m pip install pillow). Les téléchargements sont gardés dans le cache :
relancer l'outil ne réinterroge pas les services.
"""
import json
import math
import os
import sys
import time
import urllib.parse
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFilter

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
UNITE = 2.4  # mètres par unité du jeu, comme à Smarves (docs/SUITE.md)
PAS_RELIEF = 5.0  # mètres entre deux points de la grille du relief
AGENT = "Smarves/1.0 (jeu ; https://github.com/chtabay/smarves)"

# Les réglages d'un bourg, du plus fort au plus faible : les options de la ligne de commande, le
# fichier bourg_reel.json du dossier de la commune, puis les valeurs par défaut tirées du code INSEE.
RAYON = 500.0  # mètres autour du centre quand le cadre n'est pas donné
REGLAGES = ("insee", "centre", "cadre", "rayon", "riviere", "remarquables", "dossier", "cache")


def lire_json(chemin):
    with open(chemin, encoding="utf-8") as f:
        return json.load(f)


def commune_vienne(insee):
    """La commune `insee` : dans communes/vienne.json, sinon dans le fichier de son département
    (communes/departements/<dép>.json, qui porte le nom du département dans son champ « nom »)."""
    for c in lire_json(os.path.join(RACINE, "communes", "vienne.json"))["communes"]:
        if c["insee"] == insee:
            return dict(c, departement="Vienne")
    chemin = os.path.join(RACINE, "communes", "departements", "%s.json" % insee[:2])
    if os.path.exists(chemin):
        dep = lire_json(chemin)
        for c in dep["communes"]:
            if c["insee"] == insee:
                return dict(c, departement=dep["nom"])
    return None


def centre_du_bourg(nom, insee, cache, departement="Vienne"):
    """Le centre du bourg : le lieu « ville » ou « village » d'OpenStreetMap qui porte le nom de la
    commune (le clocher, d'ordinaire), par Nominatim ; à défaut, le centre de la commune dans
    communes/vienne.json (ou celui de son département), qui tombe souvent en pleine campagne."""
    q = urllib.parse.urlencode({"q": "%s, %s, France" % (nom, departement), "format": "json", "limit": 5,
                                "featuretype": "settlement"})
    try:
        for r in json.loads(telecharger("https://nominatim.openstreetmap.org/search?" + q, cache, "centre_%s.json" % insee)):
            if r.get("addresstype") in ("town", "village", "city", "hamlet") or r.get("type") in ("town", "village", "city"):
                return (round(float(r["lon"]), 5), round(float(r["lat"]), 5))
    except (urllib.error.URLError, ConnectionError, ValueError, KeyError):
        pass
    c = commune_vienne(insee)
    print("centre du bourg introuvable sur OpenStreetMap : centre de la commune, à préciser par --centre=lon,lat")
    return tuple(c["centre"])


def reglages(ident, args):
    """Réunit les réglages du bourg `ident` (voir l'usage en tête du fichier)."""
    opts = {}
    for a in args:
        if not a.startswith("--") or "=" not in a or a[2:].split("=", 1)[0] not in REGLAGES:
            raise SystemExit("option inconnue : %s\n%s" % (a, __doc__))
        k, v = a[2:].split("=", 1)
        opts[k] = v
    dossier = opts.get("dossier")
    if dossier is None:
        dossier = os.path.join("communes", ident)
        if not os.path.isdir(os.path.join(RACINE, dossier)):
            dossier = os.path.join("tools", "paquet_essai", ident)
    plein = os.path.join(RACINE, dossier)
    if not os.path.isdir(plein):
        raise SystemExit("pas de dossier %s : posez d'abord la commune (le kit) ou donnez --dossier=" % dossier)
    fichier = os.path.join(plein, "bourg_reel.json")
    cfg = lire_json(fichier) if os.path.exists(fichier) else {}
    manifeste = os.path.join(plein, "commune.json")
    insee = opts.get("insee") or cfg.get("insee") or (lire_json(manifeste).get("insee") if os.path.exists(manifeste) else None)
    c = commune_vienne(str(insee)) if insee else None
    if c is None:
        raise SystemExit("code INSEE inconnu : %s (ni dans communes/vienne.json, ni dans communes/departements/)" % insee)
    cache = opts.get("cache") or os.path.join(RACINE, "build", "bourg_reel", ident)
    os.makedirs(cache, exist_ok=True)
    if "centre" in opts:
        centre = tuple(float(x) for x in opts["centre"].split(","))
    elif "centre" in cfg:
        centre = tuple(cfg["centre"])
    else:
        centre = centre_du_bourg(c["nom"], c["insee"], cache, c["departement"])
    if "cadre" in opts:
        cadre = tuple(float(x) for x in opts["cadre"].split(","))
    elif "cadre" in cfg and "rayon" not in opts:
        cadre = tuple(cfg["cadre"])
    else:
        r = float(opts.get("rayon", cfg.get("rayon", RAYON)))
        cadre = (-r, -r, r, r)
    rem = cfg.get("remarquables", [])
    if "remarquables" in opts:
        rem = lire_json(opts["remarquables"])
        rem = rem.get("remarquables", []) if isinstance(rem, dict) else rem
    remarquables = []
    for x in rem:
        if isinstance(x, dict):
            remarquables.append((x["id"], x["nom"], x.get("genre", "lieu"), x["osm"], x.get("absorbe", [])))
        else:
            remarquables.append(tuple(x)[:4] + (list(x[4]) if len(x) > 4 else [],))
    return {"dossier": dossier, "cache": cache, "insee": c["insee"], "nom": c["nom"], "origine": centre,
            "cadre": cadre, "riviere": opts.get("riviere", cfg.get("riviere", "")), "remarquables": remarquables}


LARGEURS = {  # largeur des voies, en mètres
    "primary": 8.0, "secondary": 7.0, "tertiary": 6.0, "residential": 5.0, "unclassified": 4.5,
    "living_street": 4.0, "road": 4.5, "service": 3.5, "pedestrian": 4.0, "track": 3.0,
    "footway": 1.8, "path": 1.5, "cycleway": 2.0, "steps": 1.8,
}


def telecharger(url, cache, nom, donnees=None):
    chemin = os.path.join(cache, nom)
    if not os.path.exists(chemin):
        entetes = {"User-Agent": AGENT}
        if donnees is not None:
            entetes["Content-Type"] = "application/json"
        req = urllib.request.Request(url, data=donnees, headers=entetes)
        for essai in range(5):
            try:
                with urllib.request.urlopen(req, timeout=180) as r:
                    contenu = r.read()
                break
            except (urllib.error.URLError, ConnectionError):
                if essai == 4:
                    raise
                time.sleep(2 ** (essai + 1))
        with open(chemin, "wb") as f:
            f.write(contenu)
    with open(chemin, "rb") as f:
        return f.read()


class Projection:
    def __init__(self, origine):
        self.lon0, self.lat0 = origine
        self.kx = 111320.0 * math.cos(math.radians(self.lat0))
        self.ky = 110574.0

    def metres(self, lon, lat):
        return ((lon - self.lon0) * self.kx, -(lat - self.lat0) * self.ky)

    def lonlat(self, x, z):
        return (self.lon0 + x / self.kx, self.lat0 - z / self.ky)


def decouper(poly, cadre):
    """Sutherland-Hodgman : le polygone coupé au rectangle du cadre."""
    x0, z0, x1, z1 = cadre
    bords = [
        (lambda p: p[0] >= x0, lambda a, b: (x0, a[1] + (b[1] - a[1]) * (x0 - a[0]) / (b[0] - a[0]))),
        (lambda p: p[0] <= x1, lambda a, b: (x1, a[1] + (b[1] - a[1]) * (x1 - a[0]) / (b[0] - a[0]))),
        (lambda p: p[1] >= z0, lambda a, b: (a[0] + (b[0] - a[0]) * (z0 - a[1]) / (b[1] - a[1]), z0)),
        (lambda p: p[1] <= z1, lambda a, b: (a[0] + (b[0] - a[0]) * (z1 - a[1]) / (b[1] - a[1]), z1)),
    ]
    out = list(poly)
    for dedans, croise in bords:
        if not out:
            break
        entree, out = out, []
        for i, b in enumerate(entree):
            a = entree[i - 1]
            if dedans(b):
                if not dedans(a):
                    out.append(croise(a, b))
                out.append(b)
            elif dedans(a):
                out.append(croise(a, b))
    return out


def couper_ligne(pts, cadre):
    """Les morceaux d'une ligne qui restent dans le cadre (un point dehors coupe la ligne)."""
    x0, z0, x1, z1 = cadre
    morceaux, cur = [], []
    for p in pts:
        if x0 <= p[0] <= x1 and z0 <= p[1] <= z1:
            cur.append(p)
        else:
            if len(cur) >= 2:
                morceaux.append(cur)
            cur = []
    if len(cur) >= 2:
        morceaux.append(cur)
    return morceaux


def simplifier(poly, tol=0.25):
    """Retire les points presque alignés (à moins de tol mètres de la ligne de leurs voisins)."""
    pts = list(poly)
    change = True
    while change and len(pts) > 3:
        change = False
        for i in range(len(pts)):
            a, b, c = pts[i - 1], pts[i], pts[(i + 1) % len(pts)]
            dx, dz = c[0] - a[0], c[1] - a[1]
            n = math.hypot(dx, dz)
            d = abs((b[0] - a[0]) * dz - (b[1] - a[1]) * dx) / n if n > 1e-6 else math.hypot(b[0] - a[0], b[1] - a[1])
            if d < tol:
                del pts[i]
                change = True
                break
    return pts


def aire(poly):
    return 0.5 * sum(poly[i - 1][0] * poly[i][1] - poly[i][0] * poly[i - 1][1] for i in range(len(poly)))


def centre(poly):
    a = aire(poly)
    if abs(a) < 1e-6:
        return (sum(p[0] for p in poly) / len(poly), sum(p[1] for p in poly) / len(poly))
    cx = cz = 0.0
    for i in range(len(poly)):
        x0, z0 = poly[i - 1]
        x1, z1 = poly[i]
        k = x0 * z1 - x1 * z0
        cx += (x0 + x1) * k
        cz += (z0 + z1) * k
    return (cx / (6 * a), cz / (6 * a))


def dedans(p, poly):
    c = False
    for i in range(len(poly)):
        (x0, z0), (x1, z1) = poly[i - 1], poly[i]
        if (z0 > p[1]) != (z1 > p[1]) and p[0] < x0 + (p[1] - z0) * (x1 - x0) / (z1 - z0):
            c = not c
    return c


def rectangle(poly):
    """Le plus petit rectangle orienté qui contient l'emprise : (centre, longueur, largeur, angle
    du long côté, remplissage). Le remplissage (aire / aire du rectangle) dit si c'est une maison
    rectangulaire, qui recevra un vrai toit."""
    best = None
    for i in range(len(poly)):
        (ax, az), (bx, bz) = poly[i - 1], poly[i]
        ang = math.atan2(bz - az, bx - ax)
        c, s = math.cos(ang), math.sin(ang)
        us = [p[0] * c + p[1] * s for p in poly]
        vs = [-p[0] * s + p[1] * c for p in poly]
        a = (max(us) - min(us)) * (max(vs) - min(vs))
        if best is None or a < best[0]:
            best = (a, ang, min(us), max(us), min(vs), max(vs))
    a, ang, u0, u1, v0, v1 = best
    c, s = math.cos(ang), math.sin(ang)
    uc, vc = (u0 + u1) / 2, (v0 + v1) / 2
    cx, cz = uc * c - vc * s, uc * s + vc * c
    lu, lv = u1 - u0, v1 - v0
    if lv > lu:
        lu, lv, ang = lv, lu, ang + math.pi / 2
    return (cx, cz), lu, lv, ang, abs(aire(poly)) / a if a > 0 else 0


class Relief:
    def __init__(self, cadre, pas, alt):
        self.x0, self.z0 = cadre[0], cadre[1]
        self.pas = pas
        self.nx = int(round((cadre[2] - cadre[0]) / pas)) + 1
        self.nz = int(round((cadre[3] - cadre[1]) / pas)) + 1
        self.alt = alt

    def a(self, x, z):
        fx = min(max((x - self.x0) / self.pas, 0), self.nx - 1.001)
        fz = min(max((z - self.z0) / self.pas, 0), self.nz - 1.001)
        ix, iz = int(fx), int(fz)
        tx, tz = fx - ix, fz - iz
        h = self.alt
        n = self.nx
        return (h[iz * n + ix] * (1 - tx) * (1 - tz) + h[iz * n + ix + 1] * tx * (1 - tz)
                + h[(iz + 1) * n + ix] * (1 - tx) * tz + h[(iz + 1) * n + ix + 1] * tx * tz)


def relief(cfg, proj, cache):
    x0, z0, x1, z1 = cfg["cadre"]
    nx = int(round((x1 - x0) / PAS_RELIEF)) + 1
    nz = int(round((z1 - z0) / PAS_RELIEF)) + 1
    points = [proj.lonlat(x0 + i * PAS_RELIEF, z0 + j * PAS_RELIEF) for j in range(nz) for i in range(nx)]
    alt = []
    lot = 400
    for k in range(0, len(points), lot):
        part = points[k:k + lot]
        corps = json.dumps({
            "lon": "|".join("%.6f" % p[0] for p in part),
            "lat": "|".join("%.6f" % p[1] for p in part),
            "resource": "ign_rge_alti_wld", "zonly": "true",
        }).encode()
        r = telecharger("https://data.geopf.fr/altimetrie/1.0/calcul/alti/rest/elevation.json",
                        cache, "relief_%d_%d_%05d.json" % (nx, nz, k), corps)
        alt += json.loads(r)["elevations"]
    # Les rares trous du service (-99999) prennent la valeur d'un voisin.
    for i, h in enumerate(alt):
        if h < -1000:
            alt[i] = alt[i - 1] if i > 0 else 0.0
    return Relief(cfg["cadre"], PAS_RELIEF, alt)


def lire_osm(xml):
    t = ET.fromstring(xml)
    noeuds = {n.get("id"): (float(n.get("lon")), float(n.get("lat"))) for n in t.iter("node")}
    tags_n = {n.get("id"): {x.get("k"): x.get("v") for x in n.findall("tag")} for n in t.iter("node")}
    chemins = {}
    for w in t.iter("way"):
        chemins[w.get("id")] = ([x.get("ref") for x in w.findall("nd")], {x.get("k"): x.get("v") for x in w.findall("tag")})
    relations = []
    for r in t.iter("relation"):
        relations.append(([(m.get("type"), m.get("ref"), m.get("role")) for m in r.findall("member")],
                          {x.get("k"): x.get("v") for x in r.findall("tag")}))
    return noeuds, tags_n, chemins, relations


def main():
    if len(sys.argv) < 2 or sys.argv[1].startswith("-"):
        print(__doc__)
        sys.exit(2)
    ident = sys.argv[1]
    cfg = reglages(ident, sys.argv[2:])
    cache = cfg["cache"]
    print("%s (%s) : centre %.5f, %.5f ; cadre %s m ; %d lieux remarquables" % (
        cfg["nom"], cfg["insee"], cfg["origine"][0], cfg["origine"][1], "/".join("%g" % x for x in cfg["cadre"]), len(cfg["remarquables"])))
    sortie = os.path.join(RACINE, cfg["dossier"])
    proj = Projection(cfg["origine"])
    cadre = cfg["cadre"]
    marge = 120.0
    lon_o, lat_n = proj.lonlat(cadre[0] - marge, cadre[1] - marge)
    lon_e, lat_s = proj.lonlat(cadre[2] + marge, cadre[3] + marge)
    bbox = "%.5f,%.5f,%.5f,%.5f" % (lon_o, lat_s, lon_e, lat_n)

    # --- Les données -------------------------------------------------------------------------
    osm = telecharger("https://api.openstreetmap.org/api/0.6/map?bbox=" + bbox, cache, "osm.xml")
    noeuds, tags_n, chemins, relations = lire_osm(osm)
    # L'eau en multipolygone (la rivière) : sa relation entière, pour avoir ses rives.
    eau_rel = []
    for membres, tg in relations:
        if tg.get("natural") == "water" and tg.get("type") == "multipolygon":
            eau_rel.append((membres, tg))
    wfs = ("https://data.geopf.fr/wfs/ows?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetFeature"
           "&TYPENAMES=BDTOPO_V3:batiment&OUTPUTFORMAT=application/json&SRSNAME=EPSG:4326&COUNT=10000"
           "&BBOX=%.5f,%.5f,%.5f,%.5f,urn:ogc:def:crs:EPSG::4326" % (lat_s, lon_o, lat_n, lon_e))
    bati = json.loads(telecharger(wfs, cache, "bdtopo_batiment.json"))["features"]
    rel = relief(cfg, proj, cache)
    alt0 = math.floor(min(rel.alt))

    def y(alt):
        return round((alt - alt0) / UNITE, 3)

    def u(v):
        return round(v / UNITE, 2)

    def pt(p):
        return [u(p[0]), u(p[1])]

    def ligne(refs):
        return [proj.metres(*noeuds[r]) for r in refs if r in noeuds]

    # --- Les lieux remarquables --------------------------------------------------------------
    rem = []
    for rid, nom, genre, objet, absorbe in cfg["remarquables"]:
        typ, ref = objet.split("/")
        if typ == "lonlat":
            # Un lieu sans objet OSM à lui : désigné par son point, d'après l'adresse.
            lon, lat = (float(v) for v in ref.split(","))
            p = proj.metres(lon, lat)
            forme = None
        elif typ == "node":
            if ref not in noeuds:
                print("absent d'OSM :", objet)
                continue
            p = proj.metres(*noeuds[ref])
            forme = None
        else:
            if ref not in chemins:
                print("absent d'OSM :", objet)
                continue
            pts = ligne(chemins[ref][0])
            forme = pts
            p = centre(pts[:-1]) if pts[0] == pts[-1] else ((pts[0][0] + pts[-1][0]) / 2, (pts[0][1] + pts[-1][1]) / 2)
        if not (cadre[0] < p[0] < cadre[2] and cadre[1] < p[1] < cadre[3]):
            print("hors du cadre :", nom)
            continue
        rem.append({"id": rid, "nom": nom, "genre": genre, "osm": objet, "p": p, "forme": forme, "batiment": None,
                    "absorbe": absorbe})

    # --- Les bâtiments (BD TOPO) -------------------------------------------------------------
    batiments = []
    for f in bati:
        g = f["geometry"]
        pr = f["properties"]
        if pr.get("etat_de_l_objet") not in (None, "En service"):
            continue
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in polys:
            anneau = [proj.metres(c[0], c[1]) for c in poly[0]]
            if anneau[0] == anneau[-1]:
                anneau = anneau[:-1]
            if len(anneau) < 3:
                continue
            c = centre(anneau)
            if not (cadre[0] + 3 <= c[0] <= cadre[2] - 3 and cadre[1] + 3 <= c[1] <= cadre[3] - 3):
                continue
            anneau = simplifier(anneau)
            if aire(anneau) < 0:
                anneau.reverse()  # sens trigonométrique en (x, z) : la scène s'en sert pour les murs
            surface = abs(aire(anneau))
            if surface < 4:
                continue
            sol_min = pr.get("altitude_minimale_sol")
            terrain = min(rel.a(p[0], p[1]) for p in anneau)
            sol = terrain if sol_min is None else min(sol_min, terrain)
            haut = pr.get("hauteur")
            if not haut:
                etages = pr.get("nombre_d_etages") or (1 if surface < 40 else 2)
                haut = 2.6 + 2.8 * etages if surface >= 40 else 2.6
            faitage = pr.get("altitude_maximale_toit")
            gouttiere = pr.get("altitude_minimale_toit")
            pente = (faitage - gouttiere) if (faitage and gouttiere) else (0.0 if surface < 15 else 2.5)
            pente = max(0.0, min(pente, 6.0))
            mat = (pr.get("materiaux_de_la_toiture") or "")
            toit = "ardoise" if "2" in mat else ("zinc" if "3" in mat else ("plat" if "4" in mat else "tuile"))
            murs = pr.get("materiaux_des_murs") or ""
            mur = "pierre" if "1" in murs[:1] else ("brique" if murs[:1] == "4" else ("bois" if murs[:1] == "6" else "enduit"))
            usage = pr.get("usage_1") or ""
            b = {
                "p": [pt(q) for q in anneau],
                "sol": y(sol - 0.3),
                "h": u(haut + 0.3),
                "pente": u(pente),
                "toit": toit,
                "mur": mur,
            }
            # Le rectangle de la maison : son centre, son grand et son petit côté, l'angle du grand
            # côté, et le remplissage (1 pour une maison rectangulaire, moins pour un L ou un U).
            # La scène en fait une maison du Poitou quand il est assez plein. Le toit : à deux pans
            # le long du grand côté, à quatre pans si la maison est presque carrée.
            centre_m, lu, lv, ang, rempli = rectangle(anneau)
            b["rect"] = [u(centre_m[0]), u(centre_m[1]), u(lu), u(lv), round(ang, 4)]
            b["rempli"] = round(rempli, 2)
            b["pans"] = 4 if lu < lv * 1.35 else 2
            b["_rect_m"] = (centre_m, lu, lv, ang)
            if usage == "Annexe":
                b["annexe"] = True
            b["_m"] = anneau
            b["_c"] = c
            batiments.append(b)
    # Le bâtiment de chaque lieu remarquable : celui qui contient son point, ou le plus proche.
    for r in rem:
        best, dbest = None, 1e9
        for i, b in enumerate(batiments):
            if dedans(r["p"], b["_m"]):
                best, dbest = i, 0
                break
            d = math.hypot(b["_c"][0] - r["p"][0], b["_c"][1] - r["p"][1])
            if d < dbest:
                best, dbest = i, d
        if r["genre"] != "ouvrage" and r["id"] not in ("monument_morts", "croix", "fontaine", "camping") and dbest < 12:
            batiments[best]["r"] = r["id"]
            r["batiment"] = best

    # --- Les rues, les ponts -----------------------------------------------------------------
    routes = []
    for wid, (refs, tg) in chemins.items():
        hw = tg.get("highway")
        if hw not in LARGEURS or tg.get("area") == "yes":
            continue
        for morceau in couper_ligne(ligne(refs), (cadre[0] - 1, cadre[1] - 1, cadre[2] + 1, cadre[3] + 1)):
            r = {"p": [pt(q) for q in morceau], "l": u(LARGEURS[hw]), "k": hw}
            if tg.get("name"):
                r["nom"] = tg["name"]
            if tg.get("bridge") == "yes":
                r["pont"] = True
                r["y"] = [y(rel.a(*morceau[0]) + 0.2), y(rel.a(*morceau[-1]) + 0.2)]
                r["osm"] = "way/" + wid
            if tg.get("tunnel") or tg.get("layer", "0").startswith("-"):
                continue
            routes.append(r)

    # La façade de chaque maison : celui des deux longs côtés qui est le plus près d'une rue
    # (face = +1 ou -1, le sens de v dans le repère du rectangle), et la distance à cette rue.
    segments = []
    for r in routes:
        if r["k"] in ("footway", "path", "steps", "track") or r.get("pont"):
            continue
        pts_m = [(q[0] * UNITE, q[1] * UNITE) for q in r["p"]]
        segments += list(zip(pts_m, pts_m[1:]))

    def dist_rue(p):
        best = 1e9
        for a, b2 in segments:
            if min(a[0], b2[0]) - best > p[0] or max(a[0], b2[0]) + best < p[0] or min(a[1], b2[1]) - best > p[1] or max(a[1], b2[1]) + best < p[1]:
                continue
            dx, dz = b2[0] - a[0], b2[1] - a[1]
            n2 = dx * dx + dz * dz
            t = 0 if n2 == 0 else max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / n2))
            best = min(best, math.hypot(a[0] + dx * t - p[0], a[1] + dz * t - p[1]))
        return best

    for b in batiments:
        (cx, cz), lu, lv, ang = b["_rect_m"]
        vx, vz = -math.sin(ang), math.cos(ang)
        d_plus = dist_rue((cx + vx * lv / 2, cz + vz * lv / 2))
        d_moins = dist_rue((cx - vx * lv / 2, cz - vz * lv / 2))
        b["face"] = 1 if d_plus <= d_moins else -1
        b["rue"] = u(min(d_plus, d_moins))
        del b["_rect_m"]

    # --- L'eau ---------------------------------------------------------------------------------
    eau, ruisseaux = [], []
    for membres, tg in eau_rel:
        for typ, ref, role in membres:
            if typ != "way" or role != "outer" or ref not in chemins:
                continue
            pts = ligne(chemins[ref][0])
            if len(pts) < 4 or pts[0] != pts[-1]:
                continue
            coupe = decouper(simplifier(pts[:-1], 0.5), cadre)
            if len(coupe) >= 3:
                eau.append({"p": [pt(q) for q in coupe], "nom": tg.get("name", cfg["riviere"])})
    for wid, (refs, tg) in chemins.items():
        if tg.get("natural") == "water" and "building" not in tg:
            pts = ligne(refs)
            if len(pts) >= 4 and pts[0] == pts[-1]:
                coupe = decouper(simplifier(pts[:-1], 0.3), cadre)
                if len(coupe) >= 3:
                    eau.append({"p": [pt(q) for q in coupe]})
        elif tg.get("waterway") in ("stream", "ditch", "canal", "drain") and not tg.get("layer", "0").startswith("-"):
            for morceau in couper_ligne(ligne(refs), cadre):
                ruisseaux.append({"p": [pt(q) for q in morceau], "l": u(1.6 if tg["waterway"] == "stream" else 1.0)})
    niveau = None
    if eau:
        # Le relief mesuré sur la rivière est sa surface : on la creuse d'un mètre et demi sous un
        # plan d'eau plat, posé au niveau médian mesuré sur la rivière.
        grand = max(eau, key=lambda e: abs(aire(e["p"])))
        lit = [(q[0] * UNITE, q[1] * UNITE) for q in grand["p"]]
        dans_lit = [k for k in range(len(rel.alt))
                    if dedans((cadre[0] + (k % rel.nx) * PAS_RELIEF, cadre[1] + (k // rel.nx) * PAS_RELIEF), lit)]
        surface = sorted(rel.alt[k] for k in dans_lit)[len(dans_lit) // 2]
        for k in dans_lit:
            rel.alt[k] = min(rel.alt[k], surface - 1.5)
        niveau = y(surface + 0.1)

    # --- Le sol : prés, bois, places, jardins --------------------------------------------------
    couvert = {"forest": "bois", "wood": "bois", "meadow": "pre", "grass": "pre", "farmland": "champ",
               "cemetery": "cimetiere", "park": "parc", "garden": "jardin", "pitch": "terrain",
               "residential": "habite", "industrial": "cour", "allotments": "jardin", "orchard": "verger",
               "parking": "place", "pedestrian": "place", "marketplace": "place", "swimming_pool": "piscine",
               "playground": "parc", "basin": "piscine", "scrub": "bois"}
    zones = []
    for wid, (refs, tg) in chemins.items():
        genre = None
        for cle in ("landuse", "natural", "leisure", "amenity", "highway"):
            v = tg.get(cle)
            if v in couvert and not (cle == "highway" and tg.get("area") != "yes"):
                genre = couvert[v]
                break
        if genre is None and tg.get("place") == "square":
            genre = "place"
        if genre is None:
            continue
        pts = ligne(refs)
        if len(pts) < 4 or pts[0] != pts[-1]:
            continue
        coupe = decouper(pts[:-1], cadre)
        if len(coupe) >= 3:
            z = {"p": coupe, "k": genre}
            if tg.get("name"):
                z["nom"] = tg["name"]
            zones.append(z)
    ordre = ["habite", "champ", "pre", "verger", "cour", "bois", "parc", "jardin", "cimetiere", "terrain", "place", "piscine"]
    zones.sort(key=lambda z: ordre.index(z["k"]))

    arbres = []
    for wid, (refs, tg) in chemins.items():
        if tg.get("natural") == "tree_row":
            for morceau in couper_ligne(ligne(refs), cadre):
                for a, b in zip(morceau, morceau[1:]):
                    n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 9))
                    for k in range(n):
                        t = k / n
                        arbres.append(pt((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)))
    for nid, tg in tags_n.items():
        if tg.get("natural") == "tree" and nid in noeuds:
            p = proj.metres(*noeuds[nid])
            if cadre[0] < p[0] < cadre[2] and cadre[1] < p[1] < cadre[3]:
                arbres.append(pt(p))

    # --- sol.png : un pixel par mètre ----------------------------------------------------------
    couleurs = {
        "habite": (122, 146, 82), "champ": (171, 160, 98), "pre": (128, 160, 80), "verger": (112, 146, 72),
        "cour": (150, 146, 132), "bois": (66, 98, 52), "parc": (104, 148, 74), "jardin": (98, 140, 70),
        "cimetiere": (132, 138, 116), "terrain": (110, 156, 84), "place": (196, 186, 164), "piscine": (96, 160, 190),
    }
    W, H = int(cadre[2] - cadre[0]), int(cadre[3] - cadre[1])
    img = Image.new("RGB", (W, H), (134, 156, 86))
    d = ImageDraw.Draw(img)

    def px(p):
        return (p[0] - cadre[0], p[1] - cadre[1])

    # Un peu de grain : des parcelles plus ou moins vertes, comme vues d'avion.
    bruit = Image.effect_noise((W // 8, H // 8), 24).resize((W, H), Image.BICUBIC)
    for z in zones:
        d.polygon([px(q) for q in z["p"]], fill=couleurs[z["k"]])
    for e in eau:
        d.polygon([px((q[0] * UNITE, q[1] * UNITE)) for q in e["p"]], fill=(88, 112, 92))
    for r in routes:
        if r["k"] in ("track", "path", "footway"):
            d.line([px((q[0] * UNITE, q[1] * UNITE)) for q in r["p"]], fill=(170, 156, 120), width=max(1, int(r["l"] * UNITE)))
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    img = Image.blend(img, Image.merge("RGB", [bruit] * 3), 0.06)
    img.save(os.path.join(sortie, "sol.png"), optimize=True)

    # --- Les arbres des bois et des parcs : semés régulièrement, un peu au hasard ------------------
    import random
    alea = random.Random(86015)
    for z in zones:
        if z["k"] not in ("bois", "parc", "verger", "cimetiere"):
            continue
        dens = {"bois": 70.0, "parc": 260.0, "verger": 110.0, "cimetiere": 400.0}[z["k"]]
        xs, zs = [q[0] for q in z["p"]], [q[1] for q in z["p"]]
        n = int(abs(aire(z["p"])) / dens)
        for _ in range(min(n, 900)):
            p = (alea.uniform(min(xs), max(xs)), alea.uniform(min(zs), max(zs)))
            if dedans(p, z["p"]) and not any(dedans(p, b["_m"]) for b in batiments if abs(b["_c"][0] - p[0]) < 30 and abs(b["_c"][1] - p[1]) < 30):
                arbres.append(pt(p))

    # Les arbres des jardins : un pour 450 m² de zone habitée, loin des maisons et des rues.
    segs = [(a, b, r["l"] * UNITE / 2 + 2.5) for r in routes for a, b in zip([(q[0] * UNITE, q[1] * UNITE) for q in r["p"]], [(q[0] * UNITE, q[1] * UNITE) for q in r["p"]][1:])]

    def pres_route(p):
        for a, b, m in segs:
            if min(a[0], b[0]) - m > p[0] or max(a[0], b[0]) + m < p[0] or min(a[1], b[1]) - m > p[1] or max(a[1], b[1]) + m < p[1]:
                continue
            dx, dz = b[0] - a[0], b[1] - a[1]
            n2 = dx * dx + dz * dz
            t = 0 if n2 == 0 else max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / n2))
            if math.hypot(a[0] + dx * t - p[0], a[1] + dz * t - p[1]) < m:
                return True
        return False

    for z in zones:
        if z["k"] not in ("habite", "jardin"):
            continue
        xs, zs = [q[0] for q in z["p"]], [q[1] for q in z["p"]]
        for _ in range(min(int(abs(aire(z["p"])) / 450.0), 1500)):
            p = (alea.uniform(min(xs), max(xs)), alea.uniform(min(zs), max(zs)))
            if not dedans(p, z["p"]) or pres_route(p) or any(dedans(p, e) for e in [[(q[0] * UNITE, q[1] * UNITE) for q in w["p"]] for w in eau]):
                continue
            if any(math.hypot(b["_c"][0] - p[0], b["_c"][1] - p[1]) < 30 and (dedans(p, b["_m"]) or min(math.hypot(q[0] - p[0], q[1] - p[1]) for q in b["_m"]) < 4) for b in batiments):
                continue
            arbres.append(pt(p))

    # --- bourg.json ----------------------------------------------------------------------------
    for b in batiments:
        del b["_m"], b["_c"]
    remarquables = []
    for r in rem:
        o = {"id": r["id"], "nom": r["nom"], "genre": r["genre"], "osm": r["osm"], "x": u(r["p"][0]), "z": u(r["p"][1]),
             "y": y(rel.a(*r["p"]))}
        if r["batiment"] is not None:
            o["batiment"] = r["batiment"]
        if r.get("absorbe"):
            # Les bâtiments que la silhouette du lieu couvre déjà : la scène ne les dessine pas à part.
            o["absorbe"] = [[round(float(q[0]), 2), round(float(q[1]), 2)] for q in r["absorbe"]]
        remarquables.append(o)
    places = [{"nom": z["nom"], "x": u(centre(z["p"])[0]), "z": u(centre(z["p"])[1])} for z in zones if z["k"] == "place" and z.get("nom", "").startswith("Place")]
    # Les sols revêtus que la scène drape en relief : les places et parkings (enrobé), les cours (gravier).
    sols = []
    for z in zones:
        if z["k"] in ("place", "cour"):
            o = {"k": z["k"], "p": [pt(q) for q in z["p"]]}
            if z.get("nom"):
                o["nom"] = z["nom"]
            sols.append(o)
    data = {
        "format": 1,
        "commune": ident,
        "sources": "© les contributeurs d'OpenStreetMap (ODbL) ; IGN, BD TOPO et RGE ALTI (Licence Ouverte 2.0)",
        "unite_m": UNITE,
        "origine": list(cfg["origine"]),
        "altitude_zero": alt0,
        "cadre": [u(c) for c in cadre],
        "relief": {"x0": u(cadre[0]), "z0": u(cadre[1]), "pas": u(PAS_RELIEF), "nx": rel.nx, "nz": rel.nz,
                   "h": [y(a) for a in rel.alt]},
        "niveau_eau": niveau,
        "eau": eau,
        "ruisseaux": ruisseaux,
        "routes": routes,
        "batiments": batiments,
        "arbres": arbres,
        "places": places,
        "sols": sols,
        "remarquables": remarquables,
    }
    with open(os.path.join(sortie, "bourg.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    plan(data, os.path.join(RACINE, "build", "plan_%s.png" % ident))
    print("%d bâtiments, %d voies, %d plans d'eau, %d arbres, %d lieux remarquables ; relief %d × %d, de %.0f à %.0f m"
          % (len(batiments), len(routes), len(eau), len(arbres), len(remarquables), rel.nx, rel.nz, min(rel.alt), max(rel.alt)))


def plan(data, chemin):
    """Le plan vu de dessus, à comparer avec la carte d'OpenStreetMap."""
    x0, z0, x1, z1 = data["cadre"]
    s = 4.0
    img = Image.new("RGB", (int((x1 - x0) * s), int((z1 - z0) * s)), (236, 232, 220))
    d = ImageDraw.Draw(img)

    def px(q):
        return ((q[0] - x0) * s, (q[1] - z0) * s)

    for e in data["eau"]:
        d.polygon([px(q) for q in e["p"]], fill=(170, 205, 230))
    for r in data["ruisseaux"]:
        d.line([px(q) for q in r["p"]], fill=(120, 170, 220), width=2)
    for r in data["routes"]:
        d.line([px(q) for q in r["p"]], fill=(255, 255, 255) if r["k"] not in ("track", "path", "footway") else (200, 180, 150),
               width=max(1, int(r["l"] * s)))
    for b in data["batiments"]:
        d.polygon([px(q) for q in b["p"]], fill=(200, 120, 90) if "r" in b else (150, 140, 130))
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    img.save(chemin)


if __name__ == "__main__":
    main()
