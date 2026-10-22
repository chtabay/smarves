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

## La scène gardée (22 octobre 2026)

« Pourquoi le chargement d'une ville se refait-il à chaque fois complètement ? » Parce que les lieux se bâtissent dans le code, pièce par pièce, et que Godot jette la scène qu'on quitte : revenir sur la place depuis une boutique ou le casino la rebâtissait entière, et de même pour une commune en paquet au retour d'une de ses salles.

Désormais (`Chargement.lieu` et `Chargement.changer`, socle) la scène qu'on quitte pour un de ses lieux (boutique, casino, salle de jeu, étude, prestation, Cercle, logement) reste dans l'arbre, cachée et à l'arrêt : ni dessin, ni scripts, ni physique, son environnement sorti de l'arbre le temps de la visite. Au retour, elle reprend telle qu'on l'a laissée, l'habitant devant la porte (sur la place, il se retourne vers la rue), avec son ambiance, sa caméra et les autres joueurs connectés.

- Une seule scène gardée à la fois, pour une seule visite : un deuxième changement de scène sans retour la libère. La mémoire en plus est donc celle d'un lieu, téléphone compris.
- Elle ne revient pas si la partie a changé ce qu'elle montre et qu'elle ne remet pas à jour d'elle-même : un seuil de gagné au jeu passé dans sa commune (lieux, structures et, sur la place, prestations) ou un bien du joueur (achat, tenue, véhicule, logement). Elle se rebâtit alors comme avant. Une scène peut donner sa signature (`signature_garde`) et se remettre à jour au retour (`revenir`).
- Retour sur la place depuis le casino : 44 à 51 ms au lieu de 0,6 s (et 1,8 à 2,0 s avant le 22 octobre).

## Le lieu construit une fois, puis sauvegardé (22 octobre 2026)

Les lieux se bâtissent dans le code à chaque ouverture, et une part de ce travail ne dépend que du code : il donne le même résultat à chaque lancement. Cette part se fait désormais une fois, et son résultat reste sur l'appareil (`user://cache/`, `scripts/socle/memo.gd`) ; les lancements suivants le relisent. Chaque famille a son dossier, par empreinte du script qui fabrique la valeur : un script modifié jette ce qu'il avait calculé, et les versions précédentes sont effacées au premier passage.

- **Les figurines** (`critter_mesh.gd`) : six mille triangles par habitant, sommet par sommet en GDScript, 14 ms chacun, 26 à 48 par lieu. Relus en moins d'une milliseconde. 7,6 Mo pour les 108 fiches rencontrées sur la place, au casino et à la salle de basket.
- **Les textures de bruit** (`Memo.bruit`) : le moteur calcule une `NoiseTexture2D` à la première image, sur le fil principal, 80 ms pour 512 × 512 ; la place en a douze, soit **une seconde entre la fin de sa construction et sa première image**, qu'aucune mesure de script ne montrait. La première fois elle sert telle quelle et ses pixels sont rangés dès qu'ils sont prêts ; ensuite c'est l'image rangée (7 Mo pour la place). Même chose pour l'acajou et le feutre du casino, le grain et le cuir du kit des jeux.
- **Les images peintes pixel par pixel** (`Memo.image`) : les six tableaux du casino, la rose des vents, les faces des dés (100 000 pixels) : 130 ms au casino.
- **La fonte des pièces immobiles** (`static_batch.gd`) se fait dans le moteur (`SurfaceTool.append_from`) et non plus sommet par sommet : 0,65 s → 0,2 s au casino, 550 lots identiques au triangle et au format près. Les boîtes, sphères et cylindres de mêmes dimensions partagent désormais un même maillage.
- **Les scripts du casino** mettent 0,65 s à se compiler à l'entrée (les 24 scripts du lieu et des jeux, dont `casino_interior.gd` seul 0,35 s). La place les lit d'avance dans un fil (`Chargement.chauffer`), pendant qu'on la regarde.

Chargements sans rendu, même conteneur, au second lancement (le premier construit et range) :

| | 22 octobre, matin | après |
|---|---|---|
| Écran titre (construction + première image) | 2,4 s | 0,9 et 1,0 s |
| « Jouer » | 0,07 s | 0,06 s |
| Casino | 3,3 s | 1,7 et 1,9 s |
| Retour sur la place (rebâtie) | 0,66 s | 0,76 s |
| Salle de basket | 1,0 s | 0,5 s |

Sur téléphone, où le GDScript et le calcul du bruit sont trois à quatre fois plus lents, le gain est d'autant plus grand ; le premier lancement y reste long, et c'est le prix de la méthode. Les fichiers rangés se refont d'eux-mêmes si on les supprime.

## Ce qui reste

- Le casino se bâtit encore en 1,7 s : ses salles (0,35 s), ses tables (la roulette 85 ms, le Grand Hasard 170), ses étiquettes et ses lustres. Les bâtir pendant un écran de chargement animé, comme les communes greffées (`Chargement`), serait la prochaine étape.
- Les paquets des communes (Civaux, Minuit…) ont leurs propres textures et figurines : le même rangement leur servirait, voir [BIBLIOTHEQUE.md](BIBLIOTHEQUE.md) pour le budget par lieu.
- La première visite d'un lieu compile ses shaders sur la carte graphique ; Godot les garde ensuite en cache, les visites suivantes sont plus rapides.
