# Le socle des communes

Smarves est la première commune d'une carte de la Vienne où d'autres viendront se greffer (le cadrage est dans [`SUITE.md`](SUITE.md), section 5). Cette page dit ce qu'une commune doit fournir et ce que le socle lui expose. Le partage suit la bible ([`BIBLE.md`](BIBLE.md), en tête) : le ton, l'époque, la règle des lieux et des seuils, l'économie en crédits et le vocabulaire sont au socle ; la géographie, les lieux, les personnages, la banque et son banquier appartiennent à la commune.

Rien de ce socle ne se voit à l'écran : la carte de la Vienne et la première commune greffée (Ligugé) sont des chantiers suivants.

## Ce qu'une commune fournit

Un dossier `communes/<id>/` avec au moins un manifeste `commune.json` et la scène de la commune. Smarves a le sien : [`communes/smarves/commune.json`](../communes/smarves/commune.json).

```json
{
	"format": 1,
	"id": "smarves",
	"nom": "Smarves",
	"auteur": "chtabay",
	"version": "1.0.0",
	"socle_min": "1.0",
	"carte": {"lat": 46.51, "lon": 0.35, "socle": ""},
	"scene": "res://scenes/main.tscn",
	"arrivee": {"lot": "place", "par": []},
	"interieurs": {"casino": "res://scenes/casino.tscn", "notaire": "res://scenes/notaire.tscn"},
	"lots": {"source": "Village.lots", "script": "res://scripts/village/village.gd"},
	"lieux": [
		{"id": "petanque", "nom": "La pétanque de la place", "jeu": "les paris de Lucien", "seuil": 1000, "hote": "Lucien", "accord": "e"}
	],
	"salles": {"casino": [{"id": "fetes", "nom": "La Salle des fêtes", "seuil": 25000, "sur": "staked", "hote": "Le maître de cérémonie"}]},
	"personnages": {"source": "res://scripts/cast.gd", "nommes": ["josiane", "brunet"]},
	"banque": {"id": "credit_smarvois", "nom": "Le Crédit Smarvois", "banquier": "M. Brunet", "preteur": "smarves", "lieu": "banque"},
	"biens": {"source": "Biens.CATALOGUE", "vendeurs": ["notaire", "couture", "garage"]},
	"jeux": {"regles_serveur": []}
}
```

| Champ | Obligatoire | Ce que c'est |
|---|---|---|
| `format` | oui | la version du format de manifeste ; ce socle lit le format 1 et refuse un format plus récent |
| `id` | oui | minuscules, chiffres et `_` ; c'est le nom du dossier, du pack et du tiroir de sauvegarde |
| `nom` | oui | le nom affiché (« Smarves ») |
| `socle_min` | non | la version du socle demandée (aujourd'hui `1.0`) |
| `carte` | oui | la position sur la carte de la Vienne (latitude, longitude) et, plus tard, la scène du petit socle posé sur la carte |
| `scene` | oui | la scène de la commune ; elle doit exister au chargement |
| `arrivee` | non | le lot où l'on arrive, et les communes d'où l'on vient (le car départemental) |
| `interieurs` | non | les scènes des intérieurs, par id |
| `lots` | non | d'où viennent les portes de la commune ; pour Smarves, le dictionnaire `lots` du nœud `Village` |
| `lieux` | oui | les lieux de jeu, dans l'ordre où ils s'ouvrent : `id`, `nom`, `jeu`, `seuil` (total gagné au jeu), `hote` (qui fait signe à l'ouverture), `accord` (`e`, `s` ou rien : « ouverte », « ouverts ») |
| `salles` | non | les salles fermées d'un intérieur, par intérieur : `id`, `nom`, `seuil`, `sur` (`staked` pour un seuil sur le total misé), `hote` |
| `personnages` | non | où sont les fiches des personnages, et la liste des personnages nommés |
| `banque` | oui | la banque de la commune et son banquier ; `preteur` est la clé de la dette envers cette banque dans le socle |
| `biens` | non | les biens et leurs vendeurs |
| `jeux.regles_serveur` | non | les règles versées au serveur pour le multi (vide tant que le multi n'existe pas) |

Le socle traduit `lieux` et `salles` dans la forme que le code connaissait déjà : `main.gd` lit `PLACES` et le casino `LOCKS` depuis le manifeste de Smarves, aux mêmes valeurs qu'avant (`tools/test_communes.gd` le vérifie lieu par lieu).

## Comment une commune arrive

- **Les communes du dépôt** vivent sous `res://communes/<id>/`. Smarves y a son manifeste ; ses scènes restent pour l'instant sous `scenes/` et `scripts/`.
- **Les communes greffées** se déposent dans `user://communes/` et sont inscrites au démarrage par l'autoload `Communes`, après Smarves :
  - **en pack** : `user://communes/<id>.pck`. Le socle lit le répertoire du pack sans le monter, refuse un pack illisible ou chiffré, un pack qui contient du code natif, et un pack qui écrit ailleurs que sous `res://communes/<id>/` (seuls les fichiers qu'un export ajoute de lui-même sont admis en plus : `.godot/imported/`, `.godot/exported/`, `.godot/uid_cache.bin`, `.godot/global_script_class_cache.cfg`, `project.binary`). Il lit le manifeste `res://communes/<id>/commune.json` directement dans le pack, vérifie qu'il porte le même id que le fichier, et inscrit la commune **sans monter le pack** ;
  - **le pack n'est monté qu'au moment où l'on entre dans la commune** : la carte appelle `Communes.ouvrir(id)` juste avant de changer de scène, qui monte le pack par `ProjectSettings.load_resource_pack(chemin, false)` (il ne remplace jamais un fichier du jeu) et vérifie que la scène est là. Le jeu pèse déjà une cinquantaine de mégaoctets pour Smarves seule ; sur le web surtout, une commune de plus ne doit rien coûter au lancement ;
  - **en dossier** : `user://communes/<id>/commune.json`, pour une commune faite de données et de scènes texte. Le nom du dossier doit être l'id du manifeste.
- Une commune dont le manifeste a une erreur, ou dont l'id est déjà pris, n'est pas inscrite ; la raison est gardée dans `Communes.refus` et écrite en avertissement.
- **Une commune ne contient que des scènes, des ressources et du GDScript, jamais de code natif.** Une GDExtension (fichiers `.gdextension`, `.so`, `.dll`, `.dylib`, `.wasm`) ne se charge pas dans la version web du jeu : le socle refuse le pack qui en contient.
- **Un pack contient du code**, et Godot ne sait pas isoler un script : un mod a les mêmes droits que le jeu. Les communes greffées sont des mods de confiance, installés à la main.
- Les captures (`--capture=`) et les outils de test ne chargent aucune greffe : ils partent du jeu seul.

Le mécanisme est éprouvé par `tools/test_communes.gd`, qui emballe la commune d'essai de [`tools/commune_essai/`](../tools/commune_essai/) en pack avec `PCKPacker`, l'inscrit sans la monter, l'ouvre, charge sa scène depuis le pack, puis vérifie qu'un pack qui voudrait remplacer `scripts/game_state.gd`, un pack avec du code natif, un pack abîmé et un dossier dont le manifeste ment sur son id sont refusés :

```sh
godot --headless --path . -s tools/test_communes.gd
```

## Ce que le socle expose

### `Communes` (autoload, `scripts/socle/communes.gd`)

| | |
|---|---|
| `communes`, `ordre` | les communes inscrites (id → `Commune`), dans l'ordre d'inscription ; Smarves d'abord |
| `commune(id)`, `origine()` | une commune, et Smarves |
| `inscrite(id)` | signal : une commune vient d'être inscrite |
| `charger_pack(chemin)`, `charger_dossier(chemin)`, `charger_greffes()` | inscrire une commune greffée ; renvoie son id, ou `""` si elle est refusée |
| `ouvrir(id)` | monter son pack s'il ne l'est pas et vérifier sa scène, avant d'y entrer |
| `refus` | les greffes refusées : `[chemin, raison]` |
| `lister_pack(chemin)`, `repertoire_pack(chemin)` | les fichiers d'un pack (formats 2 à 4 de Godot 4), ou `null` |

### `Commune` (classe, `scripts/socle/commune.gd`)

`Commune.lire(chemin)` lit et vérifie un manifeste ; `valide()` et `erreurs` disent s'il est bon. `lieux()` et `salles(interieur)` rendent les lieux et les salles dans la forme de `PLACES` et `LOCKS` ; `preteur()`, `banque()` et `interieur(id)` lisent le reste. `Commune.smarves()` est Smarves, lue une fois.

### La sauvegarde en tiroirs (`scripts/socle/sauvegarde.gd`)

| Fichier | Qui l'écrit | Ce qu'il tient |
|---|---|---|
| `user://socle.save` | `Game` | ce qui vaut pour toutes les communes : `bourse` (crédits), `gagne` (le total gagné au jeu, la clé de tous les seuils), `mise`, `pic`, `dettes` (par prêteur : `{"smarves": 4297}`) |
| `user://communes/<id>.save` | `Game`, pour chaque commune | le tiroir de la commune ; celui de Smarves tient `avances` (Josiane), `prets` (accordés par M. Brunet) et `accueil` |
| `user://smarves_biens.save` | `Biens` | les biens, comme avant (et les logements du fil Gestion) ; le fichier ne bouge pas |

- **Au premier lancement**, l'ancien fichier unique `user://smarves.save` est lu une fois, réécrit en tiroirs, puis renommé `smarves.save.ancien` : rien n'est perdu, et l'ancien fichier ne repasse jamais devant les tiroirs. Un outil lancé par `-s` lit l'ancien fichier sans le migrer. `tools/test_sauvegarde.gd` écrit une partie à l'ancien format, la migre, la relit, et relit aussi un fichier de biens à l'ancien format.
- **Une commune greffée range ses affaires** dans `Game.tiroir("<id>")`, un dictionnaire de valeurs JSON, écrit avec la partie à chaque `Game.changed`. Elle n'écrit jamais dans le socle.
- **La dette est tenue par prêteur.** `Game.borrow(montant, preteur)`, `Game.repay(montant, preteur)` et `Game.debt_of(preteur)` ; sans prêteur, c'est celui de la commune d'origine (`banque.preteur` du manifeste de Smarves, donc M. Brunet). `Game.debt` reste le total, et l'écrire ajuste le prêteur par défaut : le code d'avant (Biens, le guichet de M. Brunet, le carnet) garde le même sens. Les intérêts courent pour chaque prêteur, au même taux.
- **Nouvelle partie** : `Game.reset()` efface le socle et tous les tiroirs.

### Ce qui existe déjà et reste à rendre générique

Ces API existent dans le code de Smarves ; le cadrage (SUITE.md, section 5) dit comment elles s'ouvriront aux autres communes, dans l'ordre des chantiers :

- `Game` : crédits, gagné au jeu (`won`, la clé partagée par toutes les communes), misé, dette par prêteur, `changed`, `brunet_calls`, `spend`, `cash_in`, `borrow`, `repay` ; plus tard une source (`commune/lieu`) sur `spend` et `cash_in`, et un signal `played(source, mise, gain)`.
- `Biens` : catalogue, `buy`, `sell`, la recette toutes les 20 mises ; plus tard `Biens.register(commune_id, items)`.
- `Carnet` : ses pages, `show_slip` ; plus tard une page et une adresse par commune.
- `Village.lots` : les portes de Smarves, avec leur `Area3D` (métadonnée `action`) ; plus tard une classe `Lots` commune.
- Les seuils : aujourd'hui `PLACES` (main.gd) et `LOCKS` (casino), lus depuis le manifeste ; plus tard un registre `Seuils` qui annonce les ouvertures de toutes les communes.
- `Cast.NAMED` et `Cast.resolve()` : les personnages ; plus tard `Cast.register(commune_id, fiches)`.
