#!/usr/bin/env python3
"""Vérifie le serveur MCP du kit comme le ferait Claude : python3 tools/mcp/test_kit_communes.py
Il le lance, se présente (initialize), liste les outils et appelle chacun de ceux qui ne demandent ni
Godot ni le réseau ; --godot appelle aussi tester_commune sur le kit et sur une commune créée exprès."""

import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ICI = Path(__file__).resolve().parent
RACINE = ICI.parents[1]
echecs = 0


def check(ok, quoi):
    global echecs
    print(("ok      " if ok else "ÉCHEC   ") + quoi)
    echecs += 0 if ok else 1


serveur = subprocess.Popen([sys.executable, str(ICI / "kit_communes.py")], stdin=subprocess.PIPE,
                           stdout=subprocess.PIPE, text=True, encoding="utf-8")
n = 0


def demande(methode, params=None, notification=False):
    global n
    msg = {"jsonrpc": "2.0", "method": methode, "params": params or {}}
    if not notification:
        n += 1
        msg["id"] = n
    serveur.stdin.write(json.dumps(msg) + "\n")
    serveur.stdin.flush()
    return None if notification else json.loads(serveur.stdout.readline())


def outil(nom_outil, **args):
    r = demande("tools/call", {"name": nom_outil, "arguments": args})["result"]
    return r["content"][0]["text"], r["isError"]


r = demande("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "essai", "version": "0"}})
check(r["result"]["serverInfo"]["name"] == "kit-communes", "le serveur se présente")
check("tools" in r["result"]["capabilities"], "  et annonce des outils")
demande("notifications/initialized", notification=True)
noms = [t["name"] for t in demande("tools/list")["result"]["tools"]]
check(set(noms) >= {"contrat", "conception", "atelier", "verifier_manifeste", "nouvelle_commune", "tester_commune", "parcourir_commune", "emballer_commune", "bourg_reel"},
      "les outils sont listés : " + ", ".join(noms))

t, e = outil("contrat")
check(not e and "Les structures" in t, "contrat liste les sections")
t, e = outil("contrat", section="structures")
check(not e and "terrain_foot" in t, "contrat donne la section des structures")
t, e = outil("conception")
check(not e and "surprend" in t and "L'animation et la vie" in t, "conception donne l'introduction et les sections")
t, e = outil("conception", section="animation")
check(not e and "suivre(" in t and "scripts actifs" in t, "conception donne la section de l'animation")
t, e = outil("conception", section="tout")
check(not e and "## Les pièges déjà rencontrés" in t, "conception donne la méthode entière")
t, e = outil("conception", section="licornes")
check(e, "une section inconnue de la conception est une erreur")
t, e = outil("atelier")
check(not e and "maisons" in t and "figurants" in t, "atelier donne le résumé")
t, e = outil("atelier", famille="nature", cherche="tree")
check(not e and "tree_oak" in json.loads(t)["modeles"], "atelier liste les arbres de la nature")
t, e = outil("atelier", cherche="bench")
check(not e and "ville" in json.loads(t)["trouve"], "atelier trouve un banc en ville")
t, e = outil("atelier", famille="licornes")
check(e, "une famille inconnue est une erreur")
t, e = outil("verifier_manifeste", id="availles_limouzine")
check(not e and "accepté" in t, "le manifeste d'Availles-Limouzine passe")
t, e = outil("verifier_manifeste", texte=(RACINE / "tools/kit/commune.json").read_text(encoding="utf-8"))
check(not e and "REFUS" in t and "marques du kit" in t, "le manifeste du kit non rempli est refusé")
t, e = outil("nouvelle_commune", insee="86999")
check(e, "un INSEE inconnu est refusé")
t, e = outil("nouvelle_commune", insee="75056")
check(e, "Paris, dont le jeu ne connaît pas les communes, est refusé")
with tempfile.TemporaryDirectory() as d:
    t, e = outil("nouvelle_commune", insee="01034", dossier=d + "/belley")
    m = json.loads((Path(d) / "belley/commune.json").read_text(encoding="utf-8")) if not e else {}
    check(not e and m.get("insee") == "01034" and m.get("socle_min") == "1.19" and m.get("population", 0) > 9000,
          "Belley, dans l'Ain, part du kit avec le socle 1.19 : %s" % t)
    m["socle_min"] = "1.12"
    t, e = outil("verifier_manifeste", texte=json.dumps(m))
    check("REFUS" in t and "socle_min" in t, "et le socle 1.12 ne lui suffit pas")
t, e = outil("verifier_manifeste", texte="{pas du json")
check("REFUS" in t, "un manifeste illisible est refusé")

essai = RACINE / "communes" / "vouneuil_sous_biard"
shutil.rmtree(essai, ignore_errors=True)
try:
    t, e = outil("nouvelle_commune", insee="86297")
    check(not e and (essai / "commune.json").is_file(), "nouvelle_commune crée Vouneuil-sous-Biard depuis le kit, par son INSEE")
    m = json.loads((essai / "commune.json").read_text(encoding="utf-8"))
    check(m["nom"] == "Vouneuil-sous-Biard" and m["population"] > 0, "  avec le nom et la population du référentiel")
    check(m["banque"]["nom"] == "La caisse de Vouneuil-sous-Biard", "  et sa caisse à son nom")
    note = (essai / "INTENTIONS.md").read_text(encoding="utf-8") if (essai / "INTENTIONS.md").is_file() else ""
    check(note.startswith("# Vouneuil-sous-Biard — note d'intentions"), "  et sa note d'intentions à remplir")
    angles = RACINE / "communes" / "angles_sur_l_anglin"
    if not angles.exists():
        try:
            outil("nouvelle_commune", insee="86004")
            b = json.loads((angles / "commune.json").read_text(encoding="utf-8"))["banque"]["nom"]
            check(b == "La caisse d'Angles-sur-l'Anglin", "  le nom de la caisse s'élide devant une voyelle : %s" % b)
        finally:
            shutil.rmtree(angles, ignore_errors=True)
    t, e = outil("verifier_manifeste", id="vouneuil_sous_biard")
    check(not e and "accepté" in t, "  et son manifeste passe")
    t, e = outil("nouvelle_commune", insee="86297")
    check(e, "  et n'est pas écrasée une seconde fois")
    if "--godot" in sys.argv:
        t, e = outil("tester_commune", id="vouneuil_sous_biard")
        check(t.startswith("RÉUSSI"), "tester_commune passe sur la commune créée")
        t, e = outil("tester_commune")
        check(t.startswith("RÉUSSI"), "tester_commune passe sur le kit")
        if not t.startswith("RÉUSSI"):
            print(t[-2000:])
        t, e = outil("parcourir_commune", id="vouneuil_sous_biard")
        check(t.startswith("RÉUSSI") and "Vue2_Scene2 → Vue3_Scene3" in t, "parcourir_commune marche d'un repère de vue à l'autre")
        if not t.startswith("RÉUSSI"):
            print(t[-2000:])
finally:
    shutil.rmtree(essai, ignore_errors=True)

serveur.stdin.close()
serveur.wait(timeout=10)
print("\n%d échec(s)" % echecs)
sys.exit(1 if echecs else 0)
