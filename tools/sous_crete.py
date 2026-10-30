#!/usr/bin/env python3
"""La profondeur sous la crête : pour chaque point d'une carte de relief de Belley (relief.png, crete.png), la
hauteur qui le sépare du point le plus haut à moins de 300 m (fenêtre carrée). Le shader du terrain y pose les
barres calcaires, collées à la crête (de 60 à 120 m sous le haut de chaque versant, verdict n° 9 du juge).

    python3 tools/sous_crete.py communes/belley/relief

Écrit sous_crete_<nom>.png (un mètre par niveau, de 0 à 255) et son .json (le cadre de la carte source).
"""
import json
import sys

import numpy as np
from PIL import Image

RAYON = 300.0


def hauteurs(dossier, nom):
    m = json.load(open(f"{dossier}/{nom}.json"))
    a = np.array(Image.open(f"{dossier}/{nom}.png").convert("RGB")).astype(np.float64)
    h = (a[..., 0] * 256 + a[..., 1]) / 65535.0 * (m["blanc"] - m["noir"]) + m["noir"]
    return m, h


def maximum_local(h, r):
    # Le maximum sur une fenêtre de (2r+1)², en deux passes séparées.
    out = h.copy()
    for axe in (0, 1):
        acc = out.copy()
        for k in range(1, r + 1):
            acc = np.maximum(acc, np.roll(out, k, axis=axe))
            acc = np.maximum(acc, np.roll(out, -k, axis=axe))
        out = acc
    return out


def main():
    dossier = sys.argv[1]
    for nom in ("relief", "crete"):
        m, h = hauteurs(dossier, nom)
        r = int(round(RAYON / m["pas"]))
        d = np.clip(maximum_local(h, r) - h, 0, 255).astype(np.uint8)
        Image.fromarray(d, "L").save(f"{dossier}/sous_crete_{nom}.png")
        json.dump({"cadre": m["cadre"], "pas": m["pas"], "rayon": RAYON}, open(f"{dossier}/sous_crete_{nom}.json", "w"))
        print(nom, d.shape, "médiane", float(np.median(d)))


if __name__ == "__main__":
    main()
