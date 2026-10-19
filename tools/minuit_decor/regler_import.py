# Règle l'import Godot du décor (à lancer après un premier --import, puis réimporter) :
# textures sans perte avec mipmaps ; .glb sans tangentes, sans LOD, sans maillage d'ombre.
import sys, glob, re
decor = sys.argv[1]
for f in glob.glob(decor + '/tex/*.png.import'):
    t = open(f).read()
    t = re.sub(r'^compress/mode=\d', 'compress/mode=0', t, flags=re.M)
    t = re.sub(r'^mipmaps/generate=\w+', 'mipmaps/generate=true', t, flags=re.M)
    t = re.sub(r'^detect_3d/compress_to=\d', 'detect_3d/compress_to=0', t, flags=re.M)
    open(f, 'w').write(t)
for f in glob.glob(decor + '/*.glb.import'):
    t = open(f).read()
    for k in ('meshes/ensure_tangents', 'meshes/generate_lods', 'meshes/create_shadow_meshes'):
        t = re.sub('^' + k + r'=\w+', k + '=false', t, flags=re.M)
    open(f, 'w').write(t)
