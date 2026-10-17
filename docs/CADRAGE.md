# Smarves — fiche de cadrage

## En une phrase

Un jeu incrémental dans l'esprit d'Addict Casino, sauf qu'ici le casino, c'est tout un village : le vrai Smarves, dans la Vienne, où l'on joue à chaque coin de rue, du comptoir du café jusqu'au fond du bois de Saint-Pierre.

## La morale

Tout le village encourage à jouer, au premier degré. À Smarves, le jeu est un investissement : on y place son argent pour assurer son avenir, et si un banquier refuse de prêter pour aller jouer, c'est un loser.

Personne ne dit le contraire, et personne n'est triste. Les habitants, les enseignes, la mairie et la banque sont sincèrement enthousiastes. La démonstration que ça ne fonctionne pas sort de la mécanique elle-même, sans un mot : les machines rendent un peu moins qu'elles ne prennent, et les prêts s'additionnent.

- **M. Brunet**, conseiller du Crédit Smarvois, est le meilleur ami du joueur. Quand on vient lui demander un prêt pour jouer, il approuve chaleureusement, explique à quel point c'est pertinent et raisonnable pour préparer son avenir, et propose volontiers d'augmenter le montant.

## Le village

Smarves existe : 2 900 habitants à 8 km au sud de Poitiers, entre le Clain et le Miosson. Le jeu reprend sa géographie réelle, mais tous les commerces, habitants et histoires sont inventés.

Les lieux réels qu'on reprend :

- **La place de la Mairie**, avec son érable rouge planté en 1986 et le monument aux morts ;
- **l'église Saint-Félix-de-Nole**, sur la place de l'Église ;
- **la salle polyvalente François-Rabelais**, au-dessus de l'église ;
- **le bois de Saint-Pierre**, l'allée du château et ses trois zèbres en béton peint (1983) ;
- **le Clain**, où l'on pose le Moulin des Dames (inventé) ;
- **les rochers de Passelourdin**, au-dessus du Miosson.

La géographie complète, les lieux, les personnages, le ton et le vocabulaire sont dans la bible du monde, [`BIBLE.md`](BIBLE.md).

## Où l'on joue

Chaque lieu du village cache un jeu du casino, déguisé en coutume locale.

| Lieu | Jeu | Ouverture |
|---|---|---|
| Le Café de la Place | la Smarvoise et les machines à sous sous la façade (le 421 de Dédé au comptoir est un décor) | dès le départ |
| La place de la Mairie | paris sur la partie de pétanque (craps aux boules) | premier seuil |
| La boulangerie | la roulette du comptoir, entre deux baguettes | |
| La salle François-Rabelais | le grand loto du samedi soir | |
| Le parvis de l'église | la roue de la kermesse | |
| L'allée du château | la course des trois zèbres, paris façon PMU | |
| Le Moulin des Dames | blackjack dans l'arrière-salle | |
| Les rochers de Passelourdin | la partie de poker clandestine | dernier seuil |

Le Casino de Smarves, ouvert dès le départ sur la place, a ses propres salles et ses propres seuils, entrelacés avec ceux du village (voir la bible, section 6).

## Boucle de jeu

Comme dans Addict, rien ne s'ouvre avec l'argent qu'on a, seulement avec ce qu'on a **gagné au jeu** :

1. On arrive à Smarves avec un petit pécule. On joue au café.
2. Les gains ouvrent les lieux un par un, par des seuils. Chaque ouverture est annoncée par un habitant.
3. Les habitants jouent aussi. Ils réagissent aux coups, se souviennent du joueur et finissent par lui confier des rumeurs qui mènent au lieu suivant.
4. Plus tard viendront les biens (une maison sur la place, une 2 CV), le patron du jeu clandestin et la fête du village.

## Les habitants (premiers rôles)

- **Josiane**, qui tient le Café de la Place et sa machine à sous « La Smarvoise » ;
- **Dédé**, accoudé au comptoir, qui perd au 421 avec méthode ;
- **Lucien**, le bouliste qui prend les paris sur la place ;
- **Mme Ferrand**, la boulangère et sa roulette ;
- **M. Brunet**, le conseiller du Crédit Smarvois.

La distribution complète (village et casino), avec la voix et les liens de chacun, est dans la bible.

## Vue et contrôles

- Le village est une maquette en 3D posée sur des socles, vue de dessus comme un diorama. On y dirige un habitant, un petit renard en costume (ZQSD, Maj pour courir) ; clic droit pour tourner, molette pour zoomer, Tab pour passer à la vue à pied.
- On s'approche d'un lieu ouvert et on appuie sur E pour y jouer : la caméra plonge vers la table et le jeu s'ouvre à l'écran.
- Dans le casino, on marche à la première personne.

## Direction artistique

- **Une maquette de jouets** : le village est posé sur un socle de bois, avec un fort effet miniature (flou de bascule, ou tilt-shift) qui fait « petit », et des couleurs vives de jouet.
- **Mignon** : les habitants sont de petits animaux à grosse tête ronde, façon Happy Tree Friends ; maisons aux formes arrondies (packs KayKit et Kenney, CC0), le tout réuni par une palette commune. L'intérieur du casino reste classieux.
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
