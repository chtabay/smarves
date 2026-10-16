# Smarves

Un jeu incrémental dans l'esprit d'Addict Casino, où le casino est tout un village : le vrai Smarves, dans la Vienne. On joue au café, sur la place, à la boulangerie, à la kermesse, au bois de Saint-Pierre… et au Casino de Smarves, dont les salles s'ouvrent à mesure qu'on gagne. Au premier degré, tout le village encourage à jouer : le jeu est un investissement, et M. Brunet, du Crédit Smarvois, prête toujours.

La fiche de cadrage est dans [`docs/CADRAGE.md`](docs/CADRAGE.md), les captures dans [`docs/captures/`](docs/captures/).

## Jouer

**Sans Godot** : [télécharger la dernière version pour Windows](https://github.com/chtabay/smarves/releases/latest/download/Smarves-windows.zip), décompresser, lancer `Smarves.exe`. Elle est reconstruite à chaque poussée sur `main`. Tant que le dépôt est privé, le lien demande d'être connecté à GitHub avec un compte qui y a accès.

**Avec Godot** : installez [Godot 4.7](https://godotengine.org/download) (version standard), ouvrez le dossier du projet dans Godot, puis appuyez sur **F5**.

En ligne de commande :

```sh
godot --path .
```

## Commandes

- **Au village** : clic gauche sur un lieu ouvert pour y jouer, clic droit maintenu pour tourner la maquette, molette pour zoomer. Les panneaux en bois mènent aux environs (bois de Saint-Pierre, Moulin des Dames, Passelourdin). La liste « Le village », en haut à droite, est cliquable.
- **Au casino** : ZQSD (ou WASD) pour marcher, souris pour regarder, **E** ou clic pour s'asseoir à une table, **Échap** pour quitter une table ou libérer la souris.

## Ce qu'on trouve

- **La place de la Mairie** : la machine à sous du Café de la Place, les paris sur la pétanque, la roulette de la boulangerie, le loto de la salle Rabelais, la roue de la kermesse, le Crédit Smarvois.
- **Les environs** : la course des trois zèbres de béton au bois de Saint-Pierre, le blackjack du Moulin des Dames, le poker clandestin des rochers de Passelourdin.
- **Le Casino de Smarves**, sur le plan d'Addict : hall d'honneur, bar Le Nocturne, salle des jeux (17 machines, roulette, blackjack, craps), Salle des Ambassadeurs (poker), salon privé (baccara), et à l'étage la Galerie de la Verrière, le Bar du Fumoir, le restaurant Le Lustre, la Loggia (Grand Hasard), le Salon de musique (la Boule), la Salle des fêtes (Roue de la fortune) et les Salons particuliers (Banco).

Les lieux et les salles s'ouvrent par seuils, sur le total gagné au jeu (la Salle des fêtes sur le total misé). La partie est sauvegardée automatiquement.

## Pour les développeurs

- `scripts/main.gd` : la place et les environs (`scripts/outskirts.gd`).
- `scripts/casino_interior.gd` : le casino ; un panneau par jeu (`*_panel.gd`, `slot_machine.gd`).
- `scripts/game_state.gd` (autoload `Game`) : crédits, gains, mises, dette, sauvegarde. `scripts/sfx.gd` (autoload `Sfx`) : le son.
- Captures de vérification : `godot --path . -- --capture=sortie.png [--open=cafe] [--travel=bois] [--view=distance,x,y,z,lacet,tangage]`, et pour le casino `godot --path . res://scenes/casino.tscn -- --capture=sortie.png --at=x,z,lacet,tangage[,hauteur] [--open=roulette] [--won=5000]`.
- Parcours automatique de tout le jeu (chaque lieu, chaque table, voyages, fenêtre redimensionnée, temps de rendu) : `godot --path . res://tools/smoke.tscn`. Il ne touche pas à la sauvegarde.
- Simulation de la progression : `godot --headless --path . res://tools/sim_progression.tscn` (résultats dans [`docs/EQUILIBRAGE.md`](docs/EQUILIBRAGE.md)).
- Test automatique des donnes de poker : `godot --headless --path . -s tools/test_games.gd`.
- Planche de contact d'un dossier d'assets : `godot --path . -s tools/sheet.gd -- res://assets/kaykit/city planche.png 6`.
