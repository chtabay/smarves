"""Les sculptures de la place Sathonay, modelées en champs de distance et mises en maillage.

Le lion couché des deux fontaines (fonderie du Creusot, 1823) et le sergent Blandan de Lamotte (1900) :
des formes simples (ellipsoïdes, capsules, cônes) fondues l'une dans l'autre par une union douce, comme
un modeleur pousse la terre, puis taillées en triangles par marching cubes. Chaque sculpture est écrite
en binaire à côté de ce script (lion.bin, blandan.bin), lu par lyon.gd : nombre de sommets, nombre
d'indices, positions, normales, occlusion (0 au creux, 1 en saillie), indices. En mètres, la face
vers +Z, le pied à y = 0.

    python3 -I tools/paquet_essai/lyon/sculptures/sculpter.py
"""
import os
import struct
import sys

import numpy as np
from skimage.measure import marching_cubes

ICI = os.path.dirname(os.path.abspath(__file__))


def lisse(a, b, k):
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b * (1 - h) + a * h - k * h * (1 - h)


def ote(a, b, k):
    """b creusé par a."""
    return -lisse(-b, a, k)


def ellipsoide(p, c, r):
    q = (p - np.array(c)) / np.array(r)
    k0 = np.linalg.norm(q, axis=-1)
    k1 = np.linalg.norm(q / np.array(r), axis=-1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)


def capsule(p, a, b, r):
    a = np.array(a)
    b = np.array(b)
    pa = p - a
    ba = b - a
    h = np.clip((pa @ ba) / (ba @ ba), 0.0, 1.0)
    return np.linalg.norm(pa - h[..., None] * ba, axis=-1) - r


def tronc_cone(p, y0, y1, r0, r1, cx=0.0, cz=0.0):
    q = np.stack([np.hypot(p[..., 0] - cx, p[..., 2] - cz), p[..., 1]], axis=-1)
    t = np.clip((q[..., 1] - y0) / (y1 - y0), 0.0, 1.0)
    r = r0 + (r1 - r0) * t
    d_cote = (q[..., 0] - r) * np.cos(np.arctan2(r0 - r1, y1 - y0))
    d_cap = np.maximum(y0 - q[..., 1], q[..., 1] - y1)
    return np.maximum(d_cote, d_cap)


def boite(p, c, t, rayon=0.0):
    q = np.abs(p - np.array(c)) - np.array(t) + rayon
    return np.linalg.norm(np.maximum(q, 0.0), axis=-1) + np.minimum(np.max(q, axis=-1), 0.0) - rayon


def symetrique(f):
    """Une forme et sa jumelle de l'autre côté du plan x = 0."""
    def g(p):
        q = p.copy()
        q[..., 0] = np.abs(q[..., 0])
        return f(q)
    return g


def lion(p):
    x = p[..., 0]
    y = p[..., 1]
    z = p[..., 2]
    # le corps couché, le dos qui descend vers la croupe
    d = capsule(p, (0, 0.40, -0.72), (0, 0.46, 0.22), 0.30)
    d = lisse(d, ellipsoide(p, (0, 0.30, -0.70), (0.34, 0.30, 0.36)), 0.08)
    cote = symetrique(lambda q: lisse(
        ellipsoide(q, (0.21, 0.30, -0.66), (0.17, 0.28, 0.34)),
        capsule(q, (0.30, 0.09, -0.78), (0.32, 0.075, -0.16), 0.085), 0.06))
    d = lisse(d, cote(p), 0.06)
    pattes_arriere = symetrique(lambda q: ellipsoide(q, (0.33, 0.06, -0.09), (0.10, 0.06, 0.13)))
    d = lisse(d, pattes_arriere(p), 0.03)
    # les pattes de devant allongées, les doigts
    devant = symetrique(lambda q: lisse(lisse(
        capsule(q, (0.17, 0.32, 0.30), (0.19, 0.09, 0.56), 0.10),
        capsule(q, (0.19, 0.09, 0.56), (0.19, 0.075, 0.95), 0.083), 0.04),
        ellipsoide(q, (0.19, 0.06, 1.00), (0.11, 0.06, 0.12)), 0.03))
    d = lisse(d, devant(p), 0.05)
    doigts = symetrique(lambda q: np.minimum(np.minimum(
        ellipsoide(q, (0.15, 0.05, 1.08), (0.035, 0.035, 0.04)),
        ellipsoide(q, (0.19, 0.05, 1.10), (0.035, 0.035, 0.04))),
        ellipsoide(q, (0.23, 0.05, 1.08), (0.035, 0.035, 0.04))))
    d = lisse(d, doigts(p), 0.015)
    # le poitrail, la crinière en grosses mèches, la tête
    d = lisse(d, ellipsoide(p, (0, 0.50, 0.33), (0.30, 0.36, 0.30)), 0.08)
    criniere = ellipsoide(p, (0, 0.74, 0.42), (0.36, 0.42, 0.30))
    criniere = lisse(criniere, ellipsoide(p, (0, 0.52, 0.5), (0.26, 0.3, 0.2)), 0.08)
    # les mèches : des côtes qui rayonnent depuis la face et retombent vers les épaules
    ang = np.arctan2(x, y - 0.8)
    criniere += 0.025 * np.sin(ang * 11.0) * np.clip((0.75 - (z - 0.1)) * 2.0, 0.0, 1.0)
    d = lisse(d, criniere, 0.07)
    tete = ellipsoide(p, (0, 0.86, 0.66), (0.17, 0.18, 0.19))
    tete = lisse(tete, ellipsoide(p, (0, 0.77, 0.84), (0.115, 0.10, 0.14)), 0.05)
    tete = lisse(tete, ellipsoide(p, (0, 0.83, 0.96), (0.05, 0.035, 0.04)), 0.02)
    tete = lisse(tete, capsule(p, (-0.085, 0.95, 0.79), (0.085, 0.95, 0.79), 0.035), 0.03)
    tete = lisse(tete, symetrique(lambda q: ellipsoide(q, (0.07, 0.75, 0.91), (0.06, 0.05, 0.05)))(p), 0.02)
    tete = lisse(tete, symetrique(lambda q: ellipsoide(q, (0.14, 1.01, 0.6), (0.05, 0.05, 0.03)))(p), 0.02)
    # la gueule entrouverte d'où l'eau sort, les orbites
    tete = ote(ellipsoide(p, (0, 0.71, 0.94), (0.065, 0.025, 0.06)), tete, 0.015)
    tete = ote(symetrique(lambda q: ellipsoide(q, (0.07, 0.895, 0.83), (0.03, 0.02, 0.02)))(p), tete, 0.01)
    d = lisse(d, tete, 0.04)
    # la queue le long du flanc droit, sa touffe
    queue = lisse(capsule(p, (0.10, 0.28, -1.00), (0.38, 0.07, -0.78), 0.04),
                  capsule(p, (0.38, 0.07, -0.78), (0.37, 0.06, -0.22), 0.035), 0.03)
    queue = lisse(queue, ellipsoide(p, (0.37, 0.07, -0.15), (0.06, 0.06, 0.1)), 0.03)
    d = lisse(d, queue, 0.03)
    return d


def blandan(p):
    x = p[..., 0]
    y = p[..., 1]
    # la terrasse de bronze
    d = boite(p, (0, 0.04, 0), (0.55, 0.04, 0.45), 0.02)
    # les jambes en marche, les souliers
    j = lisse(capsule(p, (-0.13, 0.12, -0.16), (-0.11, 0.95, -0.01), 0.095),
              capsule(p, (0.14, 0.12, 0.22), (0.11, 0.95, 0.02), 0.095), 0.04)
    j = lisse(j, ellipsoide(p, (-0.13, 0.12, -0.10), (0.09, 0.06, 0.15)), 0.03)
    j = lisse(j, ellipsoide(p, (0.14, 0.12, 0.28), (0.09, 0.06, 0.15)), 0.03)
    d = lisse(d, j, 0.03)
    # la capote : la jupe évasée aux pans ouverts, le buste, le ceinturon, le sac
    jupe = tronc_cone(p, 0.62, 1.48, 0.34, 0.26)
    jupe = ote(boite(p, (0, 0.8, 0.38), (0.05, 0.22, 0.12)), jupe, 0.03)
    jupe = ote(boite(p, (0, 0.55, 0), (0.5, 0.06, 0.5)), jupe, 0.04)
    d = lisse(d, jupe, 0.05)
    d = lisse(d, ellipsoide(p, (0, 1.76, 0.0), (0.27, 0.36, 0.19)), 0.08)
    d = lisse(d, tronc_cone(p, 1.43, 1.50, 0.285, 0.285), 0.01)
    d = lisse(d, boite(p, (0, 1.78, -0.24), (0.2, 0.2, 0.08), 0.04), 0.04)
    d = lisse(d, symetrique(lambda q: ellipsoide(q, (0.24, 1.98, 0.0), (0.11, 0.09, 0.11)))(p), 0.05)
    # les bras qui tiennent le fusil en travers, baïonnette au canon
    bras = lisse(capsule(p, (0.26, 1.98, 0.0), (0.31, 1.66, 0.17), 0.075),
                 capsule(p, (0.31, 1.66, 0.17), (0.08, 1.56, 0.33), 0.065), 0.03)
    bras = lisse(bras, capsule(p, (-0.26, 1.98, 0.0), (-0.31, 1.80, 0.20), 0.075), 0.03)
    bras = lisse(bras, capsule(p, (-0.31, 1.80, 0.20), (-0.12, 1.95, 0.40), 0.065), 0.03)
    bras = lisse(bras, ellipsoide(p, (0.06, 1.56, 0.35), (0.06, 0.06, 0.07)), 0.02)
    bras = lisse(bras, ellipsoide(p, (-0.11, 1.97, 0.42), (0.06, 0.06, 0.07)), 0.02)
    d = lisse(d, bras, 0.04)
    fusil = lisse(capsule(p, (0.30, 1.12, 0.20), (0.12, 1.46, 0.29), 0.05),
                  capsule(p, (0.12, 1.46, 0.29), (-0.26, 2.36, 0.50), 0.026), 0.02)
    fusil = np.minimum(fusil, capsule(p, (-0.26, 2.36, 0.50), (-0.34, 2.58, 0.55), 0.011))
    d = np.minimum(d, fusil)
    # le col, la tête, le shako à visière et son pompon
    d = lisse(d, capsule(p, (0, 2.05, 0), (0, 2.17, 0.02), 0.08), 0.04)
    tete = ellipsoide(p, (0, 2.29, 0.03), (0.105, 0.135, 0.12))
    tete = lisse(tete, ellipsoide(p, (0, 2.27, 0.14), (0.025, 0.035, 0.03)), 0.015)
    tete = lisse(tete, ellipsoide(p, (0, 2.19, 0.09), (0.07, 0.04, 0.06)), 0.03)
    d = lisse(d, tete, 0.03)
    shako = tronc_cone(p, 2.36, 2.62, 0.125, 0.115, 0.0, 0.0)
    shako = lisse(shako, ellipsoide(p, (0, 2.38, 0.14), (0.11, 0.016, 0.075)), 0.01)
    shako = lisse(shako, ellipsoide(p, (0, 2.66, 0.04), (0.045, 0.045, 0.045)), 0.02)
    d = np.minimum(d, shako)
    return d


def tailler(f, bas, haut, pas):
    xs = np.arange(bas[0], haut[0], pas)
    ys = np.arange(bas[1], haut[1], pas)
    zs = np.arange(bas[2], haut[2], pas)
    grille = np.stack(np.meshgrid(xs, ys, zs, indexing="ij"), axis=-1)
    champ = f(grille)
    v, faces, n, _ = marching_cubes(champ, 0.0, spacing=(pas, pas, pas))
    v += np.array(bas)
    # les normales vers le dehors (le gradient du champ), l'occlusion par un pas en dedans du creux
    eps = pas * 0.5
    g = np.stack([f(v + np.array(e)) - f(v - np.array(e)) for e in ((eps, 0, 0), (0, eps, 0), (0, 0, eps))], axis=-1)
    n = g / np.maximum(np.linalg.norm(g, axis=-1, keepdims=True), 1e-9)
    occ = np.ones(len(v))
    for r in (0.03, 0.07, 0.12):
        occ -= np.clip((r - f(v + n * r)) / r, 0.0, 1.0) * 0.3
    occ = np.clip(occ, 0.0, 1.0)
    # Godot dessine les faces dans l'autre sens que skimage
    faces = faces[:, ::-1]
    return v.astype(np.float32), n.astype(np.float32), occ.astype(np.float32), faces.astype(np.int32).ravel()


def ecrire(nom, v, n, occ, idx):
    with open(os.path.join(ICI, nom), "wb") as fd:
        fd.write(struct.pack("<ii", len(v), len(idx)))
        fd.write(v.tobytes())
        fd.write(n.tobytes())
        fd.write(occ.tobytes())
        fd.write(idx.tobytes())
    print(nom, len(v), "sommets", len(idx) // 3, "triangles")


if __name__ == "__main__":
    pas = float(sys.argv[1]) if len(sys.argv) > 1 else 0.018
    ecrire("lion.bin", *tailler(lion, (-0.5, -0.02, -1.15), (0.5, 1.15, 1.2), pas))
    ecrire("blandan.bin", *tailler(blandan, (-0.6, -0.02, -0.5), (0.6, 2.75, 0.75), pas * 0.8))
