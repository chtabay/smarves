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
5. `exporter_ecrans.mjs <sortie> <références>` découpe, avec le code de dessin de l'original, les pièces des écrans
   que le portage redessine en direct (afficheur du jackpot, mur des tournois du poker, décalages des lignes de
   base des écrans des paris) et capture les images de référence qui servent à les vérifier.
6. `exporter_tables.mjs <sortie>` relève les postes de jeu de l'original (`Casino.stations` : jeu, places, tables
   sous housse) dans `donnees/tables.json`.

Les noms de zones passés à `exporter_decor.mjs` portent le préfixe `zone-` (la liste est dans `donnees/rendu.json`).
Une texture du décor change de nom quand son contenu change : après un nouvel export, reporter les nouveaux noms
dans les `TEX_*` d'ecrans.gd. Les dix-neuf images de la DA sont dans la bibliothèque (`matieres-de-minuit@1`, socle 1.17) :
après un nouvel export, `python3 -I vers_bibliotheque.py <decor> <empreinte>=<nom> …` les retire des zones (chaque
matière qui en portait une la nomme dans ses extras, « matiere », et son image devient `tex/matiere.png`, un pixel
blanc que `decor.gd` remplace au chargement), puis on efface leurs copies de `decor/tex/`.

Les scripts attendent la source de l'original dans `/mnt/project-files/casino-minuit/source` et, dans `vendor/`
(ou le dossier que nomme la variable `MINUIT_VENDOR`),
ce que la page charge d'un CDN : `three.min.js` (r128), `GLTFLoader.js`, `SkeletonUtils.js`, `cannon.min.js`
(0.6.2), `fonts.css` et `fonts/` (Limelight, Barlow, Cinzel). `vendor/GLTFExporter.js` est celui de three r128,
corrigé pour les DataTexture (tableau converti en `Uint8ClampedArray`, données absentes tolérées).
Les polices sont servies avec l'en-tête CORS : sans lui, le navigateur les refuse en silence et dessine les
textures avec une police de secours. Un export qui montre une police sans empattement à la place de Limelight
sur le jackpot est à refaire.

Ensuite, côté Godot : régler l'import de `decor/*.glb` (sans tangentes, sans LOD, sans maillage d'ombre) et de
`decor/tex/*.png` (sans perte, sauf les surfaces unies que `SURFACES` compresse pour la carte graphique ; avec mipmaps,
bornées à 1024 px quand les deux côtés en ont au moins autant) et
de `decor/ecrans/*.png` (sans perte, sans mipmaps) avec `python3 -I regler_import.py <decor>`, réimporter
(`godot --headless --import`), puis emballer comme d'habitude. Le monde des PNJ s'exporte compressé :
`node exporter_pnj.mjs <paquet>/donnees/pnj_monde.json.gz …` (le paquet le lit par `Atelier.donnees`).
