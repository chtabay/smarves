# Smarves : le SDK des communes

Ce dossier est un projet Godot 4.7 complet. On y construit, on y essaie et on y emballe une commune
de la Vienne pour Smarves, sans avoir besoin du dépôt du jeu. Il contient le socle du jeu en clair :
- le stade, la salle de jeu et ses dix jeux ;
- les façades du Poitou, les figurants, l'habitant et sa caméra, la carte de la Vienne ;
- les modèles et les sons libres que le socle utilise ;
- le kit de départ, les outils de test et d'emballage, et le serveur MCP pour Claude.

Le village de Smarves lui-même (sa place, son casino, ses intérieurs) n'y est pas. Le lanceur du SDK
tient sa place.

Le contrat entre le jeu et une commune est dans `docs/COMMUNE.md`. Ce qui fait un lieu réussi, et la
méthode pour y arriver, est dans `docs/CONCEPTION.md` : **à lire avant de construire**. On y trouve le
niveau visé (planches de Casino Minuit et de L'Isle-Jourdain dans `docs/references/`), les questions à
poser au porteur du projet avant de commencer, la note d'intentions (le modèle vide est
`tools/kit/INTENTIONS.md`, l'exemple complet `docs/exemples/INTENTIONS-isle-jourdain.md`), les règles
pour représenter le réel, ce qu'une commune offre en jeu, la façon de travailler avec Guillaume et de
livrer. Le ton, l'époque, le vocabulaire et l'économie en crédits sont dans `docs/BIBLE.md` (l'extrait
commun de la bible du jeu) ; la carte et les structures partagées dans `docs/SUITE.md` (extrait).

## 1. Ouvrir le SDK

1. Installer [Godot 4.7](https://godotengine.org/download/), gratuit et libre.
2. Ouvrir ce dossier avec Godot : « Importer », puis choisir `project.godot`. Le premier import des
   modèles prend une minute.
3. Lancer le projet (F5) : le lanceur liste les communes posées dans `communes/`.

En ligne de commande, depuis ce dossier :

```sh
godot --headless --path . --import
godot --headless --path . -s tools/test_commune.gd          # le kit de départ lui-même
```

## 2. Créer sa commune

Copier le kit de départ téléchargé sur le portail des développeurs : son dossier `communes/<id>/`
(manifeste, scène, script et note d'intentions à remplir) va dans `communes/`. On peut aussi partir du
modèle `tools/kit/`, en remplaçant `__ID__`, `__NOM__` et `__INSEE__`. Avec Claude, demandez `nouvelle_commune` en donnant le code INSEE (section 4).

```sh
godot --headless --path . -s tools/test_commune.gd -- <id>
```

Le test ouvre la commune comme chez un joueur. Il vérifie que la scène expose l'habitant et la
caméra, que l'habitant se pose au sol et qu'il marche.

## 3. Construire avec le socle

Avant le premier modèle, la note d'intentions (`communes/<id>/INTENTIONS.md`, d'après
`tools/kit/INTENTIONS.md` ; l'emballeur la laisse hors du paquet) : `docs/CONCEPTION.md`, « Avant de
construire ». La scène du kit ne pose aucun décor : un sol, une lumière réglable (`SOLEIL`), l'arrivée
et trois repères `Vue1_…`, `Vue2_…`, `Vue3_…`, un par scène forte.

- **L'atelier** (`scripts/socle/atelier.json`, classe `Atelier`) : modèles 3D, maisons à façades,
  figurants, meubles, sons, matières. Ils sont déjà dans le jeu chez le joueur : rien ne part dans
  votre paquet.
- **Les structures** du manifeste, dont le jeu fournit la scène et le comportement :
  - `terrain_foot` : le stade, un club dans le championnat de la Vienne ;
  - `salle_jeu` : une salle avec son tenancier et ses tables (machine, loto, blackjack, roulette,
    craps, baccara, poker, dés, roue, courses), et s'il le veut le comptoir des paris du championnat
    (`"paris": true`, socle 1.26) ;
  - `gymnase` : la salle de basket, un club sur les résultats réels de l'Euroleague et de l'EuroCup ;
  - `commerce` : une boutique de tenues, de véhicules ou de meubles ;
  - `charge` : une charge d'agent de change, la bourse à levier de Smarves au nom de votre agent (socle 1.27) ;
  - `gare` et `arret_car`.
  Voir `docs/COMMUNE.md`, « Les structures ».
- **La bibliothèque commune** (`bibliotheque/`, classe `Bibliotheque`) : des décors entiers prêts à
  servir, branchés par leurs ancres. Un stade s'écrit `"modele": "stade-de-campagne@1"` (socle 1.13),
  une salle de basket `"modele": "salle-de-quartier@1"` (socle 1.14), et les dix-neuf matières de
  Casino Minuit se prennent par `Bibliotheque.matiere("matieres-de-minuit@1", "marbre_noir")`
  (socle 1.17). Voir `docs/BIBLIOTHEQUE.md`.
- **Les tables du casino** (classe `Tables`, `scripts/socle/tables.gd`) : les tables 3D du casino de
  Smarves et leurs panneaux, dernière version, pour une salle de jeu bâtie à la main. Ne fabriquez
  pas de table avec les modèles de l'atelier et ne recopiez pas les panneaux : voir `docs/COMMUNE.md`,
  « Les tables du casino ».
- **Les autres joueurs** (socle 1.23, autoload `Presences`) : deux joueurs connectés dans la même
  scène se voient, sans une ligne de réseau dans la commune. Le manifeste règle la portée et découpe
  une grande scène en zones (`"presences"`) ; une commune peut aussi diffuser ses propres messages et
  apparier deux joueurs dans un salon à 10 positions par seconde. Voir `docs/COMMUNE.md`, « Les autres
  joueurs ». Essai sans réseau : lancer avec `-- --presences-essai` ; tests : `tools/test_presences.gd`,
  et `tools/test_presences_deux.gd` sur le vrai canal.
- **Les salles à deux** (socle 1.24, classe `SalleDuo`) : appariement, descente payante, prime unique et
  plaque tenus par le serveur ; un faux serveur (`SalleDuoEssai`) pour jouer à deux sans compte ni réseau.
  Notice : `docs/COMMUNE.md`, « Les salles à deux » ; essai bout à bout : `tools/test_salle_duo.gd`.
- **Le vrai bourg** : `python3 -I tools/bourg_reel.py <id>` tire d'OpenStreetMap et de l'IGN les
  rues, les bâtiments, l'eau et le relief.
- **Juger à hauteur de joueur** : `tools/parcours_commune.gd` pose l'habitant sur chaque repère `Vue…`
  de la scène, le photographie en vue de dessus, à pied et en se retournant, et vérifie qu'on va à pied
  d'un repère au suivant ; il marche aussi sur un paquet (`--pck=`) et sur un point donné (`--point=`).
  ```sh
  godot --path . -s tools/parcours_commune.gd -- <id>     # captures et rapport dans user://parcours/<id>/
  ```
- **Un exemple technique** : Availles-Limouzine (`tools/paquet_essai/availles_limouzine/`), bâtie dans
  sa disposition réelle depuis `bourg.json`. Il montre comment lire le plan réel, pas le niveau visé :
  ses maisons sont toutes du même modèle et rien ne s'y joue. Les références de niveau sont au
  catalogue (Casino Minuit, Cloué, L'Isle-Jourdain), voir `docs/CONCEPTION.md`, « Le niveau visé ».
  `godot --headless --path . -s tools/test_availles.gd` l'emballe et l'essaie.

## 4. Avec Claude

Le serveur MCP du kit (`tools/mcp/kit_communes.py`, Python sans dépendance) donne à Claude les
règles, la méthode de conception, l'atelier, la création d'une commune, la vérification du manifeste, le test et l'emballage.
- **Claude Code** : ouvrez `claude` dans ce dossier. Le fichier `.mcp.json` le fait proposer tout seul.
- **L'application Claude** : voir `docs/COMMUNE.md`, « Le Claude du développeur ».

## 5. Emballer et déposer

```sh
godot --headless --path . -s tools/emballer_commune.gd -- <id>
godot --headless --path . -s tools/test_commune.gd -- <id> --pck=build/<id>.pck
```

Déposez `build/<id>.pck` sur le portail des développeurs. Les règles du dépôt :
- une version par dépôt, toujours plus haute ;
- une mise à jour s'ouvre chez le joueur au lancement suivant ;
- 32 Mo au plus par paquet ;
- tout sous `res://communes/<id>/`, sans GDExtension ;
- léger : l'emballeur passe les grandes textures en WebP et dit ce qui pèse encore ;
- dans les seuils : l'emballeur bâtit chaque lieu et le mesure (triangles, lampes, textures…), dit ce
  qui dépasse et range la mesure dans le paquet, que le portail affiche (`docs/LENTEUR.md`, « Le
  budget par lieu »). `tools/budget_lieu.gd -- --pck=build/<id>.pck` mesure un paquet sans l'emballer.

## Ce que contient le SDK

Le SDK est construit par `tools/sdk/construire_sdk.py` dans le dépôt de Smarves, à chaque version
du jeu. Sa version (date et commit) est dans `sdk.json`. Prenez le SDK le plus récent, celui du jeu de vos
joueurs ; une commune qui se sert d'un type de structure récent le déclare par `socle_min` (le kit de
départ demande `1.12`, pour `Cast.moi()`). Les
licences des modèles et des sons sont dans `assets/LICENCES.md`.
