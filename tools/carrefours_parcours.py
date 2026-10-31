#!/usr/bin/env python3
"""Relève les carrefours d'un parcours de course (relief/parcours.json) sur les routes réelles (relief/routes.json),
pour y planter un poteau qui montre le chemin, comme on balise une course la veille.

    python3 tools/carrefours_parcours.py <id> --troncons="Au Replat,Relais des Lônes" --retour="Belley, centre"
        [--avant-retour=600] [--apres-fin=90,0] [--sortie=relief/carrefours]

Un carrefour est un sommet du parcours où part une route goudronnée ou empierrée (genres 0 et 1 de routes.json)
qui n'est pas le parcours. Le poteau se plante sur le bas-côté, du côté où ne part aucune route, à la demi-largeur
de la chaussée plus 1,4 m. Il porte deux lames : celle de l'avant (la fin du tronçon, son nom pris dans
--troncons) et celle du retour (le tronçon d'avant, ou --retour pour le premier). Les distances sont celles de la
route, en mètres : --avant-retour s'ajoute au retour du premier tronçon (de son départ jusqu'au centre de la
ville), --apres-fin à la fin de chaque tronçon, dans l'ordre (de son bout jusqu'au lieu nommé). Deux carrefours de tronçons
différents à moins de 25 m l'un de l'autre (une route qu'on reprend dans l'autre sens) n'en font qu'un, avec les
lames des deux, une seule par lieu. Sur un même tronçon, un carrefour à moins de 150 m du précédent est passé.

Écrit <sortie>.json : une liste de poteaux, chacun {"x", "z", "lames": [{"cap": degrés depuis le nord, vers l'est,
"vers": le lieu, "m": mètres}]}. Le repère est celui de la commune (x vers l'est, z vers le sud).
"""
import json
import math
import os
import sys

RACINE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
# Un sommet de routes.json est le même qu'un sommet du parcours à moins de tant de mètres.
PRES = 3.0
# La route en avant et en arrière d'un carrefour : sa direction sur tant de mètres.
REGARD = 25.0
ECART_MEME_TRONCON = 150.0
ECART_FUSION = 25.0


def cap(dx, dz):
    return round(math.degrees(math.atan2(dx, -dz)) % 360.0)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    if not args or "troncons" not in opts:
        print(__doc__)
        sys.exit(2)
    ident = args[0]
    dossier = os.path.join(RACINE, "communes", ident)
    if not os.path.isdir(dossier):
        dossier = os.path.join(RACINE, "tools", "paquet_essai", ident)
    noms = [n.strip() for n in opts["troncons"].split(",")]
    retour = opts.get("retour", "Le départ")
    avant_retour = float(opts.get("avant-retour", "0"))
    apres_fin = [float(x) for x in opts.get("apres-fin", "0").split(",")]
    apres_fin += [0.0] * (len(noms) - len(apres_fin))
    with open(os.path.join(dossier, "relief", "parcours.json"), encoding="utf-8") as f:
        troncons = json.load(f)["troncons"]
    with open(os.path.join(dossier, "relief", "routes.json"), encoding="utf-8") as f:
        routes = json.load(f)["routes"]

    # Le graphe des routes : chaque sommet arrondi au mètre, ses voisins, leur genre et la largeur.
    voisins = {}
    for r in routes:
        p = r["p"]
        pts = [(round(p[i]), round(p[i + 1])) for i in range(0, len(p), 2)]
        for a, b in zip(pts, pts[1:]):
            if a != b:
                voisins.setdefault(a, []).append((b, r["g"], r["l"]))
                voisins.setdefault(b, []).append((a, r["g"], r["l"]))

    def sommet(v):
        meilleur, d = None, PRES
        for dx in range(-3, 4):
            for dz in range(-3, 4):
                q = (int(v[0]) + dx, int(v[1]) + dz)
                if q in voisins and math.hypot(dx, dz) < d:
                    meilleur, d = q, math.hypot(dx, dz)
        return meilleur

    lignes = [[(t[i], t[i + 1]) for i in range(0, len(t), 2)] for t in troncons]
    longueurs = [sum(math.dist(a, b) for a, b in zip(P, P[1:])) for P in lignes]
    poteaux = []
    for ti, P in enumerate(lignes):
        sur = {s for s in (sommet(v) for v in P) if s}
        cumul, dernier = 0.0, -1e9
        for i, v in enumerate(P):
            if i > 0:
                cumul += math.dist(P[i - 1], v)
            s = sommet(v)
            if s is None or i == 0 or i == len(P) - 1 or cumul - dernier < ECART_MEME_TRONCON:
                continue
            branches = [(n[0] - s[0], n[1] - s[1]) for n, g, _ in voisins[s] if n not in sur and g <= 1]
            if not branches:
                continue
            dernier = cumul

            def vers(pas):
                j, d = i, 0.0
                while 0 <= j + pas < len(P) and d < REGARD:
                    d += math.dist(P[j], P[j + pas])
                    j += pas
                return (P[j][0] - v[0], P[j][1] - v[1])

            av, ar = vers(1), vers(-1)
            n = math.hypot(*av) or 1.0
            droite = (-av[1] / n, av[0] / n)
            cotes = [(b[0] * droite[0] + b[1] * droite[1]) / (math.hypot(*b) or 1.0) for b in branches]
            # Du côté où ne part aucune route : à droite de l'avant, sauf si une branche part seulement à droite.
            cote = -1.0 if any(c > 0.3 for c in cotes) and not any(c < -0.3 for c in cotes) else 1.0
            ecart = max(l for _, _, l in voisins[s]) / 2.0 + 1.4
            lames = [{"cap": cap(*av), "vers": noms[ti], "m": round(longueurs[ti] - cumul + apres_fin[ti])}]
            if ti == 0:
                lames.append({"cap": cap(*ar), "vers": retour, "m": round(cumul + avant_retour)})
            else:
                lames.append({"cap": cap(*ar), "vers": noms[ti - 1], "m": round(cumul + apres_fin[ti - 1])})
            poteaux.append({"x": round(v[0] + droite[0] * ecart * cote, 1), "z": round(v[1] + droite[1] * ecart * cote, 1),
                            "lames": lames, "_t": ti})

    # Une route reprise dans l'autre sens : un seul poteau, les lames des deux, une par lieu.
    garde = []
    for p in poteaux:
        double = next((q for q in garde if q["_t"] != p["_t"] and math.hypot(q["x"] - p["x"], q["z"] - p["z"]) < ECART_FUSION), None)
        if double is None:
            garde.append(p)
            continue
        for lame in p["lames"]:
            if all(l["vers"] != lame["vers"] for l in double["lames"]):
                double["lames"].append(lame)
    for p in garde:
        del p["_t"]
    sortie = os.path.join(dossier, opts.get("sortie", "relief/carrefours") + ".json")
    with open(sortie, "w", encoding="utf-8") as f:
        json.dump(garde, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
    print("%d poteaux sur %.1f km de parcours, écrits dans %s" % (len(garde), sum(longueurs) / 1000.0, sortie))


if __name__ == "__main__":
    main()
