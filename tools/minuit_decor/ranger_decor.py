# Range les .glb exportés de l'original : images sorties vers un dossier commun (une par contenu), attributs
# inutiles retirés (UV sans texture, normales sans lumière), sommets identiques fusionnés (indices), tampon compacté.
import json, struct, hashlib, sys, os, glob
src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst + '/tex', exist_ok=True)
# Les textures de l'original telles que le navigateur les donne au GPU (exporter_textures.mjs) : l'export glTF
# repasse chaque image par un canvas, qui arrondit d'un niveau les pixels à demi transparents. Une image du
# .glb qui ne s'en écarte que de cet arrondi est remplacée par celle de l'original, retournée comme le veut le glTF.
from PIL import Image, ImageOps, ImageChops
import io
ORIG = {}
if len(sys.argv) > 3:
    for g in glob.glob(sys.argv[3] + '/*.png'):
        im = Image.open(g).convert('RGBA'); ORIG.setdefault(im.size, []).append(im)
def fidele(data):
    im = Image.open(io.BytesIO(data)).convert('RGBA')
    for o in ORIG.get(im.size, []):
        r = ImageOps.flip(o)
        if max(e[1] for e in ImageChops.difference(im, r).getextrema()) <= 1:
            out = io.BytesIO(); r.save(out, 'PNG', optimize=True); return out.getvalue()
    return data
CT = {5126: ('f', 4), 5123: ('H', 2), 5125: ('I', 4), 5121: ('B', 1)}
NC = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}

def lire(js, b, i):
    a = js['accessors'][i]; v = js['bufferViews'][a['bufferView']]
    c, t = CT[a['componentType']]; n = NC[a['type']]
    o = v.get('byteOffset', 0) + a.get('byteOffset', 0); st = v.get('byteStride', t * n)
    return [b[o + k * st: o + k * st + t * n] for k in range(a['count'])], a

for f in sorted(glob.glob(src + '/*.glb')):
    b = open(f, 'rb').read()
    jl = struct.unpack('<I', b[12:16])[0]
    js = json.loads(b[20:20 + jl])
    bin_ = b[20 + jl + 8:] if len(b) > 20 + jl else b''
    neuf, vues, accs = bytearray(), [], []
    def ajoute(data, cible=None):
        while len(neuf) % 4: neuf.append(0)
        v = {'buffer': 0, 'byteOffset': len(neuf), 'byteLength': len(data)}
        if cible: v['target'] = cible
        neuf.extend(data); vues.append(v); return len(vues) - 1
    for im in js.get('images', []):
        if 'bufferView' in im:
            bv = js['bufferViews'][im['bufferView']]
            data = bin_[bv.get('byteOffset', 0): bv.get('byteOffset', 0) + bv['byteLength']]
            data = fidele(data)
            h = hashlib.sha1(data).hexdigest()[:16]
            p = f'{dst}/tex/{h}.png'
            if not os.path.exists(p): open(p, 'wb').write(data)
            del im['bufferView']; im['uri'] = f'tex/{h}.png'
    mats = js.get('materials', [])
    for m in js.get('meshes', []):
        for p in m['primitives']:
            mt = mats[p['material']] if 'material' in p else {}
            tex = 'baseColorTexture' in mt.get('pbrMetallicRoughness', {}) or 'emissiveTexture' in mt
            attrs = dict(p['attributes'])
            if not tex: attrs.pop('TEXCOORD_0', None)
            if 'KHR_materials_unlit' in mt.get('extensions', {}): attrs.pop('NORMAL', None)
            noms = sorted(attrs)
            cols = {k: lire(js, bin_, attrs[k]) for k in noms}
            n = len(cols['POSITION'][0])
            ordre = [int.from_bytes(x, 'little') for x in lire(js, bin_, p['indices'])[0]] if 'indices' in p else range(n)
            vus, sommets, idx = {}, [], []
            for k in ordre:
                cle = b''.join(cols[a][0][k] for a in noms)
                if cle not in vus: vus[cle] = len(sommets); sommets.append(k)
                idx.append(vus[cle])
            nouv = {}
            for a in noms:
                vals, acc = cols[a]
                data = b''.join(vals[k] for k in sommets)
                na = {kk: acc[kk] for kk in ('componentType', 'type', 'normalized') if kk in acc}
                na['count'] = len(sommets); na['bufferView'] = ajoute(data, 34962)
                if a == 'POSITION':
                    xs = [struct.unpack('<3f', vals[k]) for k in sommets]
                    na['min'] = [min(v[i] for v in xs) for i in range(3)]; na['max'] = [max(v[i] for v in xs) for i in range(3)]
                accs.append(na); nouv[a] = len(accs) - 1
            p['attributes'] = nouv
            grand = len(sommets) > 65535
            data = struct.pack('<%d%s' % (len(idx), 'I' if grand else 'H'), *idx)
            accs.append({'componentType': 5125 if grand else 5123, 'type': 'SCALAR', 'count': len(idx), 'bufferView': ajoute(data, 34963)})
            p['indices'] = len(accs) - 1
    # les accesseurs hors maillage (animations, peaux) : aucun dans l'export ; on s'en assure
    assert not js.get('animations') and not js.get('skins')
    js['accessors'], js['bufferViews'] = accs, vues
    while len(neuf) % 4: neuf.append(0)
    js['buffers'] = [{'byteLength': len(neuf)}]
    jb = json.dumps(js, separators=(',', ':')).encode()
    while len(jb) % 4: jb += b' '
    out = b'glTF' + struct.pack('<II', 2, 12 + 8 + len(jb) + 8 + len(neuf)) + struct.pack('<I', len(jb)) + b'JSON' + jb + struct.pack('<I', len(neuf)) + b'BIN\x00' + bytes(neuf)
    open(dst + '/' + os.path.basename(f), 'wb').write(out)
print('images', len(glob.glob(dst + '/tex/*.png')))
