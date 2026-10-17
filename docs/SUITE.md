# La suite de Smarves : cadrage et architecture

Ce document dit où va Smarves après le prototype du village, et les choix d'architecture qui en découlent. Il part de la direction donnée par Guillaume le 17 octobre 2026 : un village à parcourir avec de l'exploration, comme la ville d'Addict Casino ; une vue extérieure plus dézoomée ; du housing ; du multi ; et, à terme, une carte de la Vienne où d'autres communes se greffent par des mods.

Chaque point donne une proposition tranchée, puis les alternatives écartées en une ligne. Rien ici n'est implémenté : c'est la feuille de route des prochains chantiers. La fiche de cadrage ([`CADRAGE.md`](CADRAGE.md)) reste la définition du jeu, la bible ([`BIBLE.md`](BIBLE.md)) celle du monde, et ces deux documents l'emportent en cas de doute.

Les règles qui ne bougent pas :

- **Rien ne change dans la première salle.** Le Café de la Place, la place de la Mairie et la salle des jeux du casino gardent leurs jeux, leurs règles et leurs seuils. Tout ce qui est nouveau s'ouvre par un seuil ou se trouve en marchant.
- **Le gameplay des jeux est en pause, le visuel passe d'abord.** Les nouveaux lieux sont d'abord du décor avec figurants ou des portes fermées, qu'on ouvrira plus tard par des seuils.
- **La morale reste au premier degré.** Elle sort des chiffres, jamais d'un personnage. Le housing et le multi suivent la même règle.
- **Le public a entre 30 et 45 ans.** Le ton est coloré et décalé face à l'argent, jamais enfantin. Les personnages sont des humains (fil « Personnages », ligne claire), il n'y a pas d'animaux.
- **Aucune migration de la base de production** sans l'accord explicite de Guillaume.

## En bref : l'ordre des chantiers

1. **La caméra dézoomée et la lisibilité** (personnages, toits, enseignes), parce que tout le reste se juge à cette distance.
2. **Le socle « commune »** : Smarves décrit par un manifeste, la sauvegarde rangée en tiroirs, sans aucun changement visible.
3. **Le village à parcourir** : la route du Bois, le chemin de Passelourdin, le plan du village qui se dévoile en marchant, les repères et les trouvailles.
4. **Le housing** : la chambre au-dessus du café habitable et meublable, puis les deux maisons.
5. **La carte de la Vienne** avec Smarves seule, puis une deuxième commune livrée en pack séparé pour éprouver la greffe.
6. **Le multi asynchrone** : compte Pyramides, visites de maisons, classements.
7. **Le multi en temps réel** : la soirée partagée sur la place, les tables à plusieurs, le poker de Passelourdin.

Le détail et l'impact sur les fils en cours sont à la section 6.

## 1. Le village à parcourir

### Ce qu'on vise

Le joueur sort du café et a envie d'aller voir ce qu'il y a au bout de la rue. Le village est une seule maquette continue, qu'on parcourt à pied (et plus tard avec sa Mobylette ou sa 2 CV), où chaque rue mène quelque part, où l'on voit de loin ce qu'on n'a pas encore atteint, et où l'on trouve des choses que personne n'a signalées.

### La boucle d'exploration

1. **On voit un repère de loin.** Chaque quartier a un repère qui dépasse des toits et se reconnaît en vue dézoomée : le clocher de Saint-Félix, l'enseigne « CASINO » allumée sur le toit du casino, l'érable rouge de la place, le château d'eau de la route du Bois, la roue du Moulin des Dames, les falaises de Passelourdin éclairées au-dessus des toits. Le repère dit « il y a quelque chose là-bas » sans dire quoi.
2. **On suit un chemin.** Les rues sont la seule chose qui guide : pas de flèche ni d'objectif à l'écran. Un panneau de bois aux carrefours, des plaques de rue émaillées, une guirlande d'ampoules qui continue au coin d'une rue.
3. **On découvre un lieu.** Trois sortes de lieux :
   - **les lieux de jeu**, qui s'ouvrent par leur seuil comme aujourd'hui (le tenancier fait signe ; avant le seuil, la porte est fermée et l'invite donne le montant) ;
   - **les lieux de décor**, ouverts à tous : le lavoir, la placette, le stade, l'école, la cabine de la poste, avec des figurants qui y vivent ;
   - **les lieux cachés**, qu'aucune liste n'annonce : une cour derrière un portail entrouvert, une cave à la porte basse, un jardin au bout d'une ruelle. Certains sont seulement trouvés en marchant, d'autres s'ouvrent par un seuil sans prévenir (la porte était fermée hier, elle est entrouverte aujourd'hui).
4. **La découverte rapporte, sans rien changer aux jeux.** Trouver un lieu caché inscrit une ligne au carnet, ajoute la rue au plan du village et donne souvent une rumeur ou une **trouvaille** : un objet de décor qu'on rapporte chez soi (le ticket de tiercé encadré de Dédé, la boule de pétanque gravée de Lucien, une affiche du loto de 1987). Les trouvailles ne valent aucun crédit, ne comptent pas dans « Gagné au jeu » et ne touchent à aucun seuil : elles servent au housing (section 3) et à la collection. Une trouvaille rare se montre aux visiteurs.

### Ce qu'on reprend d'Addict Casino

| Dans Addict | À Smarves |
|---|---|
| La minicarte où les rues n'apparaissent qu'une fois parcourues | **Le plan du village**, une page du carnet dessinée au crayon, qui se remplit à mesure qu'on marche ; les lieux de jeu y sont inscrits à l'encre quand ils sont ouverts |
| Les plaques de rue émaillées aux carrefours | les plaques, avec les vrais noms des rues du bourg quand ils existent |
| 212 bâtiments numérotés, fermés, chacun avec son lot et son adresse ; frapper donne l'adresse | chaque porte du village a un lot (`Village.lots`) et une adresse ; une porte fermée répond (« Personne. Repassez après le loto. ») |
| Un projet extérieur occupe un lot en ajoutant une ligne à un annuaire | les lots libres (`lot_reserve`, `lot_a_ceder`) et les communes greffées (section 5) |
| Les îlots construits en détail près du joueur, en boîtes au-delà | même principe, par quartier, pour tenir la vue dézoomée et une machine modeste |
| Les salles en 3D construites à la première visite, figurants animés seulement près du joueur | les intérieurs du village (boutiques, maisons, caves) suivent la même règle |
| Le taxi qu'on hèle de n'importe quelle rue | **le véhicule qu'on possède** (Mobylette, 2 CV, DS, achetés chez Roger Fradin) sert de déplacement rapide vers les lieux déjà découverts ; sans véhicule, on marche |
| Une ville qui existe avant qu'on la voie, et qu'un seuil révèle | **les rues fermées par des barrières de chantier** (« Travaux. Le comité des fêtes vous remercie. ») tant que leur seuil n'est pas atteint |

### Ce qu'on ne reprend pas

- **Le jour réel, le salaire, l'impôt et les crises de la ville d'Addict.** À Smarves, le temps se compte en mises et la recette tombe toutes les 20 mises (GESTION.md). Un village qui vivrait sans le joueur changerait l'économie, qui est en pause.
- **La limousine et le survol unique.** Le village se découvre à pied ; il n'y a pas de grande révélation au million.
- **La sécurité, le patron, la cave et le casse.** Ils appartiennent au casino d'Addict, pas au village.
- **Les bâtiments greffés en page web dans une fenêtre isolée.** Smarves est un jeu Godot : la greffe se fait par commune entière (section 5), pas par page.

**Alternatives écartées.** Des quêtes avec objectifs à l'écran : contraire au ton, la rumeur suffit. Un village ouvert en entier dès le départ : on perd la clé unique des seuils. Un monde procédural : Smarves est un vrai village, sa géographie est écrite à la main.

## 2. La vue extérieure dézoomée

Le fil « Extension du village » prototype la caméra ; ce chapitre donne les recommandations, transmises par le coordinateur. Je ne touche pas à la caméra.

### Aujourd'hui

En vue de dessus, la caméra suit l'habitant à 9 unités, inclinée à 48°, avec un champ vertical de 34° (`main.gd`, `set_fps`). À l'échelle de la maquette, une unité vaut environ 2,4 m (un habitant mesure 0,7 unité, la route 2,4 unités) : on voit donc environ 23 m de large, à peine une devanture et demie. Les captures sont belles, mais on ne voit jamais où l'on va.

### Ce qu'on propose

Trois crans de molette, la caméra glisse de l'un à l'autre :

| Cran | Distance | Hauteur | Inclinaison | Champ vertical | Largeur vue (16:9) | Taille d'un habitant à l'écran (900 px de haut) | Usage |
|---|---:|---:|---:|---:|---:|---:|---|
| Proche | 9 u (≈ 22 m) | ≈ 16 m | 48° | 34° | ≈ 23 m | ≈ 110 px | parler, entrer, regarder une devanture (l'actuel) |
| **Rue (par défaut)** | **18 u (≈ 43 m)** | **≈ 34 m** | **51°** | **30°** | **≈ 41 m** | **≈ 45 px** | marcher, voir le bout de la rue |
| Quartier | 40 u (≈ 96 m) | ≈ 83 m | 60° | 30° | ≈ 90 m | ≈ 30 px | s'orienter, voir les repères |

**Retenu sur captures** (fil « Extension du village ») : le cran Rue était proposé à 22 u ; avec les personnages en ligne claire, on n'y voit plus que des points d'environ 30 px. À 18 u, on reconnaît encore une coiffure et la couleur des épaules, et toute la place tient à l'écran. Les crans sont dans `scripts/village/village.gd` (`CAMERA_NOTCHES`) ; la molette passe de l'un à l'autre.

Au-delà du cran « quartier », on ne dézoome plus : on ouvre le plan du village (carnet) ou, plus tard, la carte de la Vienne. Le flou de bascule (tilt-shift) reste à tous les crans et s'accorde à la distance, comme aujourd'hui ; c'est lui qui garde l'effet maquette quand on s'éloigne. Sur téléphone en paysage, le cran par défaut se rapproche d'environ 20 % (le fil web et mobile tranchera).

### Ce que cela impose aux personnages

- **Vus à 51°, on voit surtout le dessus de la tête et les épaules.** Un personnage se reconnaît donc d'abord à sa coiffure ou à son chapeau, puis à la couleur de ses épaules. Les fiches de la bible doivent avoir, pour chaque personnage nommé, un **signe vu d'en haut** : la permanente blonde de Josiane, le béret de Dédé, la casquette de Lucien, la raie sur le côté et les épaules gris anthracite de M. Brunet, le nœud papillon or et le costume bleu nuit du nouveau venu.
- **Taille minimale : environ 45 px au cran « rue ».** En dessous de 40 px, on ne lit plus un visage, seulement une silhouette ; c'est le contour noir de la ligne claire qui la tient.
- **Une ombre portée nette sous chaque personnage**, qui le pose sur le sol et le détache des pavés.
- **Au cran « quartier »**, les personnages nommés gagnent une petite pastille au-dessus de la tête (leur signe vu d'en haut, en icône), les figurants non.
- **Coût** : au-delà de 40 m, l'animation tombe à quelques images par seconde et le visage ne s'anime plus ; au-delà de 90 m, les figurants disparaissent (c'est déjà le principe de `villager.gd`, à étendre).

### Ce que cela impose aux façades

- **Les toits font la moitié de l'image.** Ils doivent varier : tuile canal ocre pour le bourg, ardoise pour la mairie, le Crédit Smarvois et les maisons de maître, zinc pour les ateliers, cheminées, lucarnes, chiens-assis, antennes râteau. Aujourd'hui les toits sont tous les mêmes.
- **Les enseignes doivent se lire d'en haut.** Une enseigne plaquée sur la façade disparaît à 51°. Les lieux de jeu ont donc une **enseigne en potence** (perpendiculaire à la rue) ou une **enseigne sur le toit** (CASINO, JACKPOT, LOTO CE SOIR), avec des lettres d'au moins 0,5 unité de haut.
- **La lumière guide.** Une vitrine allumée veut dire « ouvert » ; une fenêtre éteinte et des volets clos, « fermé » ; une porte entrouverte avec un rai de lumière, « lieu caché ». C'est le seul code couleur du village, et il ne s'écrit nulle part.
- **Construction par distance**, comme les îlots d'Addict : les façades détaillées dans un rayon d'environ 70 m, des volumes simples avec toit et fenêtres allumées au-delà, rien après 150 m sauf les repères.

**Alternatives écartées.** Une vue isométrique orthographique : on perd la profondeur et le flou de maquette. Une vue à la troisième personne derrière l'épaule : on ne voit plus le village. Garder le cran actuel par défaut : c'est précisément ce que Guillaume demande de changer.

## 3. Le housing

### Le principe

Les maisons de l'autoload `Biens` deviennent des lieux qu'on habite et qu'on aménage. Au premier degré, c'est la suite logique de la réussite : on gagne, on s'installe, on reçoit. Et c'est toujours M. Brunet qui finance les meubles.

Les trois logements existent déjà dans le catalogue, chacun à un exemplaire au plus :

| Id dans `Biens` | Logement | Lot du village (à poser) | Taille |
|---|---|---|---|
| `chambre` | la chambre au-dessus du café | `chambre_cafe`, porte latérale du Café de la Place | une pièce, 6 emplacements |
| `maison` | la maison de la rue de l'Église | `maison_eglise`, sur le chemin de Passelourdin | quatre pièces et un jardin, 24 emplacements |
| `maison_place` | la maison de maître sur la place | `maison_place`, face à l'érable | huit pièces, un salon de réception, 48 emplacements |

### Habiter ou louer

**Tranché : un logement est soit loué, soit habité, et on choisit dans le carnet.** Loué, il verse sa rente à chaque recette, comme aujourd'hui. Habité, il ne verse plus rien mais compte deux fois son standing, et son ameublement en ajoute. Comme le standing fait grossir les prêts que M. Brunet propose, habiter une belle maison, c'est renoncer à une rente pour emprunter plus. Personne ne le dit ; le carnet aligne les deux colonnes.

On ne peut habiter qu'un logement à la fois. Le nouveau venu dort à l'hôtel du casino tant qu'il n'a rien (aucune scène, juste une ligne au carnet : « Adresse : chez Monsieur Armand »).

### L'ameublement

- **Des emplacements, pas un placement libre.** Chaque pièce a des emplacements nommés (« mur du salon, à gauche », « buffet », « coin du feu », « jardin, sous le tilleul ») où se pose un meuble d'un genre donné. C'est rapide à jouer à la souris comme au doigt, impossible à casser, et facile à montrer aux autres.
- **Où l'on achète** : chez **Ginette Boutin, brocante et meubles**, rue du Clain (sur `lot_a_ceder`, que la brocante prend). Comme les autres vendeurs : payer comptant ou financer au Crédit Smarvois, reprise à 60 %.
- **Ce qu'on pose** : des meubles de la brocante (buffet Henri II, téléviseur à pieds, juke-box, billard, table de jeu en feutre vert), les trouvailles de l'exploration, et les **souvenirs de jeu** que le jeu remet d'office (le premier jeton du casino, la carte de membre du Salon privé, le carton du loto si l'on a gagné). Une machine à sous de salon, achetée chez Ginette, ne se joue pas : elle clignote.
- **Le confort ne donne rien au jeu.** Un meuble donne quelques points de standing quand on habite le logement, rien d'autre. Les seuils ne bougent pas.

### La reprise par M. Brunet

**Tranché : une maison saisie part avec ses meubles.** M. Brunet reprend « meublé, c'est plus facile à revendre », au prix de reprise de la maison plus 60 % du prix des meubles. Les trouvailles et les souvenirs de jeu, qui ne valent rien, reviennent au joueur dans un carton posé devant la porte de son ancien logement, avec un mot du Crédit Smarvois (« Nous avons pris soin de vos effets personnels. »). Si l'on habitait le logement saisi, on retourne à l'hôtel du casino.

Alternatives écartées : rendre les meubles (la reprise perdrait son poids) ; les vendre à part (deux reprises pour un seul geste, illisible).

### Le modèle de données

La sauvegarde de `Biens` (`user://smarves_biens.save`, JSON lu champ par champ avec des valeurs par défaut) gagne un dictionnaire `logements`, sans casser les sauvegardes existantes :

```json
"logements": {
  "chambre": {
    "lot": "chambre_cafe",
    "habite": true,
    "interieur": "chambre_v1",
    "meubles": { "lit": "lit_cuivre", "mur_gauche": "affiche_loto_1987", "table": "machine_salon" },
    "facade": { "volets": "vert_bouteille", "jardiniere": "geraniums", "plaque": "" }
  }
},
"meubles_possedes": { "lit_cuivre": 1, "machine_salon": 1 },
"trouvailles": ["affiche_loto_1987", "ticket_dede"]
```

- `interieur` désigne un gabarit d'intérieur (une scène par logement et par version). Un gabarit déclare ses emplacements : id, pièce, genre de meuble accepté, position.
- Les meubles sont un nouveau genre du catalogue de `Biens` (`kind: "meuble"`), vendus par `brocante`, avec prix, standing et `slot` (le genre d'emplacement). Les trouvailles sont un catalogue à part, sans prix.
- **Fait (fil Gestion)** : pas de clé `meubles_possedes`. Les meubles achetés sont comptés dans `owned` comme les autres biens (revente, financement et estimation réutilisés tels quels) ; `logements[id].meubles` dit seulement où ils sont posés. Les gabarits (`Biens.INTERIEURS`) déclarent pièces et genres ; les positions viendront avec les scènes d'intérieur. `Biens.door_of(lot)` répond aux portes du village.
- **Le lien maison ↔ lot** se fait par le champ `lot` du catalogue de `Biens`, qui nomme la porte de `Village.lots` (`chambre_cafe`, `maison_eglise`, `maison_place`). Le fil « Extension du village » pose ces lots ; la porte d'un logement possédé ouvre l'intérieur, sinon elle dit « Propriété privée » et, s'il est en vente, « En vente chez Maître Garnier ».
- **Ce que les autres voient** (section 4) est un instantané de ce dictionnaire, réduit à `interieur`, `meubles`, `facade` et le nom du joueur. Ni les crédits, ni la dette, ni les rentes ne sortent de la machine.

### Le lien avec le carnet

Une page **« Mon logement »** dans le carnet (`Carnet`) : l'adresse, habité ou loué (le bouton qui bascule), la rente qu'on touche ou à laquelle on renonce, les charges, le standing gagné par l'ameublement, la valeur estimée par Maître Garnier, meubles compris. Le plan du village y renvoie, et « Adresses » gagne la brocante.

**Alternatives écartées.** Le placement libre des meubles sur une grille : beaucoup plus de code, de collisions et de cas tordus pour un gain faible. Une maison construite pièce par pièce : c'est un autre jeu. Des meubles qui rapportent : on brouillerait l'économie des recettes, en pause.

## 4. Le multi

### Ce que « multi » veut dire à Smarves

Par ordre d'arrivée :

1. **Visiter la maison des autres** (asynchrone) : on frappe à la porte d'un joueur dont on connaît le nom, ou l'on suit une carte postale qu'il a envoyée, et l'on entre dans son logement tel qu'il l'a meublé. Il n'est pas là ; on peut laisser un mot dans le livre d'or.
2. **Les classements** (asynchrone), affichés au village et jamais à l'écran : le tableau à la craie de Lucien (« Les meilleurs placements de la semaine », sur le total gagné au jeu), le tableau d'honneur du Crédit Smarvois (« Nos clients les plus confiants », sur la dette, au premier degré), le palmarès du loto à la salle Rabelais.
3. **La soirée partagée** (temps réel) : comme la nuit d'Addict, jusqu'à 16 joueurs dans la même copie du village. On se voit marcher sur la place, on se fait un signe, une phrase dans une bulle, les gros gains se voient au-dessus des têtes.
4. **Les tables à plusieurs** (temps réel) : deux joueurs de la même soirée à la même roulette ou au même blackjack partagent le tirage, chacun avec ses mises.
5. **Le poker de Passelourdin à plusieurs** (temps réel), comme le Poker des Ambassadeurs d'Addict : les joueurs prennent les chaises du Notaire, de la Meunière, de Gégé ou du Docteur, qui se lèvent.
6. **Visiter le village d'un autre** n'existe pas : le village est le même pour tous. Ce qui diffère d'un joueur à l'autre, ce sont ses portes ouvertes, ses biens et sa maison.

### L'architecture

**Tranché : le Supabase existant de Pyramides (projet `alvxrjftenialifyktyz`), comme Addict Casino.** Comptes Pyramides partagés avec le casino d'Addict et la page des jeux de Pyramides, un schéma `smarves` séparé, une fonction serveur `smarves` pour tout ce qui touche à l'argent, et Supabase Realtime pour la présence. C'est ce qu'Addict a éprouvé (nuit partagée, tables à plusieurs, poker), sans serveur à héberger.

Concrètement, côté Godot :

- **Connexion** : le même serveur d'autorisation de Pyramides qu'Addict (PKCE), ouvert dans le navigateur du système ; le jeton revient par une adresse locale. Sans compte, Smarves se joue exactement comme aujourd'hui, sur la machine.
- **Appels à la fonction** : `HTTPRequest` vers la fonction `smarves`, en JSON.
- **Temps réel** : un petit client Realtime en GDScript sur `WebSocketPeer` (le protocole de Supabase Realtime est simple : rejoindre un canal, diffuser, recevoir). Les positions passent de joueur à joueur en diffusion (5 envois par seconde quand on bouge) ; tout le reste (arrivées, phrases, gestes, gros gains) est décidé et signé par la fonction, comme dans Addict.
- **L'argent** : en solo, rien ne change, les jeux tournent dans Godot. Avec un compte, **seuls les jeux joués à plusieurs** (tables partagées, poker) et les achats passent par le serveur, qui tire et paie. Les règles de ces jeux existent alors en double, en GDScript et en TypeScript ; un test commun (mêmes graines, mêmes résultats attendus) garde les deux d'accord. Les autres jeux restent dans Godot et le serveur ne les croit que dans des plafonds par heure, comme la manche d'Addict.
- **Ce qui part au serveur** : le nom, la tenue, le logement (l'instantané de la section 3), les trouvailles exposées, le total gagné au jeu et la dette pour les classements. Pas la sauvegarde entière.

| Asynchrone (tables du schéma `smarves`, lues à la demande) | Temps réel (canal Realtime de la soirée) |
|---|---|
| logements et livres d'or, cartes postales, classements, profil public | positions, signes, bulles, gros gains, places aux tables, donnes du poker |

**Alternatives écartées.** Le multijoueur de haut niveau de Godot (`MultiplayerAPI` sur WebSocket ou ENet) : il demande un serveur de jeu à héberger et à garder allumé, et ne donne ni comptes ni base. Un nouveau projet Supabase : on repaierait une base et on séparerait les comptes de ceux d'Addict. Tout l'argent sur le serveur dès le départ : on casserait le jeu hors ligne et on récrirait tous les jeux en double.

**À demander à Guillaume le moment venu** : la création du schéma `smarves` et de ses tables est une migration de la base de production ; elle attend son accord, dans le fil qui la fera.

## 5. La carte de la Vienne et les communes greffées

### Le principe

Smarves est la première commune d'une carte de la Vienne. La carte est une maquette du département, posée sur la même table de noyer que le village : les rivières (le Clain, la Vienne, le Miosson), les routes, et des communes comme des petits socles. Une commune présente est éclairée et se visite ; les autres sont des silhouettes de clocher sous une cloche de verre. **Poitiers est un trou dans la carte**, une zone de brume au nord : on n'y va pas, c'est là que partent ceux qui ne croient pas au jeu (bible, section 4).

On passe d'une commune à l'autre par la route, avec son véhicule ou par le car départemental, depuis l'arrêt de car de la place. Le trajet est un court survol de la carte.

**Le partage suit celui de la bible** (en tête de [`BIBLE.md`](BIBLE.md)), sans en inventer un autre :

- **Au socle, parce que la bible les déclare communs** : le ton, l'époque, la règle des lieux et des seuils, l'économie en crédits, le vocabulaire et la typographie. Côté code, cela donne une seule bourse de crédits, un seul total gagné au jeu (la clé, partagée par toutes les communes : ce qu'on gagne à Ligugé ouvre aussi Smarves), un seul total misé, une seule dette au total, les recettes toutes les 20 mises et le carnet.
- **Dans la commune, parce que la bible les déclare propres** : la géographie, les lieux et leurs tenanciers, le casino s'il y en a un, les personnages, la banque et son banquier, la machine fétiche et les enseignes. Chaque commune apporte donc **sa propre banque** : le socle tient la dette par prêteur, le carnet en donne le total et le détail (« Crédit Smarvois : 4 297 »), et chaque banquier n'a d'opinion que sur ce qu'on lui doit à lui.

La première commune greffée est **Ligugé**, la voisine du nord-ouest, celle du prieuré où vécut Rabelais : elle vérifie le format sans enjeu, faite par nous, livrée en pack séparé comme le serait un mod.

### Le format d'une commune

Une commune est un dossier `communes/<id>/` avec un manifeste et ses ressources :

```json
{
  "format": 1,
  "id": "liguge",
  "nom": "Ligugé",
  "carte": { "lat": 46.52, "lon": 0.33, "socle": "res://communes/liguge/socle_carte.tscn" },
  "auteur": "chtabay",
  "version": "0.1.0",
  "socle_min": "1.0",
  "scene": "res://communes/liguge/commune.tscn",
  "arrivee": { "lot": "arret_car", "par": ["smarves"] },
  "lieux": [
    { "id": "prieure", "nom": "Le cloître du prieuré", "jeu": "…", "seuil": 30000, "hote": "…", "lot": "prieure" }
  ],
  "personnages": "res://communes/liguge/cast.tres",
  "banque": { "id": "…", "banquier": "…", "lot": "…" },
  "biens": "res://communes/liguge/biens.json",
  "jeux": { "regles_serveur": [] }
}
```

- **Deux façons de livrer une commune.** Les communes du dépôt vivent dans `res://communes/` (Smarves y passera elle-même). Les mods arrivent en **pack `.pck`** déposé dans `user://communes/`, chargé au démarrage par `ProjectSettings.load_resource_pack()` avant la première scène ; un pack ne doit écrire que sous `res://communes/<son id>/`, et le chargeur refuse celui qui écrase un fichier du socle.
- **Un pack contient du code.** Godot ne sait pas isoler un script : un mod `.pck` a les mêmes droits que le jeu. Les mods sont donc des mods de confiance, installés à la main par le joueur, comme dans tous les jeux Godot ; le jeu l'écrit au premier chargement d'un pack.
- **L'argent d'un mod, en multi.** Avec un compte, une commune tierce ne fait gagner que si ses règles ont été versées au serveur (comme les règles de bâtiment d'Addict, `casino/batiments/README.md`) ; sinon ses jeux tournent, mais ce qu'on y gagne reste dans la partie locale et n'ouvre rien chez les autres.

### Ce que le socle doit exposer

Pour qu'une commune tierce se branche sans toucher au code de Smarves :

| Ce qui existe | Ce qu'il faut en faire |
|---|---|
| `Game` : crédits, gagné au jeu, misé, dette, `changed`, `brunet_calls`, `spend`, `cash_in`, `borrow` | une API stable et documentée ; `cash_in` et `spend` prennent une source (`commune/lieu`) pour le carnet ; un signal `played(source, mise, gain)` ; `borrow(prêteur, montant)` et la dette tenue par prêteur, M. Brunet devenant le prêteur `smarves` |
| `Biens` : catalogue, `buy`, `sell`, recette, reprise | `Biens.register(commune_id, items)` pour qu'une commune ajoute ses biens et ses vendeurs |
| `Carnet` : pages, `go_to`, `show_slip` | `Carnet.add_page(commune_id, titre, construire)` et une ligne d'adresse par commune |
| `Village.lots`, portes, métadonnées `action` sur les `Area3D` | une classe `Lots` commune à toutes les communes, que chaque scène de commune remplit ; le plan du village devient « le plan de la commune » |
| `PLACES` et `_check_unlocks` dans `main.gd` | un registre de seuils `Seuils` (autoload) : chaque commune déclare ses lieux, le registre annonce les ouvertures ; `main.gd` le lit au lieu de sa constante |
| `Cast.NAMED`, `Cast.resolve()` | `Cast.register(commune_id, fiches)` : une commune apporte ses personnages dans la même famille (ligne claire) |
| deux fichiers de sauvegarde à la racine de `user://` | une sauvegarde versionnée en **tiroirs** : `Game` et `Biens` au socle, un tiroir `user://communes/<id>.save` par commune, comme les tiroirs `addict.jeu.<id>` d'Addict |

### L'ordre pour y arriver sans casser Smarves

1. **Décrire Smarves comme une commune, sans rien changer à l'écran.** `PLACES`, les lots et le catalogue sont lus depuis `res://communes/smarves/`. Le parcours automatique (`tools/smoke.tscn`), les simulations et les tests de `Biens` sont les garde-fous : leurs chiffres ne doivent pas bouger d'une unité.
2. **Ranger la sauvegarde en tiroirs**, avec une migration lue une seule fois des deux fichiers actuels.
3. **Le registre `Seuils` et les API `register`** de `Biens`, `Carnet` et `Cast`, utilisés d'abord par Smarves elle-même.
4. **La carte de la Vienne avec Smarves seule** : un écran de plus, depuis l'arrêt de car, avec Poitiers dans la brume.
5. **Ligugé en pack `.pck` séparé**, construit par le même workflow d'export, chargé depuis `user://communes/`. C'est le test de la greffe : si Ligugé a eu besoin de toucher au socle, le socle n'expose pas assez.
6. **La notice des communes** (`communes/README.md`), sur le modèle de la notice des bâtiments d'Addict, puis seulement les communes tierces.

**Alternatives écartées.** Des communes en scènes ajoutées directement au dépôt sans manifeste : aucune frontière, chaque commune finit par toucher au socle. Des mods en données seules (JSON et modèles, sans script) : sûr, mais trop pauvre pour un jeu par commune. Un éditeur de commune dans le jeu : bien plus tard, si des gens font des mods.

## 6. Le séquencement et les fils en cours

| # | Chantier | Fil | Dépend de |
|---|---|---|---|
| 1 | Caméra à trois crans, lisibilité des personnages, toits variés, enseignes en potence et sur les toits, construction par distance | Extension du village (caméra, façades), Personnages (signe vu d'en haut, ombre, pastilles) | — |
| 2 | Smarves décrite par un manifeste, sauvegarde en tiroirs, registre `Seuils` | un fil « Socle des communes » à ouvrir | 1 n'est pas bloquant ; à faire avant 3 pour que les nouvelles rues naissent dans le bon format |
| 3 | Route du Bois, chemin de Passelourdin, barrières de chantier, plan du village dans le carnet, repères, lieux cachés, trouvailles | Extension du village, Cohérence du monde (noms, rumeurs) | 2 |
| 4 | Chambre au-dessus du café habitable, brocante de Ginette Boutin, page « Mon logement », puis les deux maisons | Gestion de la ville | 2, et les lots `chambre_cafe`, `maison_eglise`, `maison_place` du fil Extension |
| 5 | Carte de la Vienne, car départemental, Ligugé en pack | Socle des communes, puis un fil Ligugé | 2, 3 |
| 6 | Compte Pyramides, visites de maisons, livre d'or, classements au village | un fil Multi | 4 ; migration du schéma `smarves` sur accord de Guillaume |
| 7 | Soirée partagée, tables à plusieurs, poker de Passelourdin | fil Multi, Visuel des jeux | 6 |

**Ce que cela change pour les fils en cours :**

- **Cohérence du monde** : la séparation entre ce qui vaut pour toutes les communes et ce qui est propre à Smarves est déjà dans la bible, et ce cadrage s'y appuie ; la bible gagne ensuite la carte de la Vienne, Poitiers dans la brume, la banque propre à chaque commune, Ligugé, la brocante de Ginette Boutin, les trouvailles et le livre d'or ; la ligne « pas d'export web » de la fiche de cadrage attend la réponse du fil web et mobile.
- **Personnages** : un signe vu d'en haut pour chaque personnage nommé (coiffure ou chapeau, couleur d'épaules), 50 px de haut au cran « rue », une ombre portée, une pastille pour les nommés au cran « quartier ».
- **Extension du village** : la caméra à trois crans (valeurs de la section 2, à ajuster sur captures), les toits et les enseignes, les lots des trois logements, la brocante sur `lot_a_ceder`, les barrières de chantier des rues pas encore ouvertes. Les nouvelles rues sont décrites par des données plutôt que par du code dès que le socle des communes existe.
- **Visuel des jeux** : rien à court terme. Plus tard, chaque table déclare ses places numérotées, pour les tables à plusieurs.
- **Gestion de la ville** : le dictionnaire `logements`, le genre `meuble`, la brocante, le choix habiter ou louer, la reprise meublée, la page « Mon logement ». Rien ne change aux recettes, aux prix ni aux seuils.

## Ce qui dépend du fil web et mobile

Ce document ne tranche pas la question du web ; ces points en dépendent :

- **Le rendu** : le web n'a que le rendu Compatibilité de Godot (WebGL 2), pas Forward+. L'éclairage global, les halos et la lumière des vitrines, qui portent la direction artistique, seraient à refaire ou à simplifier ; la vue dézoomée, qui montre plus de façades et plus de lumières, est la plus exposée.
- **Le cran par défaut et les contrôles** sur téléphone : pincer pour zoomer, glisser pour tourner, toucher pour marcher.
- **Les mods** : sur le web, un pack `.pck` doit être téléchargé dans le stockage du navigateur avant d'être chargé ; c'est possible mais moins simple que de déposer un fichier.
- **Le multi** n'en dépend pas : `HTTPRequest` et `WebSocketPeer` marchent sur ordinateur comme dans le navigateur.
