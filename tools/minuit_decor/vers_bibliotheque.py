# Les images de la DA de Minuit (decor/tex/<empreinte>.png) passent à la brique matieres-de-minuit@1 de la
# bibliothèque (socle 1.17) : dans chaque zone .glb, une matière qui en portait une la nomme dans ses extras
# (« matiere »), et son image devient tex/matiere.png, un pixel blanc que decor.gd remplace au chargement par
# l'image de la bibliothèque. Les réglages de la matière (répétition, filtrage, décalage) ne changent pas.
#   python3 -I vers_bibliotheque.py <decor> <empreinte>=<nom> …   (les paires de DA_TEX, avant ce passage)
import json, os, struct, sys

decor = sys.argv[1]
table = dict(a.split("=") for a in sys.argv[2:])
PIXEL = "tex/matiere.png"
total = 0
for f in sorted(os.listdir(decor)):
    if not f.endswith(".glb"):
        continue
    p = os.path.join(decor, f)
    d = open(p, "rb").read()
    magic, ver, _ = struct.unpack("<4sII", d[:12])
    l, t = struct.unpack("<II", d[12:20])
    assert t == 0x4E4F534A, f
    j = json.loads(d[20:20 + l])
    reste = d[20 + l:]
    noms = {}
    for i, im in enumerate(j.get("images", [])):
        u = im.get("uri", "")
        h = os.path.basename(u)[:-4] if u.startswith("tex/") else ""
        if h in table:
            noms[i] = table[h]
            im["uri"] = PIXEL
    if not noms:
        continue
    n = 0
    for m in j.get("materials", []):
        bc = m.get("pbrMetallicRoughness", {}).get("baseColorTexture")
        if bc is None:
            continue
        src = j["textures"][bc["index"]].get("source")
        if src in noms:
            m.setdefault("extras", {})["matiere"] = noms[src]
            n += 1
    s = json.dumps(j, separators=(",", ":"), ensure_ascii=False).encode()
    s += b" " * ((4 - len(s) % 4) % 4)
    open(p, "wb").write(struct.pack("<4sII", magic, ver, 20 + len(s) + len(reste)) + struct.pack("<II", len(s), 0x4E4F534A) + s + reste)
    total += n
    print(f, n)
print("matières passées à la bibliothèque :", total)
