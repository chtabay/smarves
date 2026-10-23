#!/usr/bin/env python3
"""Construit le SDK des communes : un projet Godot autonome où un développeur construit, teste et
emballe sa commune sans accès au dépôt de Smarves.

Le SDK contient le socle en clair (scripts/socle/, les jeux, le stade, la salle de jeu, les façades,
les figurants, l'habitant et sa caméra), les modèles et les sons libres qu'ils utilisent, le kit de
départ, les outils (test_commune, emballer_commune, bourg_reel, le serveur MCP) et docs/COMMUNE.md.
Il ne contient pas le village de Smarves : ni sa place, ni son casino, ni ses intérieurs, ni ses
quartiers. Ce qui reste est trouvé en suivant les liens depuis les points d'entrée (les autoloads du
projet et ENTREES ci-dessous) ; le village s'arrête aux fichiers de COUPE, remplacés par des bouchons
(BOUCHONS) quand le socle les nomme. Décision de Guillaume du 18 octobre 2026 : « socle lisible ».

Usage : python3 tools/sdk/construire_sdk.py [--sortie=build/] [--liste]
  écrit build/smarves-sdk-<date>-<commit>.zip ;
  --liste affiche ce qui part, sans rien écrire.
La vérification est tools/sdk/test_sdk.sh : elle déballe le zip ailleurs et y passe les tests.
"""

import json
import re
import subprocess
import sys
import zipfile
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
ICI = Path(__file__).resolve().parent

## Ce dont une commune a besoin, en plus des autoloads du projet.
ENTREES = [
    "scripts/socle/atelier.gd", "scripts/socle/atelier.json", "scripts/socle/salle_jeu.gd", "scenes/salle_jeu.tscn",
    "scripts/socle/tables.gd", "scripts/socle/partage.gd",
    # Les quartiers enregistrés d'avance (socle 1.21) : la classe, l'outil qui les enregistre, son test.
    "scripts/socle/quartiers.gd", "tools/enregistrer_quartiers.gd", "tools/test_quartiers.gd",
    # La bibliothèque commune (socle 1.13) : le catalogue, ses briques, les contrats d'ancres.
    "bibliotheque/bibliotheque.json", "scripts/socle/bibliotheque.gd", "scripts/socle/ancres.gd",
    "tools/test_bibliotheque.gd", "tools/planche_facadier.gd", "tools/capture_decor.gd", "tools/capture_interieur_modele.gd",
    # Les règles des paquets (socle 1.15) : l'emballeur les applique, leur test les vérifie.
    "tools/regles_paquet.gd", "tools/test_regles_paquet.gd",
    # Le budget par lieu (socle 1.16) : l'emballeur mesure, budget_lieu.gd mesure un paquet sans l'emballer.
    "tools/budget_lieu.gd",
    "scripts/socle/etude.gd", "scenes/etude.tscn",
    # L'intérieur d'une maison achetée chez le notaire d'une commune (Biens.enter), à essayer dans le SDK.
    "scripts/logement.gd", "scenes/logement.tscn",
    "scripts/socle/commerce.gd", "scripts/socle/articles.gd", "scenes/commerce.tscn",
    "scenes/stade.tscn", "communes/vienne.json", "communes/france.json",
    "tools/kit/commune.gd", "tools/kit/commune.tscn", "tools/kit/commune.json",
    "tools/test_commune.gd", "tools/parcours_commune.gd", "tools/emballer_commune.gd", "tools/test_atelier.gd", "tools/test_salle_jeu.gd",
    "tools/fixtures/salle_jeu/commune.json", "tools/fixtures/salle_jeu/commune.tscn",
    # L'exemple complet : Availles-Limouzine dans sa disposition réelle, tirée de bourg_reel.py.
    "tools/paquet_essai/availles_limouzine/commune.json", "tools/paquet_essai/availles_limouzine/commune.tscn",
    "tools/paquet_essai/availles_limouzine/availles.gd", "tools/paquet_essai/availles_limouzine/remarquables.gd",
    "tools/paquet_essai/availles_limouzine/bourg.json", "tools/paquet_essai/availles_limouzine/bourg_reel.json",
    "tools/paquet_essai/availles_limouzine/sol.png", "tools/test_availles.gd",
]
## Copiés tels quels, sans suivre leurs liens (outils hors Godot, documentation).
TELS_QUELS = [
    "tools/bourg_reel.py", "tools/mcp/kit_communes.py", "tools/mcp/test_kit_communes.py",
    "docs/COMMUNE.md", "docs/CONCEPTION.md", "docs/BIBLIOTHEQUE.md", "docs/LENTEUR.md", "docs/AVATAR.md", "assets/LICENCES.md", "icon.svg", ".editorconfig", ".gitattributes",
    # La méthode de conception (docs/CONCEPTION.md) : sa note d'exemple, ses planches de référence et le
    # modèle de note du kit. docs/.gdignore garde les images hors de l'import de Godot.
    "docs/.gdignore", "docs/exemples/INTENTIONS-isle-jourdain.md", "docs/references/minuit.jpg",
    "docs/references/isle-jourdain.jpg", "tools/kit/INTENTIONS.md",
] + sorted("communes/departements/" + p.name for p in (RACINE / "communes/departements").glob("*.json"))
# (Les communes des autres départements connus, Departements : le jeu les lit par leur code, aucun lien
# ne mène à elles.)
## Les parties de la bible et du cadrage qui valent pour toutes les communes ; COMMUNE.md et CONCEPTION.md y
## renvoient. Le SDK en reçoit un extrait tiré à chaque construction (EXTRAITS), pas les fichiers entiers :
## ce qui est propre à Smarves (ses lieux, ses personnages, son casino, l'ordre du récit) reste au jeu.
## (fichier, sections « ## n. » gardées, sous-sections « ### » écartées dans ces sections, en-tête)
EXTRAITS = [
    ("docs/BIBLE.md", {2, 3, 5, 7, 8, 9}, {"Au village", "Au casino", "Le joueur", "Enseignes"},
     "Ce fichier du SDK est un extrait de la bible du monde de Smarves (`docs/BIBLE.md` du jeu), tiré à chaque "
     "construction du SDK. Il garde ce qui vaut pour toutes les communes : le ton, l'époque, la règle des lieux, "
     "la réserve de noms, l'économie en crédits et le vocabulaire. Ce qui est propre à Smarves (sa géographie, "
     "ses lieux et leurs tenanciers, son casino, ses personnages, l'ordre de son récit) n'y est pas : une "
     "commune garde ces règles communes et invente le reste, ancré dans sa propre géographie réelle."),
    ("docs/SUITE.md", {5, 6}, {"Le football de la Vienne : une pyramide à la Hattrick", "L'ordre pour y arriver"},
     "Ce fichier du SDK est un extrait du cadrage de Smarves (`docs/SUITE.md` du jeu), tiré à chaque "
     "construction du SDK : la carte de la Vienne, les communes greffées et les structures partagées. Les autres "
     "chantiers du jeu n'y sont pas ; le contrat à jour est `COMMUNE.md`."),
]
## Le village de Smarves : ce qui ne part pas. Les liens qui y mènent s'arrêtent là.
COUPE = {
    "scenes/main.tscn", "scenes/title.tscn", "scenes/casino.tscn", "scenes/notaire.tscn", "scenes/couture.tscn",
    "scenes/garage.tscn", "scenes/brocante.tscn", "scenes/bourse.tscn", "scenes/cafe.tscn",
    "scenes/moulin.tscn", "scenes/rabelais.tscn",
    "scripts/main.gd", "scripts/title.gd", "scripts/village/village.gd", "scripts/casino_interior.gd",
    "scripts/casino_exterior.gd", "scripts/outskirts.gd", "scripts/village/bois.gd",
    "scripts/village/passelourdin.gd", "scripts/village/pepites.gd", "scripts/village/charge.gd",
    # Le registre du notaire de Smarves se calcule sur l'agencement du village (NORTH_ROW, BOIS…), absent
    # du bouchon : il ne se compilerait pas, et toute commune qui déclare un notaire en hériterait les
    # erreurs (retour de l'auteur de Chauvigny). Le manifeste d'origine du SDK ne le nomme plus (_origine).
    "scripts/adresses.gd",
}
## Les fichiers coupés que le socle nomme quand même, remplacés par leur bouchon (tools/sdk/bouchons/).
BOUCHONS = {
    "scenes/main.tscn": "lanceur.tscn",
    "scripts/village/village.gd": "village.gd",
}
SUFFIXES = (".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".glb", ".gltf", ".bin", ".png", ".jpg", ".ogg", ".wav", ".mp3",
            ".ttf", ".otf", ".woff", ".woff2", ".json", ".svg")
## Les morceaux de shader (.gdshaderinc) passent avant .gdshader : un #include est un lien comme un autre.
LIEN = re.compile(r"res://[\w/\-. ]+?\.(?:gdshaderinc|gdshader|gd|tscn|tres|glb|gltf|bin|png|jpg|ogg|wav|mp3|ttf|otf|woff2|woff|json|svg)(?!\w)")
DOSSIER = re.compile(r'"(res://[\w/\-.]+/)"')


def _res(chemin):
    return chemin.replace("res://", "")


def _classes():
    out = {}
    for f in RACINE.rglob("*.gd"):
        if ".godot" in f.parts or "build" in f.parts:
            continue
        m = re.search(r"^class_name\s+(\w+)", f.read_text(encoding="utf-8", errors="ignore"), re.M)
        if m:
            out[m.group(1)] = f.relative_to(RACINE).as_posix()
    return out


def _autoloads():
    txt = (RACINE / "project.godot").read_text(encoding="utf-8")
    return [_res(m.group(1)) for m in re.finditer(r'^\w+="\*(res://[^"]+)"', txt, re.M)]


def fermeture():
    """Les fichiers du dépôt atteints depuis les entrées, sans passer par le village. Rend
    (gardés, liens durs) : un lien dur est un preload ou un extends vers un fichier coupé sans bouchon."""
    classes = _classes()
    gardes, durs = set(), []
    pile = list(_autoloads()) + ENTREES
    while pile:
        rel = pile.pop()
        # Le cache de Godot (.godot/) est propre à chaque machine : chargement.gd nomme « res://.godot/ »
        # et la CI a déjà importé le projet quand le SDK se construit.
        if rel in COUPE or rel in gardes or rel.startswith((".godot/", "build/")):
            continue
        f = RACINE / rel
        if not f.is_file():
            continue
        gardes.add(rel)
        imp = Path(str(f) + ".import")
        if f.suffix not in (".gd", ".tscn", ".tres", ".gdshader", ".gdshaderinc", ".json"):
            if imp.is_file():
                # Les .gltf nomment leur .bin et leurs textures dans leur propre fichier, lu plus bas.
                pass
            if f.suffix != ".gltf":
                continue
        t = f.read_text(encoding="utf-8", errors="ignore")
        if f.suffix == ".gltf":
            for m in re.finditer(r'"uri"\s*:\s*"([^"]+)"', t):
                pile.append((f.parent / m.group(1)).relative_to(RACINE).as_posix())
            continue
        for m in LIEN.finditer(t):
            pile.append(_res(m.group(0)))
        # Une brique de matières nomme ses images sans chemin, à côté de son matieres.json.
        if f.name == "matieres.json":
            for m in re.finditer(r'"image"\s*:\s*"([^"/]+)"', t):
                pile.append((f.parent / m.group(1)).relative_to(RACINE).as_posix())
        for m in DOSSIER.finditer(t):
            d = RACINE / _res(m.group(1))
            if d.is_dir():
                for g in d.rglob("*"):
                    if g.is_file() and g.suffix in SUFFIXES:
                        pile.append(g.relative_to(RACINE).as_posix())
        if f.suffix == ".gd":
            for m in re.finditer(r'(?:preload\s*\(|extends\s+)\s*"(res://[^"]+)"', t):
                cible = _res(m.group(1))
                if cible in COUPE and cible not in BOUCHONS:
                    durs.append((rel, cible))
            for c, cf in classes.items():
                if cf != rel and re.search(r"\b%s\b" % c, t):
                    if cf in COUPE and cf not in BOUCHONS:
                        durs.append((rel, cf))
                    pile.append(cf)
    return gardes, durs


def _extrait(rel, gardees, ecartees, entete):
    """Le titre du document, l'en-tête de l'extrait, puis les sections « ## n. » gardées, sans leurs
    sous-sections écartées. Les sections citées ailleurs gardent leur numéro (« bible, section 8 »)."""
    lignes = (RACINE / rel).read_text(encoding="utf-8").split("\n")
    out = [lignes[0] + " (extrait)", "", entete, ""]
    garder = False
    sous_ecartee = False
    for l in lignes[1:]:
        m = re.match(r"## (\d+)\. ", l)
        if l.startswith("## "):
            garder = bool(m) and int(m.group(1)) in gardees
            sous_ecartee = False
        elif l.startswith("### "):
            sous_ecartee = l[4:].strip() in ecartees
        if garder and not sous_ecartee and not re.match(r"\s*!\[", l):
            out.append(l)
    return "\n".join(out).rstrip() + "\n"


def _version():
    """La version du SDK : la date et le commit du dépôt d'où il sort (« 2026-10-18-335f9a6 »). Le jeu
    n'a pas de numéro de version : il se repère à son commit (scripts/socle/version.gd)."""
    try:
        out = subprocess.run(["git", "log", "-1", "--format=%cs-%h"], cwd=RACINE, capture_output=True, text=True, check=True)
        return out.stdout.strip() or "local"
    except (OSError, subprocess.CalledProcessError):
        return "local"


def _projet():
    """project.godot du SDK : celui du jeu, qui démarre sur le lanceur, sans préréglages d'export."""
    t = (RACINE / "project.godot").read_text(encoding="utf-8")
    t = re.sub(r'run/main_scene="[^"]*"', 'run/main_scene="res://scenes/main.tscn"', t)
    t = t.replace('config/name="Smarves"', 'config/name="Smarves — SDK des communes"')
    # Le module addons/smarves_version estampille les exports du jeu avec son commit : il ne part pas
    # dans le SDK, où une commune s'emballe sans lui ; sa section partirait sans lui et Godot s'en plaindrait.
    t = re.sub(r"\[editor_plugins\]\n+enabled=[^\n]*\n+", "", t)
    return t


def _origine():
    """Le manifeste de Smarves, réduit à ce que le socle lit d'une commune d'origine : son id, sa place
    sur la carte, sa banque, son stade. Ses intérieurs, ses lots et le registre de son notaire ne sont pas
    dans le SDK."""
    m = json.loads((RACINE / "communes/smarves/commune.json").read_text(encoding="utf-8"))
    m["interieurs"] = {"stade": "res://scenes/stade.tscn"}
    m.pop("lots", None)
    # Le registre de Smarves (scripts/adresses.gd) ne part pas : Maître Garnier garde son nom, sans adresses.
    if "notaire" in m:
        m["notaire"].pop("registre", None)
    m["description"] = "Smarves n'est pas dans le SDK : le lanceur tient sa place."
    return json.dumps(m, ensure_ascii=False, indent="\t") + "\n"


def construire(sortie, lister=False):
    gardes, durs = fermeture()
    if durs:
        for d in sorted(set(durs)):
            print("lien dur vers le village : %s -> %s" % d, file=sys.stderr)
        sys.exit("Le socle dépend encore d'un fichier du village sans bouchon (BOUCHONS).")
    fichiers = {}
    for rel in sorted(gardes):
        fichiers[rel] = RACINE / rel
        for compagnon in (rel + ".import", rel + ".uid"):
            if (RACINE / compagnon).is_file():
                fichiers[compagnon] = RACINE / compagnon
    for rel in TELS_QUELS:
        if (RACINE / rel).is_file():
            fichiers[rel] = RACINE / rel
    for cible, bouchon in BOUCHONS.items():
        fichiers[cible] = ICI / "bouchons" / bouchon
    fichiers["scripts/sdk/lanceur.gd"] = ICI / "bouchons" / "lanceur.gd"
    textes = {
        "project.godot": _projet(),
        "communes/smarves/commune.json": _origine(),
        "LISEZMOI.md": (ICI / "LISEZMOI.md").read_text(encoding="utf-8"),
        ".mcp.json": (RACINE / ".mcp.json").read_text(encoding="utf-8"),
        ".gitignore": ".godot/\n/build/\n*.pck\n",
        "sdk.json": json.dumps({"sdk": _version()}) + "\n",
    }
    for rel, gardees, ecartees, entete in EXTRAITS:
        textes[rel] = _extrait(rel, gardees, ecartees, entete)
    for rel in textes:
        fichiers.pop(rel, None)
    intrus = sorted(r for r in fichiers if r.startswith((".godot/", "addons/")))
    if intrus or "res://addons/" in textes["project.godot"]:
        sys.exit("Le SDK ne doit contenir ni cache .godot/ ni module addons/ : %s" % ", ".join(intrus or ["project.godot"]))
    taille = sum(p.stat().st_size for p in fichiers.values()) + sum(len(t.encode()) for t in textes.values())
    code = [r for r in fichiers if r.endswith((".gd", ".tscn"))]
    print("%d fichiers, %.1f Mo, dont %d scripts et scènes" % (len(fichiers) + len(textes), taille / 1048576, len(code)))
    if lister:
        for r in sorted(code):
            print("  " + r)
        return None
    sortie.mkdir(parents=True, exist_ok=True)
    zip_ = sortie / ("smarves-sdk-%s.zip" % _version())
    racine = "smarves-sdk/"
    with zipfile.ZipFile(zip_, "w", zipfile.ZIP_DEFLATED) as z:
        for rel, src in sorted(fichiers.items()):
            z.write(src, racine + rel)
        for rel, t in textes.items():
            z.writestr(racine + rel, t)
    print("SDK écrit : %s (%.1f Mo)" % (zip_, zip_.stat().st_size / 1048576))
    return zip_


if __name__ == "__main__":
    sortie = RACINE / "build"
    for a in sys.argv[1:]:
        if a.startswith("--sortie="):
            sortie = Path(a.split("=", 1)[1]).resolve()
    construire(sortie, "--liste" in sys.argv)
