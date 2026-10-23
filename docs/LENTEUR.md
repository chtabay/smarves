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

## Le budget par lieu (22 octobre 2026, socle 1.16)

Une fois bâti, un lieu demande à la carte graphique un nombre de triangles, de surfaces dessinées, de lampes (chaque lampe à ombres redessine la scène), de textures en mémoire ; au processeur un nombre de nœuds et de scripts qui tournent à chaque image. Ce sont ces nombres qui font ramer un téléphone, plus que le temps de construction, et personne ne les voyait. La classe **`Budget`** (`scripts/socle/budget.gd`) les compte sur une scène dans l'arbre, et porte les seuils du socle, calés sur le casino de Smarves, le lieu le plus chargé qui tourne sur téléphone :

| | seuil |
|---|---|
| triangles dessinés au regard le plus chargé (multimaillages compris ; voir « Ce qui est vraiment dessiné ») | 600 000 |
| surfaces dessinées | 2 500 |
| lampes | 80 |
| lampes à ombres | 8 |
| textures uniques | 96 Mo |
| nœuds | 8 000 |
| scripts actifs | 250 |
| étiquettes (`Label3D`) | 250 |

Rien ne refuse un lieu : on dit ce qui dépasse, dans les mots des auteurs (« 968 512 triangles (au plus 600 000) »).

- `tools/budget_lieu.gd` mesure les lieux de Smarves, des scènes, ou les lieux d'un paquet (`--pck=`), et écrit la mesure en JSON (`--json=`).
- **L'emballeur** (`tools/emballer_commune.gd`) bâtit chaque lieu du manifeste (la scène de la commune, celles de ses structures : `scene`, `habillage`, `modele`), le mesure, dit ce qui dépasse, et range la mesure dans le paquet (`communes/<id>/budget.json` : `socle`, `seuils`, `lieux`).
- **Le portail** (Pyramides2, `src/lib/communes/paquet.ts`, `budgetDesLieux`) lit ce fichier à la soumission et le dit lieu par lieu, sans refuser : « Budget : 2 lieu(x) dans les seuils du socle, 1 au-delà. », puis « Budget de dome.tscn : 968 512 triangles, … À alléger : … ». Un paquet sans ce fichier vient d'un emballeur d'avant le socle 1.16 : la page demande de le refaire avec le SDK à jour.

Les lieux de Smarves, mesurés par l'outil (`tools/budget_lieu.gd`, 22 octobre 2026, objets lointains déjà simplifiés) :

| lieu | triangles | surfaces | lampes (à ombres) | textures | nœuds | scripts actifs | étiquettes |
|---|---|---|---|---|---|---|---|
| La place (`main.tscn`) | 392 309 | 1 122 | **110** (1) | 63,5 Mo | 2 508 | 72 | 159 |
| Casino | **774 516** | **2 804** | 65 (2) | 74,7 Mo | 4 455 | 124 | 69 |
| Salle de basket | **920 360** | 449 | 35 (1) | 6,0 Mo | 2 581 | 28 | 74 |
| Stade | 180 170 | 253 | 12 (1) | 0,0 Mo | 537 | 33 | 15 |
| Café | 26 812 | 117 | 8 (2) | 6,3 Mo | 225 | 6 | 4 |
| Salle de jeu | 12 574 | 124 | 6 (2) | 2,0 Mo | 185 | 4 | 4 |
| Commerce | 7 116 | 32 | 4 (2) | 0,7 Mo | 81 | 3 | 1 |

En gras ce qui dépasse : les seuils sont une cible, et trois lieux de Smarves la manquent encore (la foule de la salle de basket, les tables et les lustres du casino, les lampes de la place). Les textures du casino sont pour l'essentiel les tapis de ses tables, dessinés dans un `SubViewport` à 600 px par mètre (voir « Ce qui reste »).

## Les objets lointains (22 octobre 2026, socle 1.16)

Les lieux dessinent de près ce qu'on voit de loin. Deux remèdes, appliqués par `Chargement` à chaque scène 3D qui arrive sous la racine, une fois bâtie, sans que les lieux aient rien à faire (classe **`Lointain`**, `scripts/socle/lointain.gd` ; une scène qui tient à ses primitives fines pose la méta `sans_lointain` sur sa racine) :

- **Les primitives à leur taille vue.** Les sphères, cylindres, capsules et tores de Godot sont très fins par défaut : une perle de lustre de 3 cm en sphère 64 × 32 fait 4 000 triangles, et le casino en a trois cents. `Lointain.simplifier` ramène leurs segments à ce que l'œil voit à leur taille réelle, la plus grande de leurs instances (12 segments sous 12 cm de rayon, 20 sous 40 cm, 32 au-delà) : 924 primitives au casino, en 40 ms.
- **Les niveaux de détail des gros maillages.** Un maillage de dix mille triangles et plus reçoit des niveaux de détail automatiques (`ImporterMesh.generate_lods`, meshoptimizer) : le moteur dessine celui dont l'erreur reste sous un pixel à l'écran, et de près c'est le même maillage. Un maillage par image est lu sur le fil principal (les maisons d'Availles, 1,6 million de triangles, demanderaient 0,6 s d'un coup), le calcul se fait dans un fil, et le maillage est remplacé quand il est prêt. Les figurines (`critter_mesh.gd`) naissent avec les leurs, rangées avec elles sur l'appareil.

| | triangles avant | après | primitives | maillages à niveaux |
|---|---|---|---|---|
| Casino | 2 404 436 | 774 516 | 924 | 48 figurines (146 876 triangles au premier niveau) |
| La place | 868 653 | 392 309 | | |
| Casino Minuit (scène) | 870 913 | 643 989 | | 20 (21 ms sur le fil principal) |
| Availles-Limouzine | | | | 11 (2 ms sur le fil principal, prêts après 4,6 s) |

La salle de basket ne change presque pas : ses triangles sont ceux de la foule (9 163 capsules en multimaillage, 660 000 triangles), que ce remède ne touche pas. `tools/test_lenteur.gd` vérifie la mesure, les seuils, la simplification, les niveaux et leur application automatique.

## Ce qui est vraiment dessiné (22 octobre 2026, soir)

Le budget comptait tout ce qui est visible, au niveau de détail le plus fin, comme si l'on voyait tout le lieu à la fois et de près : 323 000 triangles de figurines à Civaux, alors que ces figurines ont des niveaux de détail (`CritterMesh`) et que le moteur dessine les lointaines en quelques centaines de triangles. `Budget.mesurer` compte désormais ce que la carte graphique dessine :

- **D'où l'on regarde.** Les points de vue sont ceux où le joueur se tient : la caméra du lieu à l'arrivée (avec son inclinaison : la vue de dessus du village regarde le sol), les autres caméras, et chaque zone d'interaction (`Area3D` : portes, tables, habitants) à hauteur d'yeux ; pas deux à moins de 6 m, au plus 48. De chacun, huit regards font le tour (le champ de la caméra par défaut de Godot, 75° en 16:9). Le lieu compte pour le **regard le plus chargé** (`point_le_plus_charge` : position et direction).
- **Ce que le moteur garde.** Un objet entre dans le regard si sa boîte touche le champ ; au-delà de sa distance de visibilité (`visibility_range_end`, mesurée au centre de sa boîte), il ne compte pas ; un maillage à niveaux de détail compte au niveau que le moteur choisit à sa distance pour un écran de 1920 pixels (erreur sous un pixel, `rendering/mesh_lod/lod_change/threshold_pixels`).
- **`triangles_pleins`** et **`surfaces_pleines`** gardent l'ancien compte (tout, partout, au plus fin) ; le résumé les dit : « 570 844 triangles (743 100 au plus fin) ». Les seuils ne changent pas.
- **Comparé au moteur.** `L'Isle-Jourdain`, dix-huit regards rendus par Godot (1920 × 1080) et comptés par lui (`RENDER_INFO_PRIMITIVES_IN_FRAME`) : le budget est de 16 à 50 % au-dessus, jamais en dessous. Il prend la distance la plus courte jusqu'à la boîte quand le moteur en prend une un peu plus longue, et son champ est un peu plus large.
- **Sans rendu** (`--headless`), le moteur ne garde pas les instances d'un multimaillage (sa boîte est vide) : le multimaillage compte alors en entier, partout, au plus fin (`multimaillages_entiers`). Un lieu riche en multimaillages (bois, prairies, feuillages) se mesure plus juste avec rendu : l'emballeur ou `tools/budget_lieu.gd` lancés sans `--headless` (sur un serveur, sous `xvfb-run` avec `--rendering-driver opengl3`).
- `tools/budget_lieu.gd` et l'emballeur attendent que les niveaux de détail calculés dans un fil (`Lointain`) soient posés avant de mesurer.

Les lieux de Smarves, avec rendu (dessiné / au plus fin) :

| lieu | triangles dessinés | au plus fin | surfaces dessinées | textures |
|---|---|---|---|---|
| La place | 189 059 | 392 309 | 1 056 | 63,5 Mo |
| Casino | 570 844 | 743 100 | **2 628** | 74,7 Mo |
| Salle de basket | 213 538 | 340 616 | 360 | 6,0 Mo |
| Stade | 104 896 | 180 170 | 200 | 0,0 Mo |
| Café | 25 380 | 26 812 | 98 | 6,3 Mo |
| Salle de jeu | 10 558 | 10 726 | 113 | 2,0 Mo |
| Commerce | 6 972 | 7 116 | 23 | 0,7 Mo |

Le casino de Smarves repasse sous le seuil de triangles : on le comptait tout entier à la fois, ses 48 figurines au plus fin.

**Essayé et abandonné** : donner des niveaux de détail aux maillages de mille triangles (au lieu de dix mille) et aux arbres des multimaillages. Les villages y gagnaient 10 à 20 %, mais Godot choisit le niveau d'après la distance à un coin de la boîte du maillage, pas à sa surface : un mur fondu avec sa rue (une boîte de 40 m) se voyait simplifié à un mètre de la caméra, en aplat noir sur la capture. Le seuil de dix mille reste.

## Les tapis partagés (22 octobre 2026, soir)

Chaque table peignait son tapis dans sa propre vue hors écran (`SubViewport`, 600 à 700 px par mètre) : six blackjacks, six tapis identiques de 5,3 Mo. Les tapis et le cylindre de la roulette se demandent désormais au kit par une clé qui dit tout ce qui change le dessin (`KIT.vue_partagee`, `KIT.partager` : « blackjack », « baccara:MINUIT:false », « roue:(2.4, 0.62) ») ; la première table le peint, les suivantes reprennent la même texture. Les vues restent d'une scène à l'autre, comme les jetons et les cartes : revenir au casino ne repeint plus rien (avant, chaque visite ajoutait ses tapis sans libérer les précédents).

- Casino Minuit : 199,7 → **131,1 Mo** de textures (19 tables, 6 tapis distincts au lieu de 19). Les 90 Mo du décor de l'auteur restent : sous le seuil seuls, au-dessus avec les tapis.
- Casino de Smarves : ses tables sont toutes différentes, rien ne change (74,7 Mo).
- Vérifié pixel par pixel sur les 19 tapis de Minuit (images relues avec rendu) : 13 identiques à l'octet, les 6 blackjacks à un niveau sur 255 près sur quelques lettres de l'annonce en arc (l'ordre dans lequel la police met ses lettres en cache). La taille des tapis ne change pas : assis, on les voit à 600 à 900 px par mètre sur un écran de 1920.

## Les arbres lointains et le décor compressé de Minuit (22 octobre 2026, nuit)

**Les imposteurs.** `Lointain.imposteurs`, troisième remède appliqué par `Chargement`, prend les multimaillages d'arbres et de buissons (au moins 50 cm de haut, 48 triangles, une emprise à peu près ronde : une haie ou une rangée de vigne n'en est pas) et photographie une fois chaque maillage, sans lumière, dans une petite vue (256 px de haut). Le multimaillage est découpé en cellules de 30 m : chacune garde ses arbres jusqu'à 120 m (au centre de la cellule, à 4 m près pour ne pas clignoter), puis les remplace par des panneaux tournés vers la caméra, éclairés par la scène et sans ombre. À 120 m, un arbre de 10 m fait une soixantaine de pixels de haut. De près, rien ne change ; sans rendu (`--headless`), rien ne change non plus, faute de photo. Les feuilles de quelques triangles et les troncs ne sont pas pris : le panneau n'y gagnerait presque rien.

| Commune | triangles dessinés avant | après |
|---|---|---|
| Civaux | 1 415 808 | 775 596 |
| L'Isle-Jourdain | 1 782 390 | 1 288 998 |
| Cloué | 1 014 252 | 893 471 |

**Le décor de Minuit.** Les matières de la DA (bibliothèque) et les surfaces unies du décor (sols, ciels, façades, murs, une frise) sont compressées pour la carte graphique (S3TC sur ordinateur, ETC2 sur téléphone : quatre à huit fois moins de mémoire) ; les enseignes, les néons, le texte, les tapis et les roues restent sans perte. La liste est dans `tools/minuit_decor/regler_import.py`. Le casino de Minuit passe de 131 à 94,9 Mo de textures, sous le seuil de 96 Mo.

## Ce qui reste

- Le casino se bâtit encore en 1,7 s : ses salles (0,35 s), ses tables (la roulette 85 ms, le Grand Hasard 170), ses étiquettes et ses lustres. Les bâtir pendant un écran de chargement animé, comme les communes greffées (`Chargement`), serait la prochaine étape.
- La foule du Dôme de Minuit pendant un match (Guillaume la garde telle quelle). Les 110 lampes de la place (les réverbères et les fenêtres), les 2 600 surfaces du casino.
- Les arbres proches des villages (Cloué 0,9 M triangles dessinés, Civaux 0,8 M, imposteurs compris ; L'Isle-Jourdain, voir plus bas) : des feuilles séparées que les niveaux de détail ne savent pas simplifier sans perte. Moins de feuilles plus grandes, ou des imposteurs plus près, se verraient : ce sont des choix d'auteur.
- Les paquets des communes (Civaux, Cloué…) ont leurs propres textures et figurines : le même rangement (`Memo`) leur servirait. Chaque paquet est repris une fois par ses auteurs, avec le budget que l'emballeur leur dit (Minuit et L'Isle-Jourdain : fait, plus bas).
- Si le téléphone peine encore, la lumière précalculée (`LightmapGI`) pour les lieux fixes.
- La première visite d'un lieu compile ses shaders sur la carte graphique ; Godot les garde ensuite en cache, les visites suivantes sont plus rapides.

## Minuit et L'Isle-Jourdain repris avec le SDK à jour (23 octobre 2026)

Les deux paquets refaits par l'emballeur du socle (avec rendu, `xvfb-run`, `--rendering-driver opengl3`) :

| Lieu | Triangles dessinés | Surfaces | Lampes (à ombres) | Textures | Dépasse |
|---|---|---|---|---|---|
| Minuit 0.10.5, casino | 567 271 | 2 132 | 16 (0) | 94,9 Mo | non |
| Minuit 0.10.5, stade de la Fortune (décor seul) | 303 352 | 330 | 30 (0) | 1,3 Mo | non |
| Minuit 0.10.5, Dôme hors match | 242 432 | 420 | 37 (1) | 6,0 Mo | non |
| L'Isle-Jourdain 0.2.2 | **1 288 998** | 668 | 16 (2) | 13,4 Mo | triangles |
| L'Isle-Jourdain 0.2.3 | 596 868 | 901 | 16 (2) | 13,8 Mo | non |

Les textures de Minuit étaient déjà sous le seuil depuis la 0.10.2 (décor compressé pour la carte graphique). La Fortune passe par ses ancres sans changer de budget.

**L'Isle-Jourdain 0.2.3** (le paquet de l'Atelier de la Vienne, repris ici : `paysage.gd` et `atelier.gd`). Le regard le plus chargé est dans le bourg, entouré de jardins et de bois : les arbres comptaient 9 000 à 13 000 triangles chacun jusqu'à 120 m, où le socle les remplace par leurs images.
- Chaque modèle de plante (les six arbres, le fruitier, les six bouquets des massifs, des haies et du bocage, l'herbe et les fleurs des prairies) porte deux niveaux de détail construits avec lui, que le moteur prend de lui-même : vers 18 m, chaque feuille devient un losange de deux triangles (six pour l'ovale), de même surface, les tiges de moins de 3 cm s'effacent et les autres perdent des facettes, l'herbe passe à deux tronçons ; vers 50 m, une feuille sur deux, deux fois plus grande, le tronc et les branches maîtresses, l'herbe à un tronçon. Un arbre : 8 932 → 3 074 → 1 310 triangles.
- Les plantations sont rangées en cellules de 12 m (24 avant) : le moteur choisit le niveau d'après le bord de la cellule, et une grande cellule gardait au plus fin des arbres lointains.
- Les cylindres et les boules fondus dans la géométrie groupée prennent les segments que le socle donne aux primitives qui restent (12 sous 12 cm de rayon, 20 sous 40 cm).
- La rivière : des mailles de 3 × 5 m au lieu de 1,5 × 2,5 (sa houle fait 2 cm).
- Comparé sur quatre points de vue (vue de dessus, à pied, en se retournant) : de près rien ne change ; au loin, l'herbe est un peu plus fine. Le patch est dans le dossier du projet (`budget-paquets/`), pour l'auteur.
