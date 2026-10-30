# Belley — note d'intentions

29 octobre 2026, version visée 0.1.0, Claude pour Guillaume. *Composition originale inspirée du lieu, pas une restitution métrique ni une visite patrimoniale.* **Projet à valider par Guillaume avant le premier modèle.**

## Ce que le porteur du projet sait du lieu

Réponses de Guillaume aux quatre questions, le 29 octobre 2026 :

1. **Le lieu.** On joue à Belley. Ne pas manquer : les lieux, les places et les bâtiments remarquables de Belley, la Dent du Chat et les reliefs environnants, **une vue sur la vallée depuis un banc sur une colline**, et le restaurant de la Paillère. Les falaises doivent être **conformes à l'impression qu'elles donnent dans la réalité**.
2. **Les visuels.** Deux planches à lui (`references/guillaume-29-10/`) : une auberge de pierre au bout d'une route, entre la route et un fleuve large, terrasses, tonnelle, kiosque de bois, aire de jeux, falaises au fond ; et une place devant une cathédrale néogothique de calcaire clair, stationnement en épi sous les arbres, maisons bourgeoises à croupes. Plus les deux planches du Bugey (`/mnt/project-files/cartes/bugey/references/`).
3. **Les inspirations.** Belley elle-même, avec un clin d'œil : l'auberge **au bout d'une route, entre la route et le Rhône (assez large)**.
4. **Ce qu'on y joue.** Une **course de vélo**, assez longue. Une salle comme **le sports bar de Selim à Cloué**, des **échecs**, des **paris sportifs**, des **paris en bourse** (comme à Smarves), **un notaire** et **un bar de poivrots**. S'appuyer sur les assets déjà développés et ajouter ceux qui manquent pour bien composer ; **avancer item par item, sans tout précipiter**.

Une correction de géographie : l'Auberge de la Paillère réelle n'est pas à La Motte-Servolex (Savoie) mais à **Lavours (Ain), sur la RD 992 entre Belley et Culoz, au bord du Rhône** (ain-tourisme.com, fiche consultée le 29 octobre 2026). C'est cohérent avec la demande : le Rhône est là, au bout de la route.

## L'intention

**Une phrase.** *Une petite capitale de pierre claire au fond de sa cuvette, d'où une seule route grimpe sur la colline et redescend jusqu'au Rhône, sous la longue crête du Mont du Chat.*

**L'atmosphère** (fiction de mise en scène, présentée comme telle) : un samedi de fin septembre, vers 17 h, lumière dorée rasante. C'est **la veille du Grand Prix de la Louve**, la course cycliste de la ville : les barrières sont posées le long de la Grande Rue, l'arche d'arrivée se gonfle place de la Victoire, des banderoles sèchent aux balcons, des coureurs en reconnaissance montent vers la colline, et au sports bar on prend déjà les cotes. Les vendanges du Bugey viennent de finir : des caisses vides devant les caves, une odeur de marc.

## Ancrages réels

Sources : OpenStreetMap et BD TOPO de l'IGN tirés par `tools/bourg_reel.py belley --rayon=800` le 29 octobre 2026 (2 578 bâtiments, 386 voies, relief de 251 à 340 m dans le cadre) ; RGE ALTI de l'IGN sur 36 km de côté (pas de 150 m, de 203 à 1 522 m) et `detail_orographique` de la BD TOPO pour les sommets et les rochers (`/mnt/project-files/cartes/bugey/relief/`) ; ain-tourisme.com et Wikipédia (fiches de Belley et de l'auberge, consultées le 29 octobre 2026). Les noms ci-dessous sont ceux d'OSM et de l'IGN, à recouper sur une seconde source avant d'être écrits dans le jeu.

**La ville**
- **La cathédrale Saint-Jean-Baptiste**, néogothique (XIXᵉ, sur la cathédrale du XIIᵉ dont il reste le portail nord), monument historique. Calcaire clair, tour-clocher à flèches et pinacles. Elle est au sud-est du centre, à 400 m de la place de la Victoire, et domine la place de la Cathédrale (la planche de Guillaume) ; c'est le seul grand volume de la ville.
- **Le palais épiscopal** (XVIIIᵉ, classé en 1932, médiathèque aujourd'hui), long corps classique à côté de la cathédrale, et le parc Jean-Pierre-Camus derrière.
- **La Grande Rue**, l'axe du centre ancien, qui descend du nord-ouest (place de la Victoire) au sud-est (la Vieille Porte), avec ses cours du XVᵉ (maison dite d'Olivier Le Daim, maison des États, hôtel des Ducs de Savoie, maison du Gouverneur), **la Louve passante** en bronze (l'emblème de la ville) et le buste de Brillat-Savarin ; sa maison natale est dans le centre.
- **Les places** : place de la Victoire (le grand rond, en haut de la Grande Rue, avec le monument aux morts), place de la Cathédrale, place Charles-Béraudier, place François-Mitterrand ; la Vieille Porte, l'ancienne prison, la chapelle des Cordeliers, la fresque des Vins du Bugey.
- **Les cours d'eau** : le Furans qui longe la ville à l'ouest, l'Ousson à l'est, et le **canal de dérivation du Rhône** au nord-est.

**Le relief** (calculé depuis le centre, `belley-panorama-reel.png`)
- Belley est **au fond d'une cuvette** : depuis les rues, l'horizon ne monte qu'à 3 à 5°. On ne voit pas de falaise au-dessus des toits.
- **Le Grand Colombier** (1 490 m) au nord-nord-est, à 16,6 km, avec ses barres rocheuses : le repère du nord.
- **La crête du Mont du Chat et de la Dent du Chat** (1 482 m) à l'est-sud-est, vers 15 km, qui ferme la vue ; la Charvaz (1 135 m) à l'est, à 11 km.
- **La Montagne de Parves** (585 m), 3,8 km à l'est : la colline entre la ville et le Rhône.
- À l'ouest, les croupes du Mont Pela (1 133 m, 8,8 km).

**La colline au banc** : **Au Replat, sur la Montagne de Parves** (572 m, 45,7461 N, 5,7326 E). Depuis là, la vue réelle s'ouvre : le Rhône en contrebas, la Dent du Chat en face à 11,8 km, le Colombier au nord, 76 points de rochers visibles contre 14 depuis la ville. C'est là que les falaises se voient vraiment.

**Le Rhône** coule à l'est de la Montagne de Parves (vers 5,78 E), du nord au sud, puis tourne vers l'ouest au sud de Belley (45,71 N) : la ville est dans le coude du fleuve. Entre la ville et la colline passe le **canal de dérivation du Rhône**, large et rectiligne, à un kilomètre à l'est du centre : l'ordre réel est donc la ville, le canal, la colline de Parves, le Rhône, puis la crête du Chat.

**L'auberge** : l'Auberge de la Paillère réelle (Lavours, RD 992) a un grand bar à l'entrée, une salle de plus de 200 couverts, une salle côté parc, un kiosque côté cour, une terrasse ombragée, un parc, une piscine, un terrain de boules, une aire de jeux et des pontons sur le Rhône. **C'est une entreprise réelle** : on ne la nomme pas et on n'en reprend ni l'enseigne ni le logo (CONCEPTION.md, « Représenter le réel »). Le jeu y place un équivalent inventé, **le Relais des Lônes**, qui garde le programme (bar d'entrée, terrasse, kiosque de bois, aire de jeux, pontons) et ne lui prête rien de négatif.

**Homonymes** : aucun pour Belley. **Photos** : les planches de Guillaume sont des illustrations, pas des photos ; un dossier de photos datées reste à constituer (voir « Fidélité »).

## Le fil rouge

Belley est une ville de notables (l'évêché, le bailliage, le gastronome) : l'argent s'y joue **en costume**, et le drame se lit par des traces bien rangées.

- **Le notaire et son registre** : Maître Hugues Varambon, étude dans une cour de la Grande Rue. Il vend la ville adresse par adresse ; une affiche de vente à la bougie est punaisée sous le porche.
- **Le sports bar** : « Le Colombier », face à l'arrivée de la course. On y parie sur la course, le championnat et tout ce qui roule.
- **Le Cercle des Fous** : le cercle d'échecs, dans une aile du palais épiscopal (aux échecs, le fou est l'évêque : la ville des évêques joue aux fous).
- **La charge d'agent de change** : Mme Lucienne Dérieux, au premier étage d'un hôtel particulier de la Grande Rue, tableau noir des cours à la fenêtre.
- **Le bar de poivrots** : « Au Dernier Tour », en bas de la ville, le long du Furans, ouvert dès 7 h, où les coureurs du dimanche finissent leur vélo contre le mur.
- **La banque** : la Caisse du Bugey, guichet au sports bar.

**Les traces** : l'ardoise des ardoises derrière le zinc du Dernier Tour ; des tickets de paris froissés dans le caniveau de l'arrivée ; un vélo de course en dépôt dans la vitrine du notaire, étiqueté « saisie » ; sur la colline, le banc porte une plaque « À Raymond, qui voyait loin », et la maison juste derrière est à vendre ; au Relais des Lônes, un coureur rembourse sa note en primes de course.

## Fidélité aux photos

- **Ce qu'on garde** : le plan réel du centre (Grande Rue, places, cathédrale et palais à leur place), l'orientation (le soleil couchant derrière le Mont Pela, le Colombier au nord, la Dent du Chat à l'est), l'ordre des choses (la ville, puis la colline de Parves, puis le Rhône, puis la crête du Chat), la cuvette, le calcaire clair.
- **Ce qu'on exagère** : la hauteur des montagnes lointaines de 30 % au plus, pour compenser l'écrasement de la caméra ; la hauteur de la flèche de la cathédrale, pour qu'elle serve de repère depuis la colline ; le nombre d'enseignes et de drapeaux de la course ; la largeur du Rhône à l'auberge reste vraie (il est déjà large).
- **Ce qu'on recompose** : la distance entre la ville, la colline et le Rhône est raccourcie (environ 4 km réels ramenés à 2 à 2,5 km de route) ; l'auberge, à 6 km au nord dans la réalité, est rapprochée au pied de la colline, sur la rive du Rhône, **au bout de sa propre route**. On le dit dans la `description`.
- **Ce qu'on laisse** : la zone d'activités et les usines au sud-est, les lotissements au-delà du centre, les ronds-points modernes autres que celui de la Victoire, les voitures récentes (le jeu vit dans un présent qui a gardé ses années 1980 : les voitures du stationnement sont des modèles de l'époque).

## Ce que l'on y joue

Ce qui existe déjà au socle et se branche tout de suite, et ce qui demande un ajout (à faire dans l'ordre, item par item) :

| Lieu | Ce que le socle offre | Ce qu'il faut ajouter |
|---|---|---|
| **Le Colombier**, sports bar (`salle_jeu`, `modele` : `bar-des-sports@1`, le sports bar de Selim venu de Cloué) | la salle et ses écrans, les tables du casino (`courses`, `des`, `machine`), le guichet de la Caisse du Bugey | **les paris sportifs au comptoir** : le socle n'ouvre aujourd'hui les paris du championnat (`Paris`) qu'au café de Smarves ; à demander au socle pour une `salle_jeu` |
| **Le Cercle des Fous** (échecs) | la brique `echecs@1` (`Plateaux`, les tables du serveur, robots de Novice à Expert, parties à deux) | rien, sauf des tables à nous si l'on en veut (à demander au serveur, dépôt addict) |
| **Maître Varambon**, notaire (`notaire`, `modele` : `etude-de-notaire@1`) | le registre, la vente adresse par adresse, les maisons habitables | rien |
| **Au Dernier Tour**, bar de poivrots (`salle_jeu`) | une salle du socle avec `machine`, `des`, `roue` | un décor de bistrot de quartier (à composer dans le paquet, ou une brique si d'autres cartes le veulent) |
| **Mme Dérieux**, agent de change | la bourse à levier existe (`Bourse`), mais elle vit dans la charge de Mme Vasseur à Smarves | **ouvrir la bourse à une commune** : à demander au socle ; d'ici là, la charge est **fermée par un seuil**, vitrine passée au blanc |
| **Le Grand Prix de la Louve**, course de vélo | le véhicule conduit (le vélo de facteur, 2,2 fois le pas) : on peut déjà **rouler le parcours** | **la course comme activité** (départ, coureurs, classement, paris), sur le modèle de `ACTIVITES.md` : un chantier du socle. Dans la 0.1, le parcours, l'arche, les barrières et les coureurs à l'entraînement sont là ; la course elle-même ouvre plus tard |
| **Le stade** (`terrain_foot`, `modele` : `stade-de-campagne@1`) | le club au championnat | rien ; à confirmer avec Guillaume (non demandé) |
| **L'arrêt de car**, place de la Victoire (`arret_car`) | le car vers les autres communes | rien |

Les seuils, à régler : le Colombier ouvert d'emblée ; le Cercle des Fous à 5 000 ; le notaire ouvert ; Au Dernier Tour ouvert ; la charge Dérieux à 20 000 (fermée tant que le socle ne l'ouvre pas aux communes). Rien de neuf n'est inventé dans le décor : chaque jeu passe par une structure ou une table du socle.

## Trois scènes fortes

### 1 L'arrivée sur la place de la Cathédrale

**Lieu :** la place de la Cathédrale, en venant de la Grande Rue ; repère `Vue1_Cathedrale`.

On débouche d'une rue étroite à façades d'enduit et de pierre sur la place ouverte : la façade néogothique, claire, presque blanche dans le soleil de 17 h, ses pinacles et sa tour à flèches ; à droite, la longue façade du palais épiscopal et la grille du parc ; le stationnement en épi sous les tilleuls, quatre voitures d'époque. Au loin, au-dessus des toits à l'est, la ligne bleue de la crête du Mont du Chat, basse, exactement là où elle est. À hauteur de personnage : les marches usées du parvis, les barrières de la course empilées contre le palais, une affiche du Grand Prix sur le panneau.

**Détail majeur :** le portail et les pinacles de la cathédrale, et le raccord des marches du parvis avec le pavé de la place.

**Trace du fil rouge :** des tickets de paris froissés au pied des barrières empilées.

### 2 Le banc d'Au Replat

**Lieu :** la colline de la Montagne de Parves, au bout de la montée de la course ; repère `Vue2_Banc`.

La route quitte la ville par les vignes et les prés, tourne deux fois dans le bois et s'ouvre d'un coup : un banc de bois sous un chêne, et derrière lui **toute la vallée**. En bas, le Rhône large et vert, ses lônes et ses peupliers ; en face, la crête du Chat et la Dent, ses barres rocheuses en bandeaux clairs ; au nord, le Colombier ; derrière soi, les toits de Belley et la flèche de la cathédrale dans la cuvette. C'est la seule scène où les falaises se lisent comme sur place : loin, nettes, plus claires que la forêt.

**Détail majeur :** la ligne des crêtes et des barres rocheuses, construite depuis le relief réel à son azimut, avec la brume de distance (trois plans de bleu) ; le banc, sa plaque et l'usure de la terre devant lui.

**Trace du fil rouge :** la plaque « À Raymond, qui voyait loin » et la pancarte « À vendre, étude Varambon » sur la maison du replat.

### 3 Le Relais des Lônes, au bout de la route

**Lieu :** au pied de la colline, sur la rive du Rhône, au bout d'une route qui ne mène qu'à lui ; repère `Vue3_Relais`.

La descente finit entre deux murets ; la route s'arrête devant une cour de gravier, l'auberge de pierre à tuiles rouges sur la gauche, sa tonnelle et ses parasols, le grand chêne de la terrasse, le kiosque de bois à droite, l'aire de jeux, puis la prairie et le fleuve, assez large pour qu'on ne voie pas bien l'autre rive dans la lumière. Des pontons de bois, une barque. Au fond, la Dent du Chat, cette fois de près (6 km recomposés), qui prend la lumière du soir.

**Détail majeur :** la rive du Rhône (galets, roseaux, saules, l'eau qui file et se trouble contre les pontons) et la terrasse sous le chêne.

**Trace du fil rouge :** au bar d'entrée, un coureur qui règle sa note avec une enveloppe de primes ; une ardoise « Paris sur la course : voir au Colombier ».

## La continuité entre les scènes

Le parcours de la course **est** la continuité : on le fait à pied, à vélo ou en voiture, et il relie les trois scènes.

- **Place de la Victoire → Grande Rue → place de la Cathédrale** : le départ et l'arrivée sous l'arche, l'arrêt de car, le sports bar ; puis la rue resserrée, les porches qui révèlent des cours du XVᵉ, la Louve passante, l'étude du notaire dans une cour, la charge de l'agent de change à l'étage. Une respiration : la place s'ouvre après la rue.
- **La cathédrale → la colline** : on descend vers l'Ousson par les rues de faubourg (maisons basses, jardins, remises), on franchit le canal du Rhône sur son pont, puis les vignes du Bugey en coteau, une cave et ses caisses vides, deux lacets dans le bois. La vue arrive par fragments entre les arbres avant de s'ouvrir au banc.
- **La colline → le Relais** : la descente vers le Rhône, les prés, les peupliers, une ferme et sa grange, et la route qui finit à l'auberge.
- **Le retour** montre autre chose : depuis le Rhône, la colline de dos et la flèche qui dépasse ; au retour en ville, l'arrière du sports bar et le bar de poivrots le long du Furans, qu'on n'avait pas vus à l'aller.

## La vie

La situation : **la veille de la course**. Des agents posent les barrières (on les voit porter, poser, revenir au camion), deux bénévoles gonflent l'arche, des coureurs en reconnaissance montent vers la colline (sur une boucle lente), un photographe attend au banc, la terrasse du Colombier est pleine et tournée vers l'arrivée, les habitués du Dernier Tour regardent passer les coureurs. Au Relais, un mariage termine sa journée sous le kiosque. Le vent, un seul : d'ouest, faible, il agite les banderoles, les peupliers et les parasols dans le même sens.

**Le son** : le murmure de la terrasse et un commentaire de course à la radio sur la place, les cloches de la cathédrale à l'heure, le vent dans le bois sur la colline et rien d'autre au banc, l'eau du Rhône et les assiettes au Relais.

## Palette et matières

| Famille | Direction | Repères |
|---|---|---|
| Calcaire des monuments | clair, presque blanc au soleil, creux gris-beige | `#E6DDC8`, `#CFC3A6`, joint `#8A8070` |
| Moellons et enduits des maisons | enduits ivoire et sable, pierre miel du Bugey | `#E4D7BD`, `#D2BE98`, `#B9A27A` |
| Toitures | tuile rouge vieillie pour le bourg, ardoise pour la cathédrale, le palais et les maisons bourgeoises | `#A65F42`, `#BE7752`, ardoise `#4B535C` |
| Menuiseries et métal | volets gris-vert et bleu passé, ferronneries noires, portes de chêne | `#7E928C`, `#8FA4B3`, `#2E2C2A`, `#6B4A30` |
| Eau | le Rhône vert profond, plus clair sur les hauts-fonds ; l'Ousson et le Furans plus clairs | `#3D6A6C`, `#5E8D88`, reflet `#A9C4C3` |
| Végétation | vert franc des tilleuls et des platanes, plus sombre au bois, vigne jaunissante de fin septembre | `#6E9440`, `#4D6E33`, vigne `#B59A3E` |
| Lointains et falaises | trois plans de bleu de distance ; barres rocheuses crème, jamais blanches | `#7F9286`, `#93A6AE`, `#AEBAC2`, roche `#D6CEB8` |
| Touches de vie | la course : jaune maillot, rouge de la Louve | `#E8C33A`, `#B23A2E` |

## Lumière et caméras

- **Soleil** : il vient de l'ouest-sud-ouest (azimut 250°), à 22° de hauteur, crème chaud `#FFE6C0` ; ciel bleu clair passant au jaune pâle à l'horizon ouest, sans rose ; ombres douces et lisibles. La cathédrale prend la lumière de face sur sa façade (à vérifier sur le plan : son orientation réelle décide de l'heure).
- **Matières** : calcaire 0,85, enduit 0,9, tuile 0,8, bois 0,65, métal peint 0,45, eau du Rhône 0,08.
- **Caméras de contrôle** : à hauteur d'yeux et au cran du jeu à chacun des trois repères ; au banc, la caméra doit voir la crête du Chat **à sa vraie direction** (vérification par un `--libre` dans `parcours_commune.gd` comparé au panorama calculé). La crête du Chat sort du cadre dans la Grande Rue et revient sur la place.

## Hors du périmètre

- La course comme compétition (classement, paris sur les coureurs), la bourse dans une commune et les paris sportifs dans une salle de commune : des ajouts au socle, demandés à part, un par un. La 0.1 en pose les lieux et les traces, fermés par des seuils.
- Le Grand Colombier et la Dent du Chat ne sont pas visitables : ce sont des lointains (`Lointain`, socle 1.16).
- Les monuments ne s'ouvrent pas tous : la cathédrale et le palais sont des façades travaillées, seul le Cercle des Fous a un intérieur (celui d'`echecs@1`).

## Les briques

**Prises dans la bibliothèque** : `facadier-du-bugey@1` (maisons de pierre, fermes, porche), `facadier-lyonnais@1` (immeubles d'enduit à trois étages de la Grande Rue), `mobilier-du-bugey@1` (fontaines, étals, bancs, lampadaires, tonnelles, muret), `vegetation-du-bugey@1` (chêne, charme, cerisier, vigne en rang), `terrains-du-bugey@1` (vigne en coteau, chemin, route à murets, talus, rivière pour le Furans et l'Ousson), `arbres-de-place@1` (tilleuls), `vegetation-lyonnaise@1` (platanes, cyprès), `bar-des-sports@1`, `etude-de-notaire@1`, `echecs@1`, `stade-de-campagne@1`.

**Dans le paquet de Belley** (n'a de sens que pour elle) : la cathédrale Saint-Jean-Baptiste, le palais épiscopal, la Louve passante, la Vieille Porte, le Relais des Lônes, le relief réel et ses lointains.

**À demander au fil de la bibliothèque** (« Ajouter des décors à la bibliothèque »), parce que d'autres cartes s'en serviront :
1. **Un fleuve large** (le Rhône, et la Garonne pour Toulouse, la Saône pour Lyon) : berge à galets et roseaux, lônes, pontons, saules et peupliers ; `terrains-du-bugey@1` n'a qu'une rivière étroite.
2. **Le matériel de course cycliste** : arche d'arrivée gonflable, barrières, banderoles, podium, vélos de course posés, voiture suiveuse d'époque.
3. **Des voitures des années 1980 en stationnement**, si le socle n'en a pas déjà qui conviennent (à vérifier d'abord du côté de `Biens` et des voitures KayKit).
4. **Le peuplier** (absent des trois décors de végétation).

## L'équipe et l'ordre de travail

Un seul fil de construction, item par item, comme Guillaume le demande ; chaque item finit par des captures prises à hauteur de joueur, montrées à Guillaume avant le suivant.

1. **Cette note** (validée par Guillaume le 29 octobre 2026), puis une **planche d'intention** (`/mnt/project-files/cartes/bugey/planche-intention-belley.png`) : le plan recomposé (ville, colline, Rhône) sur le relief réel, le panorama du banc calculé, et un montage des briques existantes. Validation de Guillaume.
2. **Le relief et le parcours** : la cuvette, la colline, la rive, les lointains, la route de la course de bout en bout, éprouvée à pied et à vélo avec `parcours_commune.gd`.
3. **Scène 1** : la place de la Cathédrale et la Grande Rue (cathédrale, palais, façades, Louve), puis le sports bar et le notaire branchés.
4. **Scène 2** : la colline et le banc, avec les lointains vérifiés contre le panorama calculé.
5. **Scène 3** : le Relais des Lônes et la rive (après l'arrivée du fleuve large dans la bibliothèque).
6. **Les liaisons**, puis le Cercle des Fous, Au Dernier Tour, la charge fermée, la vie et le son.
7. **Deux vagues d'approfondissement** (silhouettes, puis matières et vie), **critique indépendante** à deux verdicts, finition, emballage, `test_commune`, `parcours_commune`.

Les demandes au socle (paris sportifs dans une salle, bourse dans une commune, la course comme activité) partent à part, une à la fois, sans retarder la carte.

## État au 30 octobre 2026 (revue finale n° 1 et verdict n° 28)

Vingt-huit étapes jugées face aux planches. Notes : vue d'ensemble de la place 8, rue des Barons à hauteur de
joueur 8, façade de la cathédrale 8, falaises de la rive savoyarde 7, Relais des Lônes 7, banc 6.

- **Lumière** : soleil 0,65, ambiance 0,4, rendu linéaire (ACES délave au rendu de compatibilité), courbe de tons
  à gamma 0,88 (`adjustment_color_correction`), saturation 1,15 ; les façades en plein soleil prennent les
  enduits les plus sourds (`places/ville.gd`).
- **Couleurs** : les briques du façadier et du mobilier passent par `atelier/sature.gdshader` (gain 1,0 à ce
  jour), les arbres d'ombrière par `atelier/feuillage_ombriere.gdshader` (platanes compris).
- **Banc** : le repère `Vue2_Banc` est passé en (4200, 2160), à 527 m, d'où le Rhône se voit par-dessus la pente
  (une bosse à 600 m le cachait depuis le premier repère) ; la scène est dans `places/banc.gd`.
- **Relais** : la halle en charpente apparente au bord de la route, le platane sur la cour, les barrières du pré.
- **Reste à faire** (verdict n° 28) : les ombres portées et la courbe de tons de la vue du Relais, le pré du
  premier plan, la terrasse ; au banc, des fleurs plus petites en taches, un pré sec, le chêne en repoussoir, la
  Dent du Chat plus bleu-gris ; le parcours à vélo entre les scènes ; le budget de triangles (4 M pour 600 k).
