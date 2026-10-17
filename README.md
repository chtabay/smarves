# Smarves

Un jeu incrémental dans l'esprit d'Addict Casino, où le casino est tout un village : le vrai Smarves, dans la Vienne. On joue au café, sur la place, à la boulangerie, à la kermesse, au bois de Saint-Pierre… et au Casino de Smarves, dont les salles s'ouvrent à mesure qu'on gagne. Au premier degré, tout le village encourage à jouer : le jeu est un investissement, et M. Brunet, du Crédit Smarvois, prête toujours.

La fiche de cadrage est dans [`docs/CADRAGE.md`](docs/CADRAGE.md), la bible du monde (lieux, personnages, ton, vocabulaire) dans [`docs/BIBLE.md`](docs/BIBLE.md), la suite (village à parcourir, housing, multi, carte de la Vienne) dans [`docs/SUITE.md`](docs/SUITE.md), les captures dans [`docs/captures/`](docs/captures/).

## Jouer

**Sans Godot** : [télécharger l'installateur pour Windows](https://github.com/chtabay/smarves/releases/latest/download/Smarves-installateur.exe) et le lancer. Il installe Smarves sans droits administrateur, pose un raccourci dans le menu Démarrer et sur le bureau, et se désinstalle depuis « Applications installées » ; relancé, il met le jeu à jour, et les parties sont gardées. Pour jouer sans installer : [l'archive](https://github.com/chtabay/smarves/releases/latest/download/Smarves-windows.zip), à décompresser, puis lancer `Smarves.exe`. Les deux sont reconstruits à chaque poussée sur `main` (`installer/smarves.iss` pour l'installateur). **Sur téléphone Android** : depuis le téléphone, [télécharger Smarves.apk](https://github.com/chtabay/smarves/releases/latest/download/Smarves.apk) et l'ouvrir pour l'installer (autoriser l'installation depuis le navigateur la première fois). Le téléphone utilise le rendu Mobile, plus léger que celui du PC. Tant que le dépôt est privé, le lien demande d'être connecté à GitHub avec un compte qui y a accès.

**Avec Godot** : installez [Godot 4.7](https://godotengine.org/download) (version standard), ouvrez le dossier du projet dans Godot, puis appuyez sur **F5**.

En ligne de commande :

```sh
godot --path .
```

## Commandes

- **Au village** : on dirige un habitant, le nouveau venu en costume, sur la maquette vue de dessus. ZQSD (ou WASD) pour marcher, **Maj** pour courir, **E** pour entrer, jouer ou parler, clic droit maintenu pour tourner la vue, molette pour zoomer, **Tab** pour passer à la vue à pied (première personne) et revenir. Les panneaux en bois mènent aux environs (bois de Saint-Pierre, Moulin des Dames, Passelourdin). La liste « Le village », en haut à droite, est cliquable.
- **Sur téléphone** : en vue de dessus, toucher le sol pour y marcher, toucher une porte ou un habitant pour y aller et agir, glisser pour tourner la vue, pincer pour zoomer ; à pied (au casino, ou bouton **Vue** au village), pouce virtuel à gauche et glisser à droite pour regarder ; l'invite devient un bouton ; **Vue**, **Carnet** et **Menu** dans le coin, le retour d'Android vaut Échap. Pour les essayer sur ordinateur : `godot --path . -- --tactile` (ajouter `--base=600` pour l'interface agrandie d'un téléphone) ; test : `godot --path . res://tools/test_tactile.tscn -- --tactile`.
- **Au casino** : ZQSD (ou WASD) pour marcher, souris pour regarder, **E** ou clic pour s'asseoir à une table, **Échap** pour quitter une table ou ouvrir les réglages.

## Ce qu'on trouve

- **La place de la Mairie** : la machine à sous du Café de la Place, les paris sur la pétanque, la roulette de la boulangerie, le loto de la salle Rabelais, la roue de la kermesse, le Crédit Smarvois.
- **Les environs** : la course des trois zèbres de béton au bois de Saint-Pierre, le blackjack du Moulin des Dames, le poker clandestin des rochers de Passelourdin.
- **Le Casino de Smarves**, sur le plan d'Addict : hall d'honneur, bar Le Nocturne, salle des jeux (17 machines, roulette, blackjack, craps), Salle des Ambassadeurs (poker), salon privé (baccara), et à l'étage la Galerie de la Verrière, le Bar du Fumoir, le restaurant Le Lustre, la Loggia (Grand Hasard), le Salon de musique (la Boule), la Salle des fêtes (Roue de la fortune) et les Salons particuliers (Banco).

Les lieux et les salles s'ouvrent par seuils, sur le total gagné au jeu (la Salle des fêtes sur le total misé). La partie est sauvegardée automatiquement.

## Pour les développeurs

- `scripts/main.gd` : la place et les environs (`scripts/outskirts.gd`).
- `scripts/casino_interior.gd` : le casino ; un panneau par jeu (`*_panel.gd`, `slot_machine.gd`).
- `scripts/game_state.gd` (autoload `Game`) : crédits, gains, mises, dette par prêteur ; la sauvegarde est rangée en tiroirs par `scripts/socle/sauvegarde.gd` (`user://socle.save` et un tiroir `user://communes/<id>.save` par commune ; test : `godot --headless --path . -s tools/test_sauvegarde.gd`). `scripts/sfx.gd` (autoload `Sfx`) : le son.
- Captures de vérification : `godot --path . res://scenes/main.tscn -- --capture=sortie.png [--open=cafe] [--travel=bois] [--view=distance,x,y,z,lacet,tangage]`, et pour le casino `godot --path . res://scenes/casino.tscn -- --capture=sortie.png --at=x,z,lacet,tangage[,hauteur] [--open=roulette] [--won=5000]`.
- Parcours automatique de tout le jeu (chaque lieu, chaque table, voyages, fenêtre redimensionnée, temps de rendu) : `godot --path . res://tools/smoke.tscn`. Il ne touche pas à la sauvegarde.
- `scripts/biens.gd` (autoload `Biens`) : les biens du joueur (parts, maisons, tenues, véhicules), la recette toutes les 20 mises, le financement et les reprises de M. Brunet. Fiche : [`docs/GESTION.md`](docs/GESTION.md). Simulation : `godot --headless --path . res://tools/sim_gestion.tscn` ; test : `godot --headless --path . res://tools/test_biens.tscn`.
- `communes/smarves/commune.json` : le manifeste de Smarves (lieux, seuils, salles du casino, banque, intérieurs), lu par l'autoload `Communes` (`scripts/socle/`) ; les communes greffées se déposent dans `user://communes/`. Notice : [`docs/COMMUNE.md`](docs/COMMUNE.md). Test : `godot --headless --path . -s tools/test_communes.gd`.
- Simulation de la progression : `godot --headless --path . res://tools/sim_progression.tscn` (résultats dans [`docs/EQUILIBRAGE.md`](docs/EQUILIBRAGE.md)).
- Test automatique des donnes de poker : `godot --headless --path . -s tools/test_games.gd`.
- Planche de contact d'un dossier d'assets : `godot --path . -s tools/sheet.gd -- res://assets/kaykit/city planche.png 6`.
