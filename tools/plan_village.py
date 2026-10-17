#!/usr/bin/env python3
"""Dessine le plan du village (vue de dessus) à partir des rangées de scripts/village/village.gd.
Usage : python3 tools/plan_village.py sortie.png
"""
import re, sys
from PIL import Image, ImageDraw, ImageFont

SRC = open(__file__.replace("tools/plan_village.py", "scripts/village/village.gd")).read()
BOIS = open(__file__.replace("tools/plan_village.py", "scripts/village/bois.gd")).read()
CHEMIN = open(__file__.replace("tools/plan_village.py", "scripts/village/passelourdin.gd")).read()
def const(src, name): return float(re.search(r"const %s := ([-0-9.]+)" % name, src).group(1))
ROND_X, RING_R = const(BOIS, "ROND_X"), const(BOIS, "RING_R")

def rows(name):
    block = SRC.split("const %s := [" % name)[1].split("\n]\n")[0]
    out = []
    for line in block.strip().splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        w = float(re.search(r'"w": ([0-9.]+)', line).group(1))
        ident = re.search(r'"id": "([^"]+)"', line)
        kind = re.search(r'"kind": "([^"]+)"', line)
        shop = re.search(r'"name": "([^"]+)"', line)
        if '"to":' in line:
            w = -1.0  # jusqu'au bout du rond-point
        out.append((w, ident.group(1) if ident else "", kind.group(1) if kind else "house", shop.group(1) if shop else ""))
    return out

S = 9  # pixels par mètre
X0, X1, Z0, Z1 = -84, 84, -82, 20
W, H = int((X1 - X0) * S), int((Z1 - Z0) * S)
img = Image.new("RGB", (W, H + 230), (16, 20, 36))
d = ImageDraw.Draw(img)
def P(x, z): return ((x - X0) * S, (z - Z0) * S)
def rect(x0, z0, x1, z1, fill, outline=None, width=1):
    a, b = P(min(x0, x1), min(z0, z1)), P(max(x0, x1), max(z0, z1))
    d.rectangle([a, b], fill=fill, outline=outline, width=width)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", 15)
    big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", 22)
    small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 11)
except OSError:
    font = big = small = ImageFont.load_default()

WALNUT, GRASS, ROAD, STONE, GOLD = (70, 40, 22), (52, 78, 40), (30, 30, 34), (220, 205, 175), (240, 190, 90)
# Les socles existants.
plinths = {"Place de la Mairie": (0, 0), "Bois de Saint-Pierre": (70, 0), "Moulin des Dames": (-70, 0), "Rochers de Passelourdin": (0, -70)}
for name, (cx, cz) in plinths.items():
    rect(cx - 11.3, cz - 8.3, cx + 11.3, cz + 8.3, WALNUT)
    rect(cx - 11, cz - 8, cx + 11, cz + 8, (60, 58, 56) if name.startswith("Place") else GRASS)
# La rue du Clain.
rect(-58.9, -8.3, -11.3, 15.3, WALNUT)
rect(-58.9, -8.0, -11.3, 15.0, GRASS)
# La route du Bois.
rect(11.3, -8.3, 58.9, 15.3, WALNUT)
rect(11.3, -8.0, 58.9, 15.0, GRASS)
# Le chemin de Passelourdin : la rue de l'Église, puis le chemin de terre entre les vignes.
CX0, CX1 = const(CHEMIN, "X0"), const(CHEMIN, "X1")
LANE_X, WEST_F, EAST_F, LANE_END = const(CHEMIN, "LANE_X"), const(CHEMIN, "WEST_FRONT"), const(CHEMIN, "EAST_FRONT"), const(CHEMIN, "LANE_END")
rect(CX0 - 0.3, -61.7, CX1 + 0.3, -8.3, WALNUT)
rect(CX0, -61.7, CX1, -8.3, GRASS)
VINE = (150, 70, 40)
for x0, x1, z0, z1 in [(CX0 + 0.4, -4.6, -23.0, -36.5), (1.4, CX1 - 0.4, -22.6, -28.8), (4.0, CX1 - 0.4, -31.0, -40.0), (CX0 + 0.4, -4.4, -38.0, -48.5)]:
    rect(x0, z0, x1, z1, (70, 50, 35))
    z = max(z0, z1) - 0.45
    while z > min(z0, z1) + 0.3:
        rect(x0 + 0.3, z - 0.12, x1 - 0.3, z + 0.12, VINE)
        z -= 0.9
NAMED = {"LANE_X": LANE_X, "LANE_END": LANE_END}
def num(t): return NAMED[t] if t in NAMED else float(t)
path = [(num(a), num(b)) for a, b in re.findall(r"Vector2\(([-0-9.A-Z_]+), ([-0-9.A-Z_]+)\)", CHEMIN.split("const PATH := [")[1].split("]\n")[0])]
d.line([P(x, z) for x, z in path], fill=(150, 135, 110), width=int(1.6 * S), joint="curve")
rect(EAST_F - 0.1, -8.3, WEST_F + 0.1, LANE_END, (150, 135, 110))
def vec(name):
    m = re.search(r"const %s := Vector3\(([-0-9.]+), [-0-9.]+, ([-0-9.]+)\)" % name, CHEMIN)
    return float(m.group(1)), float(m.group(2))
def side_houses(name, front, out):
    block = CHEMIN.split("const %s := [" % name)[1].split("\n]\n")[0]
    z = -8.3 - 0.7
    for line in block.strip().splitlines():
        w = float(re.search(r"\[([0-9.]+),", line).group(1))
        if '"jardin"' in line:
            rect(front, z, front - out * 1.0, z - w, (70, 110, 55))
        else:
            ident = re.search(r'"id": "([^"]+)"', line)
            rect(front, z - 0.05, front - out * 3.0, z - w + 0.05, (235, 175, 80) if ident else (200, 110, 70), outline=(40, 30, 20))
            if ident:
                LEGEND.append(LABELS.get(ident.group(1), ident.group(1)))
                d.text(P(front - out * 1.5, z - w / 2), str(len(LEGEND)), fill=(20, 20, 30), font=font, anchor="mm")
        z -= w
# La route, de part en part.
rect(-81, 5.2, 81, 7.6, ROAD)
for x in range(-80, 80, 2):
    rect(x, 6.36, x + 0.9, 6.44, (200, 200, 190))
rect(-58.9, 1.5, -50.4, 4.9, (40, 90, 120))
rect(-81, 1.5, -59, 4.9, (40, 90, 120))
# Le rond-point du vieux chêne.
cx_, cz_ = P(ROND_X, 6.4)
d.ellipse([cx_ - RING_R * S, cz_ - RING_R * S, cx_ + RING_R * S, cz_ + RING_R * S], fill=ROAD, outline=STONE)
d.ellipse([cx_ - 1.3 * S, cz_ - 1.3 * S, cx_ + 1.3 * S, cz_ + 1.3 * S], fill=(70, 110, 55), outline=STONE)
# Les façades.
SIGNS = []
LEGEND = []
LABELS = {"notaire": "Étude de Maître Garnier, notaire", "poste": "La poste (PTT) et sa cabine", "boucherie": "Boucherie Texier", "lot_reserve": "Local réservé", "coiffure": "Gisèle Coiffure", "couture": "Raymonde, couture et retouches", "pizzeria": "Pizzeria du Clain", "epicerie": "L'Épicerie du Bourg", "fleurs": "Fleurs Odette", "brocante": "Brocante Boutin, meubles et objets", "bibliotheque": "Bibliothèque municipale",
          "maison_eglise": "Maison de la rue de l'Église", "garage": "Garage Fradin et ses pompes", "pharmacie": "Pharmacie", "lot_bois": "Local réservé", "ecole": "École publique et sa cour", "stade": "Stade municipal, U.S. Smarves"}
def draw_row(row, north, x_start, step):
    x = x_start
    front = 4.3 if north else 8.5
    for w, ident, kind, shop in row:
        if w < 0:
            w = abs(ROND_X + RING_R + 0.4 - x)
        x0, x1 = sorted((x, x + step * w))
        def number():
            LEGEND.append(LABELS.get(ident, shop))
            tx, tz = P((x0 + x1) / 2, (z0 + z1) / 2)
            d.text((tx, tz), str(len(LEGEND)), fill=(20, 20, 30), font=font, anchor="mm")
        if kind in ("garage", "ecole", "stade"):
            depth = {"garage": 5.1, "ecole": 4.1, "stade": 12.0}[kind]
            z0, z1 = front - depth, front
            rect(x0 + 0.05, z0, x1 - 0.05, z1, (235, 175, 80) if kind == "garage" else (90, 140, 70) if kind == "stade" else (220, 200, 150), outline=(40, 30, 20))
            number()
        elif kind == "pavillon":
            z0, z1 = front + 1.6, front + 4.4
            rect(x0 + 0.1, z0, x1 - 0.1, z1, (215, 195, 165), outline=(40, 30, 20))
        elif kind == "house":
            z0, z1 = (front - 3.3, front) if north else (front, front + 3.3)
            col = (200, 110, 70) if not ident else ((120, 160, 120) if ident.startswith("lot_") else (235, 175, 80))
            rect(x0 + 0.05, z0, x1 - 0.05, z1, col, outline=(40, 30, 20))
            if shop or ident:
                number()
        elif kind == "ruelle":
            rect(x0 + 0.2, -8.0, x1 - 0.2, front, (150, 135, 110))
            SIGNS.append(((x0 + x1) / 2 + 0.9, front - 0.6))
            tx, tz = P((x0 + x1) / 2, -4)
            d.text((tx, tz), "ruelle", fill=STONE, font=small, anchor="mm")
        elif kind in ("porche", "jardin"):
            z0, z1 = (front - 2.5, front) if north else (front, front + 2.5)
            rect(x0 + 0.2, z0, x1 - 0.2, z1, (70, 110, 55))
        x += step * w
draw_row(rows("NORTH_ROW"), True, -11.8, -1)
draw_row(rows("SOUTH_ROW"), False, -11.8, -1)
draw_row(rows("BOIS_NORTH"), True, 11.8, 1)
draw_row(rows("BOIS_SOUTH"), False, 11.8, 1)
side_houses("WEST", WEST_F, 1)
side_houses("EAST", EAST_F, -1)
cx, cz = vec("CHATEAU_EAU")
d.ellipse([P(cx - 1.75, cz - 1.75), P(cx + 1.75, cz + 1.75)], fill=(225, 220, 205), outline=(40, 30, 20))
cx, cz = vec("CABANE")
rect(cx - 0.95, cz - 0.85, cx + 0.95, cz + 0.85, (170, 175, 180), outline=(40, 30, 20))
# Lavoir, placette.
rect(-56.5, 1.7, -52.5, 4.7, (180, 100, 60), outline=(40, 30, 20))
d.text(P(-54.5, 0.5), "lavoir", fill=STONE, font=small, anchor="mm")
rect(-58.9, 8.6, -49.9, 13.2, (150, 135, 110))
d.text(P(-54.4, 12.0), "placette", fill=(40, 30, 20), font=small, anchor="mm")
# Les lieux de la place et des environs, pour se repérer.
marks = {"Café": (-8.8, -0.6), "Rabelais": (-9, 4.4), "Mairie": (-4.6, -5.8), "Église": (0.4, -6), "Casino": (6.4, -6),
         "Boulangerie": (9, -1.2), "Crédit Smarvois": (9, 3.8), "érable": (0.6, -0.4),
         "moulin": (-72, -1), "pont": (-64.5, 3.2), "zèbres": (64, 3.5), "château": (70, -6.2),
         "calvaire": (-0.3, -24.0), "château d'eau": (5.6, -45.0), "cabane de vigne": (-7.2, -43.0), "presbytère": (-0.2, -10.7)}
for k, (x, z) in marks.items():
    px, pz = P(x, z)
    d.ellipse([px - 4, pz - 4, px + 4, pz + 4], fill=GOLD)
    d.text((px, pz - 12), k, fill=STONE, font=small, anchor="mm")
for name, (cx, cz) in plinths.items():
    if cz < -60:
        # Le socle des rochers touche le chemin par le sud : son nom passe à côté.
        d.text(P(cx + 11.8, cz), name.upper(), fill=GOLD, font=font, anchor="lm")
    else:
        d.text(P(cx, cz + 9.6), name.upper(), fill=GOLD, font=font, anchor="mm")
d.text(P(-35.1, 16.6), "RUE DU CLAIN", fill=GOLD, font=font, anchor="mm")
d.text(P(35.1, 16.6), "ROUTE DU BOIS", fill=GOLD, font=font, anchor="mm")
d.text(P(ROND_X, 0.6), "vieux chêne", fill=STONE, font=small, anchor="mm")
d.text(P(CX1 + 1.0, -35.0), "CHEMIN DE\nPASSELOURDIN", fill=GOLD, font=font, anchor="lm")
# Les panneaux (raccourcis) et les passages à pied.
for x, z in [(9.0, 7.75), (-6.2, 7.75), (-4.0, -2.9)] + SIGNS:
    px, pz = P(x, z)
    d.rectangle([px - 4, pz - 4, px + 4, pz + 4], fill=(230, 120, 60))
d.text((20, H + 14), "Smarves — plan de la maquette", fill=GOLD, font=big)
d.text((20, H + 50), "Gris : la place. Vert : socles et jardins. Orange : maisons. Or : commerces. Vert pâle : locaux réservés aux lieux à venir.", fill=STONE, font=font)
d.text((20, H + 74), "Carrés orange : panneaux de bois (raccourcis). La route traverse tout : on va à pied du Moulin des Dames au bois de Saint-Pierre.", fill=STONE, font=font)
d.text((20, H + 98), "Au nord, le chemin de Passelourdin monte entre les vignes jusqu'aux rochers. Nord en haut, 1 m = %d px." % S, fill=STONE, font=font)
for i, name in enumerate(LEGEND):
    d.text((20 + (i // 5) * 300, H + 130 + (i % 5) * 18), "%d  %s" % (i + 1, name), fill=STONE, font=small)
img.save(sys.argv[1] if len(sys.argv) > 1 else "plan.png")
