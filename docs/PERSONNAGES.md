# Les personnages de Smarves

Direction artistique et animation des habitants, du personnel du casino et du joueur. Planches : [`captures/personnages.jpg`](captures/personnages.jpg) (distribution et tenues), [`captures/personnages-gestes.jpg`](captures/personnages-gestes.jpg) (gestes).

## La famille

Des figurines floquées de maquette, façon Happy Tree Friends en plus tendre : grosse tête (près de la moitié de la hauteur), grands yeux brillants, joues roses, corps en poire, petites jambes. Hauteur commune d'environ 0,75 (avant échelle de scène). Chaque personnage se reconnaît d'abord à sa silhouette (oreilles, chapeau, carrure), puis à sa couleur, puis à son accessoire, ce qui marche aussi bien vu de dessus qu'à hauteur d'yeux.

- **Palette.** Le village est en couleurs de terroir (brique, moutarde, vert bouteille, bleu de travail, crème). Le casino est sobre et classe : noir, blanc cassé, bordeaux, or. Les fourrures restent naturelles.
- **Matière.** Un seul matériau partagé (`shaders/critter.gdshader`) : couleur peinte par sommet, rugosité par pièce, léger velours sur les bords, éclat pour les lunettes et les dorures.
- **Les renards** sont réservés au joueur et à l'Inconnu (un renard plus âgé, en trench et feutre). Aucun figurant n'est un renard.
- **Espèces** : celles de la bible (section 7) pour les personnages nommés. Les figurants piochent aussi le chien, le blaireau, le hérisson et le sanglier, pour que la foule varie.

## Distribution

| Personnage | Espèce | Ce qui le signe |
|---|---|---|
| le joueur | renard | costume bleu nuit, nœud papillon or (ou la tenue achetée) |
| l'Inconnu | renard âgé | trench gris, feutre noir, moustache grise |
| Josiane | chatte crème | robe brique, tablier, chignon, perles |
| Dédé | ours brun | béret, marinière, gobelet de 421 |
| Lucien | lapin gris | gilet moutarde, casquette, lunettes, carnet |
| M. Brunet | castor | costume anthracite, cravate bordeaux, demi-lunes, chaîne de montre, mallette |
| Mme Ferrand | souris | robe bleue, tablier, nœud, baguette |
| M. Gaudin | ours miel | blazer vert, canotier, micro |
| le gardien du bois | lapin brun | veste loden, chapeau de chasse à plume, canne |
| le meunier | castor clair | chemise bleue, tablier à bavette, bonnet de meunier |
| Monsieur Castel | ours blanc | smoking |
| Monsieur Armand | chat noir et blanc | queue-de-pie, gants blancs, moustache |
| Maître Garnier | chat gris-brun | costume noir, lunettes dorées, mallette |
| Raymonde Chauvet | souris blanche | robe lavande, mètre ruban au cou, lunettes, fleur |
| Roger Fradin | ours | bleu de travail, casquette, clé plate |

Les croupiers sont un peu plus menus que les autres (`Villager.CROUPIER_SCALE`, 80 %) pour ne pas boucher la vue du joueur assis. Le personnel du casino (croupiers en gilet noir et badge, hôtesses en bordeaux et calot, caissier à visière verte, barmans, pianistes) et les figurants sont tirés de `Cast.resolve()` : même nom de modèle et même place donnent toujours le même habitant.

## Animation

Squelette commun de 28 os, une `AnimationTree` partagée (bibliothèque et graphe communs), sans `AnimationPlayer`.

- **Bases** : repos, attentif, debout à table, mains dans le dos, au bar, chante, marche, court, assis, assis à table, au piano. La marche suit la vitesse réelle.
- **Gestes** (haut du corps, par-dessus la base) : parle, salue, joie, dépit, haussement d'épaules, applaudit, mise, donne une carte, lance la bille, ratisse, distribue les jetons, acquiesce, révérence, se gratte la tête, regarde l'heure, boit, montre, se prend la tête. **Corps entier** : saute de joie, tape du pied.
- **Visage** : clignements, sourire et moue, sourcils (joie, dépit, surprise, attention), bouche qui parle.
- **Comportements** (`villager.gd`) : tourne la tête vers le joueur qui approche, puis le corps s'il s'attarde ; bavarde avec un voisin ; petites manies ; promenade avec pauses ; suit des yeux sa table (`watch`). Au casino, le croupier lance la bille, donne les cartes et ramasse les dés, puis ratisse les mises perdues ou distribue les gains ; le public proche réagit à chaque coup (`Villager.crowd_react`, `Villager.dealer_gesture`).
- **Coût** : maillage mis en cache par allure, animation mise à jour moins souvent quand le personnage est loin ou hors champ.

## Ajouter un personnage ou une tenue

- Un personnage nommé : une entrée dans `Cast.NAMED` (espèce, fourrure, haut, bas, chapeau, cou, visage, accessoires), puis sa clé dans `BY_SPEAKER` ou `BY_MODEL`.
- Une tenue du joueur : une entrée dans `Cast.PLAYER_OUTFITS` dont la clé est l'`id` de la tenue dans `Biens`. La tenue portée (`Biens.worn`) habille le renard, et elle change dès qu'on en achète une autre.
- Vérifier : `godot --path . tools/lineup.tscn -- --capture=out.png` avec `--part=0|1|2`, `--tenues`, `--top`, `--close` ou `--moves --only=wave,jump`.

## Ressources

Tout est fabriqué par le code (`scripts/critter_mesh.gd`, `scripts/critter_anims.gd`). Aucun modèle, texture ni animation n'a été téléchargé, donc aucune licence n'est à citer.
