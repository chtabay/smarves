# Lenteur du jeu

Mesures du 22 octobre 2026 (Godot 4.7.2), après « le jeu met du temps à charger, rame parfois, et sur ordinateur semble prendre toutes les ressources de la machine ». Outil : `tools/mesure_lenteur.gd` ; vérification : `tools/test_lenteur.gd`.

## Ce qui coûtait

- **La cadence n'avait pas de plafond.** Avec la synchronisation verticale, le jeu dessinait autant d'images que l'écran en affiche : 60 sur un écran ordinaire, 144 ou 165 sur un écran rapide, chaque image avec l'éclairage indirect (SDFGI, SSIL), le brouillard volumétrique et, au casino, les reflets. Fenêtre en arrière-plan ou derrière une autre, il continuait au même rythme. C'est ce qui faisait tourner la carte graphique à plein.
- **Aucun réglage de qualité.** Chaque lieu allumait tous les effets, sur tous les ordinateurs.
- **« Jouer » rebâtissait le village.** L'écran titre construit déjà toute la place (façades, rues, habitants) pour la faire tourner en fond, puis « Jouer » la jetait et la reconstruisait : 1,7 à 2,1 s de plus.
- **Les ambiances sonores se calculaient pendant les chargements.** Seize secondes de son, 350 000 échantillons en GDScript, au premier passage sur la place puis au casino : 0,9 s au casino (davantage sur téléphone).
- **Les textures de bruit de la place** (pierre, pavés, murs, herbe, gravier, asphalte, terre : douze images 512 × 512) étaient recalculées à chaque retour sur la place.

Les scripts, eux, ne coûtent presque rien : moins de 1,2 ms par image dans le lieu le plus peuplé (le casino, 96 figurants), et aucune vue hors écran ne se redessine à chaque image (elles sont toutes en `UPDATE_ONCE`).

## Ce qui change

- **60 images par seconde au plus**, 30 en qualité légère, et **10 quand la fenêtre n'a pas le focus** (sauf sur téléphone, où le système met l'application en pause). Sur un écran à 144 Hz, la carte graphique travaille 2,4 fois moins ; en arrière-plan, six fois moins qu'à 60 images/s.
- **Réglages, « Qualité de l'image »** : Haute, Équilibrée, Légère. Le réglage s'applique à chaque lieu qui arrive (`Settings._sur_noeud`), sans toucher aux scripts des lieux, et se garde dans `user://reglages.cfg`.
  - *Haute* : le jeu tel qu'il était (les valeurs du projet).
  - *Équilibrée* (par défaut sur ordinateur) : les mêmes effets, moins chers : éclairage indirect calculé à demi-résolution et lampes mises à jour moins souvent, brouillard sur une grille plus lâche et sans filtre, occlusion et rebond d'écran en qualité basse, reflets limités à 24 pas et sans flou des surfaces rugueuses, ombres douces un cran plus bas.
  - *Légère* (par défaut sur téléphone et dans le navigateur) : sans éclairage indirect, rebond d'écran, brouillard ni reflets, rendu 3D à 75 % agrandi par FSR, sans anticrénelage, 30 images/s.
- **« Jouer » reprend le village de l'écran titre** (`main.gd`, `quitter_vitrine`) : son interface reparaît, l'habitant est posé, une caméra neuve prend la main, les bavardages et l'accueil reprennent, comme à une arrivée sur la place.
- **Les deux ambiances se calculent au lancement dans des fils à part** (`sfx.gd`) : identiques échantillon pour échantillon, prêtes avant qu'on en ait besoin.
- **Les textures de bruit sont gardées** d'un chargement du village à l'autre (`main.gd`, `_bruits`) : même graine, même image.

## Mesures

Chargements sans rendu (processeur seul, conteneur à 4 cœurs ; deux passages chacun) :

| | avant | après |
|---|---|---|
| Écran titre | 2,7 et 3,2 s | 2,4 et 2,4 s |
| « Jouer » | 1,7 et 2,1 s | 0,07 s |
| Casino | 4,0 et 4,5 s | 3,3 et 3,3 s |
| Retour sur la place | 2,0 et 1,8 s | 0,66 et 0,62 s |
| Salle de basket | 1,0 et 1,1 s | 1,0 et 1,0 s |

Du lancement à la place en jeu : 6,9 à 7,9 s avant, 4,9 à 5,0 s après sur ce conteneur.

Rendu : le conteneur n'a pas de carte graphique, seulement un rendu logiciel (lavapipe), où chaque image prend une seconde à 480 × 270 et où les effets d'écran pèsent peu (à si petite taille, c'est le nombre de lampes et d'objets qui domine). Temps d'image moyen : place 1,04 s avant, 0,99 s en haute, 0,65 s en légère ; casino 1,22 s avant, 1,18 s en haute, 1,13 s en équilibrée, 0,75 s en légère. Le gain de l'équilibrée sur une vraie carte graphique, en pleine définition, ne se mesure pas ici ; celui du plafond de cadence, si : il dépend seulement de la fréquence de l'écran.

## Ce qui reste

- Le casino se bâtit en 3,3 s : 1,6 s pour ses salles, 0,65 s pour fondre ses 6 100 pièces immobiles en 550 maillages (`static_batch.gd`). Bâtir la salle pendant un écran de chargement animé, comme les communes greffées (`Chargement`), ou garder le résultat de la fonte, seraient les prochaines étapes.
- Chaque retour sur la place reconstruit encore la rue du Clain et la route du bois (0,6 s) ; garder la place en mémoire pendant qu'on est dans une boutique ou au casino l'éviterait.
- La première visite d'un lieu compile ses shaders sur la carte graphique ; Godot les garde ensuite en cache, les visites suivantes sont plus rapides.
