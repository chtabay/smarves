# Les personnages de Smarves

Direction artistique et animation des habitants, du personnel du casino et du joueur. Planches : [`captures/personnages.jpg`](captures/personnages.jpg) (distribution et tenues), [`captures/personnages-gestes.jpg`](captures/personnages-gestes.jpg) (gestes).

## La famille

Des adultes de bande dessinée, en **ligne claire** (la veine de Spirou ou de Tintin) : proportions d'adulte, la tête vers un sixième de la hauteur, yeux en point, nez qui signe le visage, aplats de couleur et contour noir. Le décalage vient des couleurs franches de figurine de maquette face aux jeux d'argent, jamais d'un ton d'enfant : le public visé a de 30 à 45 ans. Hauteur commune d'environ 0,7 (avant échelle de scène). Chaque personnage se reconnaît d'abord à sa coupe ou à son chapeau et à la couleur de ses épaules, ce qui se lit de dessus, puis à son nez, sa carrure et son accessoire.

- **Palette.** Le village est en couleurs de terroir (brique, moutarde, vert bouteille, bleu de travail, crème). Le casino est sobre et classe : noir, blanc cassé, bordeaux, or. Teints et cheveux en aplats (`Cast.PEAU`, `Cast.CHEVEUX`) ; les cheveux gris restent plus foncés que la peau pour qu'une tête ne paraisse pas chauve de loin.
- **Matière.** Un seul matériau partagé (`shaders/critter.gdshader`) : couleur peinte par sommet, rugosité par pièce, éclat pour les lunettes et les dorures. Le contour noir est une seconde passe (`shaders/critter_outline.gdshader`, coque inversée), d'environ 2,5 pixels pour un écran de 1080 de haut quelle que soit la distance ; les yeux, sourcils et bouche en sont exclus par l'alpha de la couleur.
- **Visage.** Coupes (`hair`) : court, raie, houppe, gomina, dégarni, chauve, brushing, carré, permanente, chignon, queue, frange. Nez (`nose`) : rond, patate, long, busqué, retroussé, avec `nose_red` pour les nez de comptoir. Pilosité (`face`) : moustache, barbe, favoris, bouc.
- **De loin**, au cran Quartier de la caméra (plus de 30 u), chaque personnage nommé porte une pastille de la couleur de son chapeau ou de sa veste, cerclée de noir (`Villager._add_badge`).
- **Les figures animales** d'avant le 17 octobre restent dans `critter_mesh.gd` mais ne sont plus accessibles : les personnages n'ont plus de propriété `species`, seulement une fiche `Cast`.

## Distribution

Les fiches suivent la section 7 de la bible.

| Personnage | Ce qui le signe |
|---|---|
| le joueur, le nouveau venu | la trentaine, roux, raie, costume bleu nuit, nœud papillon or (ou la tenue achetée) |
| l'Inconnu | cheveux gris, moustache, trench gris, feutre noir, le même nœud or |
| Josiane | permanente blonde, robe rose, tablier, perles |
| Dédé | casquette rouge, moustache, nez rouge, blouson de skaï, gobelet de 421 |
| Lucien | chapeau de paille, lunettes rondes, gilet moutarde, carnet |
| M. Brunet | raie sur le côté, trois-pièces gris, cravate bordeaux, chaîne de montre, mallette |
| Mme Ferrand | permanente brune, blouse blanche, tablier bleu, baguette |
| M. Gaudin | dégarni, rond, blazer vert, nœud rouge, micro |
| le gardien du bois | veste de chasse, feutre à plume, canne |
| le meunier | cheveux blancs, moustache, tablier de toile, casquette farinée |
| Monsieur Castel | cheveux blancs gominés, smoking blanc |
| Monsieur Armand | gomina noire, fine moustache, queue-de-pie, gants blancs |
| Maître Garnier | chauve, costume noir, lunettes dorées, mallette |
| Raymonde Chauvet | carré, robe lavande, mètre ruban au cou, lunettes, fleur |
| Roger Fradin | moustache, bleu de travail, casquette, clé plate |
| Ginette Boutin | permanente grise, robe-gilet vert sauge, demi-lunes dorées, sac |

Les croupiers sont un peu plus menus que les autres (`Villager.CROUPIER_SCALE`, 80 %) pour ne pas boucher la vue du joueur assis. Le personnel du casino (croupiers en gilet noir et badge, hôtesses en bordeaux et calot, caissier à visière verte, barmans, pianistes) et les figurants sont tirés de `Cast.resolve()` : même nom de modèle et même place donnent toujours le même habitant.

## Animation

Squelette commun de 28 os, une `AnimationTree` partagée (bibliothèque et graphe communs), sans `AnimationPlayer`.

- **Bases** : repos, attentif, debout à table, mains dans le dos, au bar, chante, marche, court, assis, assis à table, au piano. La marche suit la vitesse réelle.
- **Gestes** (haut du corps, par-dessus la base) : parle, salue, joie, dépit, haussement d'épaules, applaudit, mise, donne une carte, lance la bille, ratisse, distribue les jetons, acquiesce, révérence, se gratte la tête, regarde l'heure, boit, montre, se prend la tête. **Corps entier** : saute de joie, tape du pied.
- **Visage** : clignements, sourire et moue, sourcils (joie, dépit, surprise, attention), bouche qui parle.
- **Comportements** (`villager.gd`) : tourne la tête vers le joueur qui approche, puis le corps s'il s'attarde ; bavarde avec un voisin ; petites manies ; promenade avec pauses ; suit des yeux sa table (`watch`). Au casino, le croupier lance la bille, donne les cartes et ramasse les dés, puis ratisse les mises perdues ou distribue les gains ; le public proche réagit à chaque coup (`Villager.crowd_react`, `Villager.dealer_gesture`).
- **Coût** : maillage mis en cache par allure, animation mise à jour moins souvent quand le personnage est loin ou hors champ.

## Ajouter un personnage ou une tenue

- Un personnage nommé : une entrée dans `Cast.NAMED` (`"species": "humain"`, teint dans `fur`, coupe, nez, haut, bas, chapeau, cou, visage, accessoires), puis sa clé dans `BY_SPEAKER` ou `BY_MODEL`.
- Une tenue du joueur : une entrée dans `Cast.PLAYER_OUTFITS` dont la clé est l'`id` de la tenue dans `Biens`. La tenue portée (`Biens.worn`) habille le nouveau venu, et elle change dès qu'on en achète une autre.
- Vérifier : `godot --path . tools/lineup.tscn -- --capture=out.png` avec `--part=0|1|2`, `--tenues`, `--top`, `--rue` ou `--quartier` (les crans de caméra de la suite, 18 u et 40 u), `--close` ou `--moves --only=wave,jump`.

## Ressources

Tout est fabriqué par le code (`scripts/critter_mesh.gd`, `scripts/critter_anims.gd`). Aucun modèle, texture ni animation n'a été téléchargé, donc aucune licence n'est à citer.
