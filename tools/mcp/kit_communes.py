#!/usr/bin/env python3
"""Le kit des communes en serveur MCP : ce que le Claude d'un développeur peut demander au socle de
Smarves pendant qu'il construit une commune en paquet.

Il lit les mêmes fichiers que le jeu (docs/COMMUNE.md, docs/CONCEPTION.md, scripts/socle/atelier.json, tools/kit/,
scripts/socle/commune.gd) et lance les mêmes outils (tools/test_commune.gd, tools/emballer_commune.gd,
tools/bourg_reel.py) : ses réponses sont celles du jeu, pas une copie qui vieillit à côté.

Lancement : python3 tools/mcp/kit_communes.py, depuis n'importe où ; le dépôt est le dossier deux
crans au-dessus de ce fichier. Claude Code le propose tout seul grâce au .mcp.json à la racine du dépôt.
Godot est cherché dans la variable GODOT, sinon « godot » dans le PATH (la version des workflows, 4.7).

Le protocole : MCP sur l'entrée et la sortie standard, un message JSON-RPC par ligne. Python 3.9 ou
plus, sans aucune dépendance. Le mode d'emploi est dans docs/COMMUNE.md, « Le Claude du développeur ».
"""

import json
import os
import re
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
VERSION = "1.0.0"
PROTOCOLE = "2025-06-18"
TAILLE_MAX = 32 * 1024 * 1024  # le plafond d'un paquet sur le portail

CONSIGNES = """Le kit des communes de Smarves (jeu Godot 4.7, la Vienne). Une commune est un paquet .pck
rangé sous res://communes/<id>/ : un manifeste commune.json, une scène qui expose « player » et
« camera ». Commence par « contrat » pour les règles, « atelier » pour ce que le jeu prête (modèles,
maisons, figurants, meubles, sons, matières : rien à embarquer), « nouvelle_commune » pour partir du
kit, puis « verifier_manifeste », « tester_commune » et « emballer_commune » avant de déposer le paquet
sur le portail des développeurs. Une version par dépôt, toujours plus haute ; 32 Mo au plus.
Avant de construire un lieu, lis « conception » : la méthode (une note d'intentions, trois scènes fortes
jugées à hauteur de joueur, une continuité habitée entre elles, une palette chiffrée, l'animation et la
vie, des passes d'approfondissement, une critique indépendante). Une commune qui passe les tests n'est
pas pour autant réussie : le critère est que le lieu surprenne, pas seulement que rien ne bloque.
Une table de jeu ne se fabrique pas avec les modèles de l'atelier : la structure « salle_jeu » pose les
tables du casino de Smarves, et une salle bâtie à la main les prend par la classe Tables
(scripts/socle/tables.gd, socle 1.10) ; « contrat Les structures », paragraphe « Les tables du casino », donne les appels."""


# --- Lire le dépôt ---------------------------------------------------------------------------------

def _lire(rel):
    return (RACINE / rel).read_text(encoding="utf-8")


def _sections_doc(doc="docs/COMMUNE.md"):
    """Les sections d'un document (docs/COMMUNE.md par défaut), par titre (##, ###), dans l'ordre, avec
    leur niveau (2 ou 3)."""
    out, titre, niveau, lignes = [], None, 0, []
    for ligne in _lire(doc).splitlines():
        m = re.match(r"^(#{2,3}) (.+)$", ligne)
        if m:
            if titre:
                out.append((titre, "\n".join(lignes).strip(), niveau))
            titre, niveau, lignes = m.group(2).strip(), len(m.group(1)), [ligne]
        elif titre:
            lignes.append(ligne)
    if titre:
        out.append((titre, "\n".join(lignes).strip(), niveau))
    return out


def _normal(s):
    s = s.lower().replace("’", "'")
    for a, b in (("é", "e"), ("è", "e"), ("ê", "e"), ("à", "a"), ("ç", "c"), ("ô", "o"), ("`", "")):
        s = s.replace(a, b)
    return s


def _catalogue():
    return json.loads(_lire("scripts/socle/atelier.json"))


def _modeles(famille):
    f = _catalogue()["modeles"].get(famille)
    if not f:
        return []
    dossier = RACINE / f["dossier"].replace("res://", "")
    if not dossier.is_dir():
        return []
    noms = {p.stem for p in dossier.iterdir() if p.suffix in (".glb", ".gltf")}
    return sorted(noms)


def _vienne():
    """Les communes de la Vienne par code INSEE (communes/vienne.json, le référentiel du jeu)."""
    v = json.loads(_lire("communes/vienne.json"))
    return {c["insee"]: c for c in v["communes"]}


def _requis():
    """Les champs obligatoires du manifeste, lus dans scripts/socle/commune.gd (REQUIS)."""
    m = re.search(r"const REQUIS := \[([^\]]*)\]", _lire("scripts/socle/commune.gd"))
    return re.findall(r'"([^"]+)"', m.group(1)) if m else []


def _dossier(id_, dossier=""):
    if dossier:
        p = Path(dossier)
        return p if p.is_absolute() else RACINE / p
    for d in (RACINE / "communes" / id_, RACINE / "tools" / "paquet_essai" / id_):
        if d.is_dir():
            return d
    return RACINE / "communes" / id_


def _res(dossier):
    """Le chemin res:// d'un dossier du dépôt, pour --depuis= des outils Godot."""
    try:
        return "res://" + dossier.resolve().relative_to(RACINE).as_posix() + "/"
    except ValueError:
        raise Erreur("Le dossier %s n'est pas dans le dépôt %s." % (dossier, RACINE))


def _godot():
    g = os.environ.get("GODOT") or shutil.which("godot") or shutil.which("godot4")
    if not g:
        raise Erreur("Godot est introuvable. Installe Godot 4.7 (https://godotengine.org/download) et mets "
                     "« godot » dans le PATH, ou donne son chemin dans la variable GODOT du serveur.")
    return g


def _lancer(cmd, delai=600):
    try:
        r = subprocess.run(cmd, cwd=RACINE, capture_output=True, text=True, timeout=delai)
    except subprocess.TimeoutExpired:
        raise Erreur("« %s » n'a pas fini en %d s." % (" ".join(cmd[:4]), delai))
    sortie = (r.stdout + ("\n" + r.stderr if r.stderr.strip() else "")).strip()
    # Godot répète des avertissements d'import sans intérêt ici : on garde la fin, qui conclut.
    lignes = sortie.splitlines()
    if len(lignes) > 200:
        lignes = ["… (%d lignes plus haut)" % (len(lignes) - 200)] + lignes[-200:]
    return r.returncode, "\n".join(lignes)


class Erreur(Exception):
    pass


# --- Les outils ------------------------------------------------------------------------------------

def contrat(section=""):
    secs = _sections_doc()
    if not section:
        return ("docs/COMMUNE.md, le contrat entre le jeu et une commune. Sections (demande-en une par son "
                "titre) :\n" + "\n".join("- " + t for t, _, _ in secs))
    return _section(secs, section)


def conception(section=""):
    secs = _sections_doc("docs/CONCEPTION.md")
    if not section:
        intro = _lire("docs/CONCEPTION.md").split("\n## ")[0].strip()
        return (intro + "\n\nSections (demande-en une par son titre, ou « tout ») :\n"
                + "\n".join("- " + t for t, _, _ in secs))
    if _normal(section) == "tout":
        return _lire("docs/CONCEPTION.md")
    return _section(secs, section)


def _section(secs, section):
    """Les sections dont le titre contient ce mot ; une section ## vient avec ses ###."""
    cle, pris, dans = _normal(section), [], False
    for t, c, niveau in secs:
        if niveau == 2:
            dans = cle in _normal(t)
            if dans:
                pris.append(c)
        elif dans or cle in _normal(t):
            pris.append(c)
    if not pris:
        raise Erreur("Aucune section ne contient « %s ». Sections : %s" % (section, ", ".join(t for t, _, _ in secs)))
    return "\n\n".join(pris)


def atelier(rubrique="", famille="", cherche=""):
    cat = _catalogue()
    if famille:
        if famille not in cat["modeles"]:
            raise Erreur("Famille inconnue « %s ». Familles : %s" % (famille, ", ".join(cat["modeles"])))
        noms = [n for n in _modeles(famille) if _normal(cherche) in _normal(n)]
        f = cat["modeles"][famille]
        return json.dumps({"famille": famille, "nom": f.get("nom"), "licence": f.get("licence"),
                           "hauteur_conseillee": f.get("hauteur"), "usage": f.get("usage"),
                           "appel": 'Atelier.modele("%s/<nom>", hauteur)' % famille,
                           "modeles": noms}, ensure_ascii=False, indent=1)
    if cherche:
        cle = _normal(cherche)
        out = {f: [n for n in _modeles(f) if cle in _normal(n)] for f in cat["modeles"]}
        out = {f: n for f, n in out.items() if n}
        meubles = [m for m in cat["meubles"]["ids"] if cle in _normal(m)]
        if meubles:
            out["meubles"] = meubles
        personnages = [m for m in cat["personnages"]["roles"] + cat["personnages"]["modeles"] if cle in _normal(m)]
        if personnages:
            out["personnages"] = personnages
        return json.dumps({"cherche": cherche, "trouve": out}, ensure_ascii=False, indent=1)
    if rubrique:
        if rubrique not in cat:
            raise Erreur("Rubrique inconnue « %s ». Rubriques : %s" % (rubrique, ", ".join(k for k in cat if k != "format")))
        val = cat[rubrique]
        if rubrique == "modeles":
            val = {f: dict(v, nombre=len(_modeles(f))) for f, v in val.items()}
        return json.dumps({rubrique: val}, ensure_ascii=False, indent=1)
    resume = {k: v for k, v in cat.items() if k not in ("modeles",)}
    resume["modeles"] = {f: "%d modèles, %s" % (len(_modeles(f)), v.get("usage", "")) for f, v in cat["modeles"].items()}
    return ("L'atelier du socle (scripts/socle/atelier.json, API dans scripts/socle/atelier.gd, classe Atelier). "
            "Tout est déjà dans le jeu : rien à mettre dans le paquet. Les tables de jeu n'y sont pas : ce sont "
            "celles du casino, par la classe Tables (contrat « Les structures », paragraphe « Les tables du casino »).\n" + json.dumps(resume, ensure_ascii=False, indent=1))


def verifier_manifeste(id="", dossier="", texte=""):
    if texte:
        source = "le texte donné"
    else:
        d = _dossier(id, dossier)
        f = d / "commune.json"
        if not f.is_file():
            raise Erreur("Pas de manifeste %s" % f)
        texte, source = f.read_text(encoding="utf-8"), str(f.relative_to(RACINE)) if RACINE in f.parents else str(f)
    try:
        m = json.loads(texte)
    except json.JSONDecodeError as e:
        return "REFUS : %s n'est pas du JSON valide (%s)." % (source, e)
    erreurs, conseils = [], []
    for k in _requis():
        if k not in m:
            erreurs.append("champ obligatoire absent : « %s »" % k)
    if m.get("format") != 1:
        erreurs.append("« format » doit valoir 1")
    i = str(m.get("id", ""))
    if not re.fullmatch(r"[a-z_][a-z0-9_]*", i):
        erreurs.append("« id » doit être en minuscules, chiffres et _ (« la_villedieu_du_clain »)")
    insee = str(m.get("insee", ""))
    if insee not in _vienne():
        erreurs.append("code INSEE inconnu dans la Vienne : « %s »" % insee)
    if i and str(m.get("scene", "")) and not str(m["scene"]).startswith("res://communes/%s/" % i):
        erreurs.append("« scene » doit être sous res://communes/%s/" % i)
    if "__" in texte:
        erreurs.append("il reste des marques du kit (__ID__, __NOM__, __INSEE__) à remplacer")
    if not re.fullmatch(r"\d+\.\d+\.\d+", str(m.get("version", ""))):
        conseils.append("« version » en x.y.z : le portail refuse une version égale ou plus basse que la dernière déposée")
    for k in ("auteur", "licence"):
        if not str(m.get(k, "")).strip():
            conseils.append("« %s » est vide : le portail l'affiche avant le dépôt" % k)
    if not m.get("population"):
        conseils.append("« population » vaut 0")
    if not m.get("sources"):
        conseils.append("« sources » est vide : cite tes données (OpenStreetMap, IGN…)")
    out = ["%s : %s" % (source, "REFUS" if erreurs else "accepté par la vérification rapide")]
    out += ["  ✗ " + e for e in erreurs] + ["  · " + c for c in conseils]
    out.append("La vérification complète (types des champs facultatifs, scène présente, pack greffé) : "
               "tester_commune.")
    return "\n".join(out)


def nom_de_caisse(nom):
    """« La caisse d'Angles-sur-l'Anglin », « La caisse du Vigeant », « La caisse des Ormes » : l'élision
    devant une voyelle et la contraction de l'article. Même règle que le portail (src/lib/communes/kit.ts)."""
    if nom.startswith("Le "):
        return "La caisse du " + nom[3:]
    if nom.startswith("Les "):
        return "La caisse des " + nom[4:]
    return ("La caisse d'" if unicodedata.normalize("NFD", nom[:1])[:1].lower() in "aeiouy" else "La caisse de ") + nom


def nouvelle_commune(insee, id="", nom="", dossier=""):
    ref = _vienne().get(str(insee))
    if not ref:
        raise Erreur("Code INSEE inconnu dans la Vienne : « %s »" % insee)
    nom = nom or ref["nom"]
    if not id:
        id = re.sub(r"[^a-z0-9]+", "_", _normal(nom).replace("œ", "oe")).strip("_")
    if not re.fullmatch(r"[a-z_][a-z0-9_]*", id):
        raise Erreur("« id » doit être en minuscules, chiffres et _ : « %s »" % id)
    d = Path(dossier) if dossier else RACINE / "communes" / id
    d = d if d.is_absolute() else RACINE / d
    if (d / "commune.json").exists():
        raise Erreur("%s existe déjà : je n'écrase pas une commune." % (d / "commune.json"))
    d.mkdir(parents=True, exist_ok=True)
    faits = []
    for nom_f in ("commune.json", "commune.tscn", "commune.gd", "INTENTIONS.md"):
        t = _lire("tools/kit/" + nom_f).replace("La caisse de __NOM__", nom_de_caisse(nom)).replace("__ID__", id).replace("__NOM__", nom).replace("__INSEE__", str(insee))
        if nom_f == "commune.json":
            t = t.replace('"population": 0', '"population": %d' % int(ref.get("population", 0)))
        (d / nom_f).write_text(t, encoding="utf-8")
        faits.append(str((d / nom_f).relative_to(RACINE)) if RACINE in d.parents else str(d / nom_f))
    return ("Commune « %s » (id « %s ») créée depuis le kit :\n%s\nD'abord la note d'intentions (INTENTIONS.md, "
            "outil conception) et les questions au porteur du projet, avant le premier modèle. À remplir dans "
            "commune.json : auteur, description, licence, sources, lieux et banque. Puis tester_commune et "
            "parcourir_commune." % (nom, id, "\n".join("- " + f for f in faits)))


def tester_commune(id="", dossier="", pck=""):
    cmd = [_godot(), "--headless", "--path", str(RACINE), "-s", "tools/test_commune.gd", "--"]
    if pck:
        cmd.append("--pck=" + str(Path(pck).resolve()))
    elif id:
        cmd.append(id)
        if dossier:
            cmd.append("--depuis=" + _res(_dossier(id, dossier)))
        elif not (RACINE / "communes" / id).is_dir():
            cmd.append("--depuis=" + _res(_dossier(id)))
    code, sortie = _lancer(cmd)
    return ("RÉUSSI" if code == 0 else "ÉCHEC (code %d)" % code) + "\n" + sortie


def parcourir_commune(id="", dossier="", pck="", reperes="", rendu=False):
    cmd = [_godot()] + ([] if rendu else ["--headless"]) + ["--path", str(RACINE), "-s", "tools/parcours_commune.gd", "--"]
    if id:
        cmd.append(id)
    if pck:
        cmd.append("--pck=" + str(Path(pck).resolve()))
    elif id:
        if dossier:
            cmd.append("--depuis=" + _res(_dossier(id, dossier)))
        elif not (RACINE / "communes" / id).is_dir():
            cmd.append("--depuis=" + _res(_dossier(id)))
    if reperes:
        cmd.append("--reperes=" + reperes)
    code, sortie = _lancer(cmd)
    return ("RÉUSSI" if code == 0 else "ÉCHEC (code %d)" % code) + "\n" + sortie


def emballer_commune(id, dossier=""):
    cmd = [_godot(), "--headless", "--path", str(RACINE), "-s", "tools/emballer_commune.gd", "--", id]
    if dossier or not (RACINE / "communes" / id).is_dir():
        cmd.append("--depuis=" + _res(_dossier(id, dossier)))
    code, sortie = _lancer(cmd)
    pck = RACINE / "build" / ("%s.pck" % id)
    if code == 0 and pck.is_file():
        taille = pck.stat().st_size
        bilan = "Paquet %s : %.2f Mo%s" % (pck, taille / 1048576,
                                           " — AU-DESSUS des 32 Mo du portail" if taille > TAILLE_MAX else "")
        return "RÉUSSI\n%s\n%s\nÀ déposer sur le portail des développeurs (une version plus haute que la dernière)." % (bilan, sortie)
    return "ÉCHEC (code %d)\n%s" % (code, sortie)


def bourg_reel(id, options=None):
    cmd = [sys.executable, "-I", str(RACINE / "tools" / "bourg_reel.py"), id] + [str(o) for o in (options or [])]
    code, sortie = _lancer(cmd, delai=900)
    return ("RÉUSSI" if code == 0 else "ÉCHEC (code %d)" % code) + "\n" + sortie


_ID = {"type": "string", "description": "l'id de la commune, en minuscules et _ (« la_villedieu_du_clain »)"}
_DOSSIER = {"type": "string", "description": "le dossier de la commune dans le dépôt, si ce n'est pas communes/<id>/ ni tools/paquet_essai/<id>/"}

OUTILS = {
    "contrat": (contrat, "Les règles qu'une commune doit suivre (docs/COMMUNE.md) : le manifeste et ses champs, "
                "les structures, le kit de départ, le paquet, la publication. Sans section : la liste des sections.",
                {"section": {"type": "string", "description": "un mot du titre : « fournit », « structures », « paquet », « kit », « publier »…"}}, []),
    "conception": (conception, "La méthode pour concevoir un lieu réussi (docs/CONCEPTION.md), à lire avant de "
                   "construire : le critère (le lieu surprend, pas seulement « rien ne bloque »), le niveau visé, les "
                   "questions au porteur du projet, la note d'intentions (modèle et exemple complet), les trois scènes "
                   "fortes, la continuité habitée, la palette chiffrée, représenter le réel, ce qu'une commune offre "
                   "en jeu, l'animation et la vie, la méthode de travail, juger à hauteur de joueur, la critique "
                   "indépendante, travailler avec Guillaume et livrer, le ton, les pièges. Sans section : l'introduction et la liste des sections.",
                   {"section": {"type": "string", "description": "un mot du titre : « critère », « niveau », « commencer », « intentions », « scènes », « continuité », « palette », « réel », « jeu », « animation », « habitants », « méthode », « hauteur », « critique », « Guillaume », « ton », « pièges », ou « tout »"}}, []),
    "atelier": (atelier, "Ce que le jeu prête aux communes sans rien embarquer : modèles 3D par famille, maisons "
                "à façades, figurants, meubles, sons, matières, polices, scènes du socle (le stade). Donne aussi "
                "l'appel GDScript (classe Atelier). Sans argument : le résumé.",
                {"rubrique": {"type": "string", "description": "modeles, maisons, figurants, personnages, meubles, sons, matieres, polices ou scenes"},
                 "famille": {"type": "string", "description": "une famille de modèles (nature, ville, voitures, mobilier, restaurant…) : la liste de ses modèles"},
                 "cherche": {"type": "string", "description": "un mot à chercher dans les noms (« tree », « bench », « car »)"}}, []),
    "verifier_manifeste": (verifier_manifeste, "Vérifie vite un commune.json (champs obligatoires, id, INSEE, scène, "
                           "marques du kit) et signale ce que le portail affichera vide.",
                           {"id": _ID, "dossier": _DOSSIER, "texte": {"type": "string", "description": "le manifeste lui-même, au lieu d'un fichier"}}, []),
    "nouvelle_commune": (nouvelle_commune, "Crée une commune depuis le kit de départ dans communes/<id>/ : le "
                         "manifeste, une scène sans décor (habitant, caméra, lumière réglable, sol, arrivée et trois "
                         "repères de vue) et la note d'intentions à remplir avant le premier modèle.",
                         {"insee": {"type": "string", "description": "le code INSEE (« 86290 ») : le nom et la population viennent du référentiel du jeu"},
                          "id": {"type": "string", "description": "l'id, sinon tiré du nom (« la_villedieu_du_clain »)"},
                          "nom": {"type": "string", "description": "le nom affiché, sinon celui du référentiel"}, "dossier": _DOSSIER}, ["insee"]),
    "tester_commune": (tester_commune, "Le test minimal, avec Godot : le pack se greffe comme chez un joueur, le "
                       "manifeste est valide, la scène expose player et camera, l'habitant se pose et marche. Sans "
                       "argument : le kit lui-même.",
                       {"id": _ID, "dossier": _DOSSIER, "pck": {"type": "string", "description": "un paquet déjà emballé, testé tel quel"}}, []),
    "parcourir_commune": (parcourir_commune, "Juge à hauteur de joueur, avec Godot : pose l'habitant sur chaque repère "
                          "de vue de la scène (Marker3D Vue1_…, Vue2_…), vérifie qu'il tient au sol et qu'on va à pied "
                          "d'un repère au suivant ; avec rendu=true (Godot avec un écran), photographie chaque repère de "
                          "dessus, à pied et en se retournant. Captures et rapport dans user://parcours/<id>/.",
                          {"id": _ID, "dossier": _DOSSIER, "pck": {"type": "string", "description": "un paquet déjà emballé, parcouru tel quel"},
                           "reperes": {"type": "string", "description": "le début du nom des repères à suivre (« Vue » par défaut)"},
                           "rendu": {"type": "boolean", "description": "true pour les captures (demande un écran)"}}, []),
    "emballer_commune": (emballer_commune, "Emballe la commune en build/<id>.pck avec Godot, par les mêmes refus que "
                         "le jeu, et donne sa taille (32 Mo au plus sur le portail).",
                         {"id": _ID, "dossier": _DOSSIER}, ["id"]),
    "bourg_reel": (bourg_reel, "Construit le plan réel du bourg (OpenStreetMap, IGN BD TOPO et RGE ALTI) : bourg.json, "
                   "sol.png et build/plan_<id>.png. Demande le réseau. Les options sont celles de tools/bourg_reel.py.",
                   {"id": _ID, "options": {"type": "array", "items": {"type": "string"},
                                           "description": "par exemple [\"--rayon=500\", \"--riviere=Le Clain\"]"}}, ["id"]),
}


# --- Le protocole ----------------------------------------------------------------------------------

def _outils_mcp():
    return [{"name": n, "description": d, "inputSchema": {"type": "object", "properties": p, "required": r}}
            for n, (_, d, p, r) in OUTILS.items()]


def traiter(msg):
    """Une requête JSON-RPC → la réponse (dict), ou None pour une notification."""
    methode, ident, params = msg.get("method"), msg.get("id"), msg.get("params") or {}
    if ident is None:
        return None
    if methode == "initialize":
        res = {"protocolVersion": params.get("protocolVersion", PROTOCOLE),
               "capabilities": {"tools": {}},
               "serverInfo": {"name": "kit-communes", "title": "Kit des communes de Smarves", "version": VERSION},
               "instructions": CONSIGNES}
    elif methode == "ping":
        res = {}
    elif methode == "tools/list":
        res = {"tools": _outils_mcp()}
    elif methode == "tools/call":
        nom = params.get("name")
        if nom not in OUTILS:
            return {"jsonrpc": "2.0", "id": ident, "error": {"code": -32602, "message": "Outil inconnu : %s" % nom}}
        try:
            texte, erreur = OUTILS[nom][0](**(params.get("arguments") or {})), False
        except Erreur as e:
            texte, erreur = str(e), True
        except TypeError as e:
            texte, erreur = "Arguments refusés : %s" % e, True
        res = {"content": [{"type": "text", "text": texte}], "isError": erreur}
    else:
        return {"jsonrpc": "2.0", "id": ident, "error": {"code": -32601, "message": "Méthode inconnue : %s" % methode}}
    return {"jsonrpc": "2.0", "id": ident, "result": res}


def main():
    for ligne in sys.stdin:
        if not ligne.strip():
            continue
        try:
            msg = json.loads(ligne)
        except json.JSONDecodeError:
            rep = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "JSON illisible"}}
        else:
            rep = traiter(msg)
        if rep is not None:
            sys.stdout.write(json.dumps(rep, ensure_ascii=False) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
