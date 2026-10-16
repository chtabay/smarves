# Smarves — fiche de cadrage

## En une phrase

Un jeu incrémental dans l'esprit d'Addict Casino, sauf qu'ici le casino, c'est tout un village : le vrai Smarves, dans la Vienne, où l'on joue à chaque coin de rue, du comptoir du café jusqu'au fond du bois de Saint-Pierre.

## La morale

Le jeu dit tout au premier degré : à Smarves, on joue, on gagne, et si ton banquier te refuse un prêt pour aller jouer, c'est un loser. Personne dans le village ne dit le contraire, ni les habitants, ni les enseignes, ni le banquier lui-même.

La démonstration que ça ne marche pas doit sortir du jeu, jamais d'un discours. Les machines rendent un peu moins qu'elles ne prennent, les prêts s'empilent, les habitants maigrissent, vendent leur voiture et finissent sur un banc, toujours souriants. Le ton est celui de Happy Tree Friends : des personnages mignons à qui il arrive des choses terribles, et qui en redemandent.

- **M. Brunet**, conseiller du Crédit Smarvois, prête volontiers pour « se refaire ». Quand il refuse enfin, le jeu l'affiche en grand : « Votre banquier refuse ? C'est un loser. Changez de banquier. »

## Le village

Smarves existe : 2 900 habitants à 8 km au sud de Poitiers, entre le Clain et le Miosson. Le jeu reprend sa géographie réelle, mais tous les commerces, habitants et histoires sont inventés.

Les lieux réels qu'on reprend :

- **La place de la Mairie**, avec son érable rouge planté en 1986 et le monument aux morts ;
- **l'église Saint-Félix-de-Nole**, sur la place de l'Église ;
- **la salle polyvalente François-Rabelais**, au-dessus de l'église ;
- **le bois de Saint-Pierre**, l'allée du château et ses trois zèbres en béton peint (1983) ;
- **le Clain** et le Moulin des Dames ;
- **les rochers de Passelourdin**.

## Où l'on joue

Chaque lieu du village cache un jeu du casino, déguisé en coutume locale.

| Lieu | Jeu | Ouverture |
|---|---|---|
| Le Café de la Place | machines à sous au fond de la salle, 421 au comptoir | dès le départ |
| La place de la Mairie | paris sur la partie de pétanque (craps aux boules) | premier seuil |
| La boulangerie | la roulette du comptoir, entre deux baguettes | |
| La salle François-Rabelais | le grand loto du samedi soir | |
| Le parvis de l'église | la roue de la kermesse | |
| L'allée du château | la course des trois zèbres, paris façon PMU | |
| Le Moulin des Dames | blackjack dans l'arrière-salle | |
| Les rochers de Passelourdin | la partie de poker clandestine | dernier seuil |

## Boucle de jeu

Comme dans Addict, rien ne s'ouvre avec l'argent qu'on a, seulement avec ce qu'on a **gagné au jeu** :

1. On arrive à Smarves avec un petit pécule. On joue au café.
2. Les gains ouvrent les lieux un par un, par des seuils. Chaque ouverture est annoncée par un habitant.
3. Les habitants jouent aussi. Ils réagissent aux coups, se souviennent du joueur et finissent par lui confier des rumeurs qui mènent au lieu suivant.
4. Plus tard viendront les biens (une maison sur la place, une 2 CV), le patron du jeu clandestin et la fête du village.

## Les habitants (premiers rôles)

- **Josiane**, qui tient le Café de la Place et sa machine à sous « La Smarvoise » ;
- **Dédé**, accoudé au comptoir, imbattable au 421 ;
- **Lucien**, le bouliste qui prend les paris sur la place ;
- **Mme Ferrand**, la boulangère et sa roulette.

## Vue et contrôles

- Le village est une maquette en 3D vue de haut et de biais, comme un diorama. Clic droit pour tourner, molette pour zoomer.
- On clique sur un lieu ouvert pour s'en approcher et y jouer : la caméra plonge vers la table et le jeu s'ouvre à l'écran.
- On ne marche pas dans le village : on le regarde vivre.

## Direction artistique

- **Une maquette de jouets** : le village est posé sur un socle de bois, avec un fort effet miniature (flou de bascule, ou tilt-shift) qui fait « petit », et des couleurs vives de jouet.
- **Mignon** : personnages trapus et souriants, maisons aux formes arrondies (packs KayKit et Kenney Mini, CC0), le tout réuni par une palette commune.
- **Le jeu partout** : enseignes lumineuses (« JACKPOT », « TIERCÉ », « LOTO »), machines à sous dans les vitrines, roue de la fortune sur la place, fanions en cartes à jouer, gros dés, tableaux de cotes à la craie.
- **Le crépuscule** : ciel bleu nuit, vitrines qui débordent de lumière chaude, guirlandes d'ampoules, rues mouillées qui reflètent les néons.
- **La lumière fait le travail** : rendu Forward+, éclairage global, halos lumineux.
- **Interface** : sobre et dorée, typographie à empattements, comme Addict.

## Première scène jouable

La place de la Mairie au crépuscule :

- la mairie, l'érable rouge, le monument, quelques maisons de pierre et l'église au fond ;
- le Café de la Place avec sa terrasse éclairée, ses guirlandes et des habitants attablés ;
- les autres lieux visibles mais fermés, chacun avec son seuil affiché ;
- un jeu jouable : « La Smarvoise », la machine à sous de Josiane, en vue rapprochée ;
- le compteur de crédits et le total gagné au jeu, qui fait avancer les seuils.

Le but de cette scène est d'abord de juger le rendu : si elle n'est pas belle, on corrige la direction artistique avant d'ajouter des jeux.

## Choix techniques

- Godot 4.7, GDScript, rendu Forward+ (pas d'export web : c'est un jeu pour ordinateur).
- Les assets externes vont dans `assets/`, chacun avec sa licence.
