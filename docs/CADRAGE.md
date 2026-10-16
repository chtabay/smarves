# Smarves — fiche de cadrage

## En une phrase

Un jeu incrémental en 3D où l'on regarde une colonie de smarves, de tout petits nains, creuser une montagne présentée comme une maquette posée sur une table, strate après strate, jusqu'à ses profondeurs les plus étranges.

## Le monde

- **Les smarves** : des nains hauts comme un pouce, têtus, lanterne au casque. Les premiers s'appellent Bodrin et Pell.
- **Le Mont Ombreclair** : la montagne qu'ils creusent. On la voit en coupe, comme une fourmilière sous verre.
- **Le Seuil** : le camp au pied de la montagne (feu, tente, chariot, enclume). C'est là que l'or est rapporté.

## Vue et contrôles

- 3D, caméra orbitale autour du diorama : clic droit pour tourner, molette pour zoomer.
- On ne contrôle aucun personnage. On clique sur un filon pour donner un coup de pioche soi-même, et on dépense l'or dans le panneau de gestion.

## Boucle de jeu

1. Les smarves vont aux filons, piochent, rapportent le minerai au Seuil : il devient de l'or.
2. L'or sert à engager des smarves, améliorer les pioches, agrandir le chariot.
3. Un seuil d'or ouvre une galerie plus profonde, donc une nouvelle strate, avec un minerai plus riche.
4. Plus tard : production hors ligne, puis un prestige (« le Grand Repos ») où les smarves gravent une rune qui accélère la partie suivante.

## Les strates prévues

| Profondeur | Strate | Ambiance |
|---|---|---|
| 1 | La Roche grise | granit bleu nuit, filons de cuivre, lanternes orange |
| 2 | La Grotte aux cristaux | cristaux violets qui éclairent la roche |
| 3 | La Forge de lave | rivière de lave, lumière rouge, vapeur |
| 4 | La Cité engloutie | ruines d'un peuple oublié, eau turquoise |

Chaque strate ajoute une palette, un minerai et une amélioration. Comme dans le casino, rien ne change dans la première strate : tout le reste s'ouvre par des seuils.

## Direction artistique

- **Une maquette miniature** : le diorama flotte dans le noir, avec un léger flou de profondeur (effet tilt-shift) qui fait « petit ».
- **Chaud contre froid** : la roche est bleu nuit, toute la vie vient des lanternes, du feu et des filons qui luisent.
- **La lumière fait le travail** : rendu Forward+, brouillard volumétrique, halos lumineux, ombres douces, éclairage global (SDFGI).
- **Assets** : modèles low-poly propres des packs Kenney (CC0) et textures ou ciels de Poly Haven (CC0), réunis par une palette unique. Rien n'est dessiné en formes de code quand un modèle existe.
- **Interface** : sobre et dorée, typographie à empattements, chiffres qui défilent.

## Première scène jouable

Le Seuil et la première galerie de la Roche grise :

- le camp avec son feu, son chariot et son enclume ;
- l'entrée de la mine et une galerie avec trois filons de cuivre qui brillent ;
- Bodrin et Pell font l'aller-retour entre les filons et le chariot ;
- un compteur d'or, un bouton « Engager un smarve », et le clic sur un filon pour piocher soi-même.

Le but de cette scène est d'abord de juger le rendu : si elle n'est pas belle, on corrige la direction artistique avant d'ajouter du jeu.

## Choix techniques

- Godot 4.7, GDScript, rendu Forward+ (pas d'export web : c'est un jeu pour ordinateur).
- Les assets externes vont dans `assets/`, chacun avec sa licence.
