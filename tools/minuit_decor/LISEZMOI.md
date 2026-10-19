# Le décor de Casino Minuit, tiré de l'original

Le paquet `casino_minuit` ne refait pas le décor de la version HTML : il le charge tel quel
(`decor/zone-<id>.glb`, `decor/tex/`). Ce dossier sert à le refaire et à le vérifier.

1. `exporter_decor.mjs <sortie> <zone-…,zone-…>` ouvre l'original (Three.js) dans Chromium, laisse de côté ce que
   le portage anime ou éclaire lui-même, cuit les maillages instanciés, marque les matières (`nt|` sans exposition,
   `add|` additive, `anim|genre|vx|vy|` texture qui défile) et exporte chaque zone en `.glb`.
2. `exporter_textures.mjs <sortie>` exporte chaque texture de la scène telle que le navigateur la donne au GPU
   (canvas et DataTexture), avec `materiaux.json`.
3. `python3 -I ranger_decor.py <sortie 1> <decor> <sortie 2>` sort les images vers `decor/tex/` (une par contenu),
   rend aux images les pixels exacts de l'original (le passage par un canvas de l'export glTF arrondit d'un
   niveau les pixels à demi transparents), retire les attributs inutiles, indexe les sommets.
4. `python3 -I verifier_textures.py <sortie 2> <decor>/tex <sortie 2>/materiaux.json` vérifie que toute texture du
   décor est une texture de l'original, au pixel près (le glTF les range tête-bêche).

Les scripts attendent la source de l'original dans `/mnt/project-files/casino-minuit/source` et, dans `vendor/`,
ce que la page charge d'un CDN : `three.min.js` (r128), `GLTFLoader.js`, `SkeletonUtils.js`, `cannon.min.js`
(0.6.2), `fonts.css` et `fonts/` (Limelight, Barlow, Cinzel). `vendor/GLTFExporter.js` est celui de three r128,
corrigé pour les DataTexture (tableau converti en `Uint8ClampedArray`, données absentes tolérées).

Ensuite, côté Godot : régler l'import de `decor/*.glb` (sans tangentes, sans LOD, sans maillage d'ombre) et de
`decor/tex/*.png` (sans perte, avec mipmaps), puis emballer comme d'habitude.
