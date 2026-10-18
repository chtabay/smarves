# Le socle des communes

Smarves est la première commune d'une carte de la Vienne où d'autres viendront se greffer (le cadrage est dans [`SUITE.md`](SUITE.md), section 5). Cette page dit ce qu'une commune doit fournir et ce que le socle lui expose. Le partage suit la bible ([`BIBLE.md`](BIBLE.md), en tête) : le ton, l'époque, la règle des lieux et des seuils, l'économie en crédits et le vocabulaire sont au socle ; la géographie, les lieux, les personnages, la banque et son banquier appartiennent à la commune.

La carte de la Vienne est un écran du jeu depuis le 18 octobre 2026 (section suivante), éprouvé par une commune d'essai, Ligugé, livrée en paquet séparé ; une commune publiée sur le portail se trouve aussi dans la bienvenue et le carnet (section « Publier sa commune »).

## La carte de la Vienne

**L'emplacement des communes est celui de la carte officielle des communes de la Vienne** (décision de Guillaume, 17 octobre 2026). Le référentiel [`communes/vienne.json`](../communes/vienne.json) tient les 265 communes actuelles du département : code INSEE, nom, population, centre et contour en longitude et latitude. Il est construit par `tools/vienne_communes.py` à partir de la liste officielle des communes (paquet `@etalab/decoupage-administratif`) et des contours de l'IGN ; le contour d'une commune nouvelle (Valence-en-Poitou, Saint-Martin-la-Pallu…) est l'union de ses anciennes communes. On ne place jamais une commune à la main : son manifeste donne son code INSEE, et la carte la pose là où elle est.

**Toutes les communes sont sur la carte, seules les communes développées sont cliquables.** `Communes.carte()` rend les 265 communes ; `cliquable` n'est vrai que pour celles qui sont inscrites au registre avec ce code INSEE (aujourd'hui Smarves seule). Les autres restent des silhouettes. Poitiers reste un trou dans la brume, jamais développé (SUITE.md, section 5).

### L'écran de la carte

L'autoload `Carte` (`scripts/carte.gd`) montre la carte en plein écran, dessinée par la même `CarteVienne` que la bienvenue, rendue navigable :

- **On y arrive** en dézoomant au-delà du cran « quartier » du village (molette, ou pincer sur téléphone : la caméra `orbit_camera.gd` émet `au_dela`), avec la touche M, depuis la bienvenue (« Ouvrir la carte »), ou dès le menu de départ (bouton « La carte », entre « Jouer » et « Réglages ») : là, on n'est encore nulle part, « Revenir » rend le menu et choisir Smarves (« Jouer à Smarves ») ou une ville installée lance la partie. Dans une commune greffée, M et le bouton « La carte », posé à côté de « Revenir à Smarves », l'ouvrent aussi.
- **On en repart** en zoomant encore sur sa commune quand la carte est au plus près, avec Échap ou M, ou par « Revenir ». La carte replonge sur la commune et s'efface.
- **Ce qu'on voit** : Smarves en or, les villes installées en vert d'eau vif, les villes publiées en vert d'eau pâle, les autres en filigrane, avec leur nom en filigrane quand on zoome ; le Clain et la Vienne (tracé approché, de commune riveraine en commune riveraine) ; Poitiers dans une brume qui dérive ; une épingle sur la commune où l'on est. Une commune qui arrive (publiée ou installée depuis la dernière ouverture) s'allume sous les yeux du joueur ; celles déjà vues sont retenues dans `user://communes/allumees.json`.
- **Toucher une commune** la montre dans la fiche (nom, population, état, description du catalogue) avec ce qu'on peut y faire : « Y aller » pour une ville installée, « Rentrer à Smarves », « Installer » pour une ville publiée. Poitiers et les communes pas encore développées ne mènent nulle part.

**Rien à changer dans un paquet pour la carte** : elle lit le code INSEE, la scène, le nom, la version, l'auteur et la description, déjà au format. Une commune qui veut ouvrir la carte depuis sa propre caméra appelle `Carte.ouvrir()` (Ligugé le fait au-delà de son dernier cran, comme le village).

**Ligugé**, la commune d'essai (`tools/paquet_essai/liguge/`), est un paquet qui apporte son script : le prieuré Saint-Martin, le Clain et son pont, quelques maisons et le Café du Pont, fermé, construits en code, avec la caméra à crans de Smarves. `tools/test_carte.gd` l'emballe, la greffe, vérifie qu'elle s'allume, qu'on y va depuis la carte, qu'on rouvre la carte depuis Ligugé et qu'on rentre à Smarves :

```sh
godot --headless --path . -s tools/test_carte.gd
godot --headless --path . -s tools/emballer_commune.gd -- liguge --depuis=res://tools/paquet_essai/liguge/
```

Le second emballe Ligugé dans `build/liguge.pck` ; déposé dans le dossier `communes/` des données du jeu (sous Windows `%APPDATA%\Godot\app_userdata\Smarves\communes\`), il s'allume sur la carte au lancement suivant.

**Availles-Limouzine** (`tools/paquet_essai/availles_limouzine/`, code INSEE 86015) est la première commune construite **dans sa disposition réelle** (demande de Guillaume, 18 octobre 2026). `tools/bourg_reel.py` tire des données ouvertes le plan du bourg : les rues, les places, les ponts, l'eau et les bois d'OpenStreetMap ; l'emprise, la hauteur et le toit de chaque bâtiment de la BD TOPO de l'IGN ; le relief du RGE ALTI (grille de 5 m). Il écrit `bourg.json` (en unités du jeu, 1 unité = 2,4 m, comme Smarves) et `sol.png` (la couverture du sol), que `availles.gd` construit à l'ouverture : terrain avec collision, rues en rubans posés sur le relief, 919 bâtiments dessinés comme les maisons du Poitou de Smarves (`scripts/village/facades.gd` : calcaire, chaînes d'angle, volets, tuiles canal), chacune posée sur son emprise réelle, façade tournée vers la rue (le rectangle de la maison, son orientation et le côté de la rue sont calculés par `bourg_reel.py`) ; les emprises en L ou en U gardent leurs vrais murs, percés de fenêtres, la Vienne et son pont (on marche dessus, les rives arrêtent), les arbres en MultiMesh, les noms de rues couchés sur la chaussée. Les lieux remarquables (église Saint-Martin, mairie, portes des Cavaliers et de la Rivière, logis de la Châtellenie, halles, commerces de la place…) sont des nœuds à part, `Remarquable_<id>`, avec leur objet OpenStreetMap en métadonnée. `remarquables.gd` y dessine ceux qui ont déjà leur vraie silhouette, d'après photo, avec les pièces de `facades.gd` : l'hôtel-restaurant de la Châtellenie (enduit ocre, volets verts, génoise, vitrines, enseigne, terrasse) le 10 place Adrien-Bernard (enduit crème, chaînes d'angle, toit d'ardoise à pignon, dépendance, palissade, lampadaire), la mairie (pavillon à deux niveaux et ses deux ailes à oculus, porte bleue, balcon aux drapeaux, plaque, fenêtres cintrées, rampe, lampadaires) et la porte des Cavaliers (passage voûté dans un mur de moellons, tour ronde à toit conique, maison à volets blancs sur la place) ; les autres attendent la leur et sont dessinés comme des maisons du bourg. Rien ne s'y joue. Test et capture :

```sh
python3 tools/bourg_reel.py availles_limouzine        # régénère bourg.json et sol.png (cache dans build/bourg_reel/)
godot --headless --path . -s tools/test_availles.gd
godot --path . -s tools/test_availles.gd -- --capture=bourg.png --a=51,38,2,-20   # x, z, cran, lacet
godot --headless --path . -s tools/emballer_commune.gd -- availles_limouzine --depuis=res://tools/paquet_essai/availles_limouzine/
```

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
	"insee": "86263",
	"carte": {"socle": ""},
	"scene": "res://scenes/main.tscn",
	"arrivee": {"lot": "place", "par": []},
	"interieurs": {"casino": "res://scenes/casino.tscn", "notaire": "res://scenes/notaire.tscn", "rabelais": "res://scenes/rabelais.tscn"},
	"lots": {"source": "Village.lots", "script": "res://scripts/village/village.gd"},
	"lieux": [
		{"id": "rabelais", "nom": "La salle François-Rabelais", "jeu": "le grand loto", "seuil": 8000, "hote": "M. Gaudin", "accord": "e"}
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
| `insee` | oui | le code INSEE d'une commune actuelle de la Vienne (`86263` pour Smarves) : c'est lui qui place la commune sur la carte, à sa vraie place ; deux communes développées ne peuvent pas avoir le même |
| `carte` | non | plus tard, la scène du petit socle posé sur la carte |
| `scene` | oui | la scène de la commune ; elle doit exister au chargement |
| `arrivee` | non | le lot où l'on arrive, et les communes d'où l'on vient (le car départemental) |
| `interieurs` | non | les scènes des intérieurs, par id |
| `lots` | non | d'où viennent les portes de la commune ; pour Smarves, le dictionnaire `lots` du nœud `Village` |
| `lieux` | oui | les lieux de jeu, dans l'ordre où ils s'ouvrent : `id`, `nom`, `jeu`, `seuil` (total gagné au jeu), `hote` (qui fait signe à l'ouverture), `accord` (`e`, `s` ou rien : « ouverte », « ouverts »). On ne joue pas dehors : un lieu de jeu se joue dans l'intérieur de même id (`interieurs`), sinon il reste fermé |
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
- Une commune dont le manifeste a une erreur (dont un code INSEE qui n'est pas une commune actuelle de la Vienne), dont l'id est déjà pris ou dont le code INSEE est déjà développé, n'est pas inscrite ; la raison est gardée dans `Communes.refus` et écrite en avertissement.
- **Une commune ne contient que des scènes, des ressources et du GDScript, jamais de code natif.** Une GDExtension (fichiers `.gdextension`, `.so`, `.dll`, `.dylib`, `.wasm`) ne se charge pas dans la version web du jeu : le socle refuse le pack qui en contient.
- **Un pack contient du code**, et Godot ne sait pas isoler un script : un mod a les mêmes droits que le jeu. Les communes greffées sont des mods de confiance, installés à la main.
- Les captures (`--capture=`) et les outils de test ne chargent aucune greffe : ils partent du jeu seul.

Le mécanisme est éprouvé par `tools/test_communes.gd`, qui emballe la commune d'essai de [`tools/commune_essai/`](../tools/commune_essai/) en pack avec `PCKPacker`, l'inscrit sans la monter, l'ouvre, charge sa scène depuis le pack, puis vérifie qu'un pack qui voudrait remplacer `scripts/game_state.gd`, un pack avec du code natif, un pack abîmé et un dossier dont le manifeste ment sur son id sont refusés :

```sh
godot --headless --path . -s tools/test_communes.gd
```

## Publier sa commune

Une commune se publie sur **le portail des développeurs**, la page `/developpeur` de Pyramides (https://pyramides2.vercel.app/developpeur), réservée au rôle développeur de Pyramides (et à l'organisateur). Le jeu, lui, ne fait que lire un catalogue public et installer des paquets ; il n'a besoin d'aucun compte.

### Le geste

1. Sur la page, choisir sa commune parmi les 265 de la Vienne (Smarves et Poitiers exceptées) et **télécharger le kit de départ** : une commune minimale que le jeu accepte telle quelle (manifeste prérempli avec le nom, le code INSEE et l'id, une scène avec un sol, une lumière, une caméra et le panneau de la commune), et son mode d'emploi `LISEZMOI.md`.
2. Poser le dossier du kit dans `communes/` d'un clone de Smarves, construire la commune, puis l'emballer :
   ```sh
   godot --headless --path . -s tools/emballer_commune.gd -- <id>
   ```
   L'outil écrit `build/<id>.pck` et le fait passer par les refus du jeu (`Communes.charger_pack`, montage, chargement de la scène). `--depuis=res://…/` emballe un autre dossier sous `communes/<id>/` (c'est ainsi qu'est fait le paquet d'essai, `tools/paquet_essai/`).
3. **Déposer** le `.pck` sur la page : il part directement du navigateur vers le stockage, puis le serveur le relit et affiche **le rapport de validation**, une ligne par règle. Un paquet valide est « prêt » ; **publier** le met au catalogue (une seule version publiée par commune, la nouvelle remplace l'ancienne), **dépublier** l'en retire. Chaque dépôt garde sa ligne : c'est l'historique des versions.

Une commune est **tenue** par l'auteur de son premier paquet valide : lui seul y dépose et publie ensuite, avec l'organisateur.

### Le paquet

- Un **pack Godot 4** (`.pck`, formats 2 à 4, non chiffré), nommé par l'id de la commune. Pas une archive zip : c'est le format que le socle sait lire sans le monter.
- **Tout sous `res://communes/<id>/`**, plus seulement ce qu'un export ajoute de lui-même (`.godot/imported/`, `.godot/exported/`, `.godot/uid_cache.bin`, `.godot/global_script_class_cache.cfg`, `project.binary`). L'id est celui du manifeste ; le kit le tire du nom (« La Villedieu-du-Clain » → `la_villedieu_du_clain`).
- **Aucun code natif** : ni `.gdextension`, ni `.so`, `.dll`, `.dylib`, `.wasm`, `.framework`. Scènes, ressources et GDScript seulement.
- **32 Mo au plus.**
- Un seul manifeste, `res://communes/<id>/commune.json`, au format décrit plus haut, avec en plus pour la publication :
  - `insee` : la commune choisie sur la page, une commune actuelle de la Vienne de `communes/vienne.json`, ni Smarves (86263) ni Poitiers (86194) ;
  - `version` : trois nombres (`0.1.0`), neuve pour cette commune (un dépôt refusé ne consomme pas sa version) ;
  - `scene` : sous `res://communes/<id>/`, présente dans le pack (ou sa forme exportée `.remap`) ;
  - `banque.preteur` : le prêteur de la commune, jamais `smarves` (c'est la dette envers M. Brunet) ;
  - `description` (facultative) : deux phrases, montrées dans le carnet du joueur.
- L'id n'appartient qu'à une commune : il nomme le pack et le tiroir de sauvegarde chez le joueur.

La page refuse ce que le jeu refuserait, règle pour règle (`src/lib/communes/paquet.ts` dans Pyramides2, en miroir de `scripts/socle/communes.gd` et `commune.gd`) ; elle est plus stricte sur la version, la commune choisie et le prêteur. Le format de pack est lu de la même façon des deux côtés.

### Le catalogue

`GET https://pyramides2.vercel.app/api/communes`, sans compte, ouvert à toutes les origines (la version web le lit depuis son propre domaine). Seuls les paquets **publiés** y figurent :

```json
{
	"format": 1,
	"genere_le": "2026-10-17T21:00:00.000Z",
	"communes": [
		{"insee": "86290", "id": "la_villedieu_du_clain", "nom": "La Villedieu-du-Clain", "auteur": "Claude",
		 "version": "0.1.0", "description": "…", "paquet": "https://pyramides2.vercel.app/api/communes/86290/la_villedieu_du_clain-0.1.0.pck",
		 "taille": 1900, "sha256": "…", "publie_le": "2026-10-17T21:00:00.000Z"}
	]
}
```

`paquet` redirige vers une adresse signée de dix minutes, et seulement tant que cette version est la version publiée. Les paquets vivent dans le stockage du projet Supabase de Pyramides (seau privé `communes`), leurs lignes dans la table `commune_packages` du schéma `pyramides2`.

### Dans le jeu

- **Au lancement**, `Communes` lit le catalogue s'il y a du réseau (dix secondes au plus, en arrière-plan, sans rien bloquer) ; sinon il garde la dernière copie (`user://communes/catalogue.json`). `Communes.catalogue_etat` dit `en_ligne` ou `hors_ligne`, le signal `catalogue_lu` l'annonce. `Portail.entrees()` ignore sans bruit une entrée abîmée.
- **La bienvenue** (autoload `Bienvenue`, `scripts/bienvenue.gd`) : à chaque lancement, dès que le joueur est sur la place (après l'accueil de Josiane, hors carnet et réglages), une fenêtre s'ouvre. À gauche, la carte de la Vienne (`CarteVienne`, `scripts/socle/carte_vienne.gd`) : Smarves en or, les villes publiées en vert d'eau, plus vif quand elles sont installées. À droite, les crédits, « Les villes de la Vienne » (les nouvelles depuis la dernière visite, `Communes.nouvelles`, sinon ce qui est disponible) avec « Voir les villes », qui déplie la liste à installer et à visiter sur place, « Votre compte », où viendra la connexion, et « Jouer ». En la refermant, les villes vues ne sont plus nouvelles (`user://communes/vues.json`).
- **Le carnet** (touche C) a une rubrique « Les communes de la Vienne » : chaque commune publiée, sa description, « → l'installer » (taille, auteur), puis « → y aller ». Une version plus récente au catalogue se propose à la place ; elle s'installe à côté et prend la place de l'ancienne au lancement suivant, parce qu'un pack déjà ouvert ne se remplace pas en cours de partie.
- **L'installation** (`Communes.installer(id)`) télécharge le paquet dans `user://communes/<id>.pck`, vérifie son empreinte sha256 contre le catalogue, puis le soumet aux refus d'une greffe déposée à la main ; un paquet refusé est effacé. Le signal `installee(id, ok, message)` donne la phrase montrée au joueur.
- **Y aller** (`Communes.visiter(id)`) monte le pack, ouvre la scène de la commune et pose les boutons « Revenir à Smarves » (`Communes.revenir()`) et « La carte ». `Communes.actuelle()` dit dans quelle commune on est.
- **Pour la carte** : `Communes.carte()` porte en plus `publiee` (au catalogue, installable) à côté de `cliquable` (installée) ; `Communes.publiees()` et `Communes.installees()` donnent les deux listes.

Le chemin entier est vérifié par `tools/test_portail.gd` : un petit serveur local tient lieu de portail, sert un catalogue et le paquet d'essai de La Villedieu-du-Clain, que le jeu lit, installe, inscrit et ouvre ; un paquet à l'empreinte fausse est refusé et effacé ; hors ligne, la liste reste.

```sh
godot --headless --path . -s tools/test_portail.gd
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
| `par_insee(code)` | la commune développée à ce code INSEE, ou `null` |
| `carte()` | les 265 communes de la Vienne : `insee`, `nom`, `centre` (Vector2 longitude, latitude), `contour` (polygones de points [longitude, latitude]), `id` et `cliquable` (vrai si développée) |
| `lister_pack(chemin)`, `repertoire_pack(chemin)` | les fichiers d'un pack (formats 2 à 4 de Godot 4), ou `null` |
| `catalogue`, `catalogue_etat`, `lire_catalogue()`, `catalogue_lu` | les communes publiées sur le portail, lues au lancement (voir « Publier sa commune ») |
| `publiees()`, `installees()`, `au_catalogue(id)` | les deux listes pour la carte, et une entrée du catalogue |
| `installer(id)`, `installee`, `en_cours`, `installations` | installer une commune publiée ; versions installées |
| `visiter(id)`, `revenir()` | entrer dans une commune greffée, et revenir à Smarves |

### `Commune` (classe, `scripts/socle/commune.gd`)

`Commune.lire(chemin)` lit et vérifie un manifeste ; `valide()` et `erreurs` disent s'il est bon. `lieux()` et `salles(interieur)` rendent les lieux et les salles dans la forme de `PLACES` et `LOCKS` ; `preteur()`, `banque()`, `interieur(id)` et `centre()` (la position réelle, d'après le code INSEE) lisent le reste.

### `Vienne` (classe, `scripts/socle/vienne.gd`)

Le référentiel : `Vienne.communes()`, `Vienne.commune(insee)`, `Vienne.centre(insee)`. `Commune.smarves()` est Smarves, lue une fois.

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
