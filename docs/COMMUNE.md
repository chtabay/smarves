# Le socle des communes

Smarves est la première commune d'une carte de la Vienne où d'autres viendront se greffer (le cadrage est dans [`SUITE.md`](SUITE.md), section 5). Cette page dit ce qu'une commune doit fournir et ce que le socle lui expose. Le partage suit la bible ([`BIBLE.md`](BIBLE.md), en tête) : le ton, l'époque, la règle des lieux et des seuils, l'économie en crédits et le vocabulaire sont au socle ; la géographie, les lieux, les personnages, la banque et son banquier appartiennent à la commune.

**Ce que le jeu accepte n'est pas ce qui fait un beau lieu.** La méthode de conception (la note d'intentions, les trois scènes fortes, la continuité habitée entre elles, la palette chiffrée, l'animation et la vie, les passes d'approfondissement et la critique indépendante) est dans [`CONCEPTION.md`](CONCEPTION.md). Elle n'est vérifiée ni par l'emballeur ni par le portail ; elle est ce qu'on attend d'une commune.

La carte de la Vienne est un écran du jeu depuis le 18 octobre 2026 (section suivante), éprouvé par une commune d'essai, Ligugé, livrée en paquet séparé ; une commune publiée sur le portail se trouve aussi dans la bienvenue et le carnet (section « Publier sa commune »).

## La carte de la Vienne

**L'emplacement des communes est celui de la carte officielle des communes de la Vienne** (décision de Guillaume, 17 octobre 2026). Le référentiel [`communes/vienne.json`](../communes/vienne.json) tient les 265 communes actuelles du département : code INSEE, nom, population, centre et contour en longitude et latitude. Il est construit par `tools/vienne_communes.py` à partir de la liste officielle des communes (paquet `@etalab/decoupage-administratif`) et des contours de l'IGN ; le contour d'une commune nouvelle (Valence-en-Poitou, Saint-Martin-la-Pallu…) est l'union de ses anciennes communes. On ne place jamais une commune à la main : son manifeste donne son code INSEE, et la carte la pose là où elle est.

**Toutes les communes sont sur la carte, seules les communes développées sont cliquables.** `Communes.carte()` rend les 265 communes ; `cliquable` n'est vrai que pour celles qui sont inscrites au registre avec ce code INSEE (aujourd'hui Smarves seule). Les autres restent des silhouettes. Poitiers reste un trou dans la brume, jamais développé (SUITE.md, section 5).

### Les destinations lointaines (socle 1.5)

**Une commune peut être ailleurs que dans la Vienne** : un grand casino de Las Vegas, une ville de bord de mer. Elle n'a pas de code INSEE et n'est pas dessinée sur la carte ; son manifeste porte le champ `ailleurs` et demande `"socle_min": "1.5"` :

```json
"ailleurs": {"ville": "Las Vegas", "pays": "États-Unis", "aeroport": "McCarran", "vol": "MN 1203 · via Paris-Charles-de-Gaulle"}
```

- **On y va en avion, depuis Poitiers-Biard.** La fiche de Poitiers sur la carte dit que l'aéroport a des vols et offre « Embarquer pour <ville> → » pour chaque destination installée. Le vol (`Carte.voler(id)`) est un écran de passage : « VOL POUR LAS VEGAS », la ligne Poitiers-Biard → l'aéroport (la ville à défaut) et le numéro de vol, un avion qui suit un arc d'or ; puis la scène de la commune.
- **On en revient de même.** Dans une commune lointaine, le bouton du coin dit « Reprendre l'avion » au lieu de « Revenir à Smarves », et la carte, cadrée sur Poitiers, montre la fiche de la ville avec « Reprendre l'avion → » ; `Carte.voler()` ramène à Smarves.
- **Ce que le socle vérifie** (`Commune.verifier_ailleurs`) : un objet, une ville, des textes, aucun champ inconnu, pas de code INSEE, et un socle 1.5 au moins. Deux communes lointaines n'entrent pas en conflit de code INSEE ; `Communes.lointaines()` les liste, `Commune.lointaine()`, `ville()`, `pays()`, `aeroport()` et `vol()` les lisent. Le test est `tools/test_ailleurs.gd`.
- **Son club joue dans la Vienne.** Une commune lointaine qui déclare un terrain a son club au championnat comme les autres ; au registre, son centre est celui de Poitiers, d'où partent ses vols. Le Racing Club Minuit (rouge laque et or) joue ainsi l'Étoile de Smarves.
- **Le premier exemple est Casino Minuit** (`tools/paquet_essai/casino_minuit/`), le casino de Guillaume porté du moteur web en GDScript : la rotonde d'entrée, l'atrium et son bar, le grand escalier, la galerie de la mezzanine. Les tables et les salles y sont pour l'instant fermées (lieux à seuil) ; le couloir du stade, dans l'allée est du grand escalier, s'ouvre à 3 000 gagnés. Le portail n'accepte pas encore les paquets lointains.

### L'écran de la carte

L'autoload `Carte` (`scripts/carte.gd`) montre la carte en plein écran, dessinée par la même `CarteVienne` que la bienvenue, rendue navigable :

- **On y arrive** en dézoomant au-delà du cran « quartier » du village (molette, ou pincer sur téléphone : la caméra `orbit_camera.gd` émet `au_dela`), avec la touche M, depuis la bienvenue (« Ouvrir la carte »), ou dès le menu de départ (bouton « La carte », entre « Jouer » et « Réglages ») : là, on n'est encore nulle part, « Revenir » rend le menu et choisir Smarves (« Jouer à Smarves ») ou une ville installée lance la partie. Dans une commune greffée, M et le bouton « La carte », posé à côté de « Revenir à Smarves », l'ouvrent aussi.
- **On en repart** en zoomant encore sur sa commune quand la carte est au plus près, avec Échap ou M, ou par « Revenir ». La carte replonge sur la commune et s'efface.
- **Ce qu'on voit** : Smarves en or, les villes installées en vert d'eau vif, les villes publiées en vert d'eau pâle, les autres en filigrane, avec leur nom en filigrane quand on zoome ; le Clain et la Vienne (tracé approché, de commune riveraine en commune riveraine) ; Poitiers dans une brume qui dérive ; une épingle sur la commune où l'on est. Une commune qui arrive (publiée ou installée depuis la dernière ouverture) s'allume sous les yeux du joueur ; celles déjà vues sont retenues dans `user://communes/allumees.json`.
- **Toucher une commune** la montre dans la fiche (nom, population, état, description du catalogue) avec ce qu'on peut y faire : « Y aller » pour une ville installée, « Rentrer à Smarves », « Installer » pour une ville publiée. Poitiers et les communes pas encore développées ne mènent nulle part.
- **Le car et la route.** Sur la place, l'arrêt du car départemental (à droite, entre deux platanes) ouvre la carte « Arrêt de la Place » : des tirets d'or partent de Smarves vers chaque commune où l'on peut aller (installée ou publiée), et l'on monte avec « Monter dans le car ». Au bout de chaque route, sur les socles des environs, un panneau blanc bordé de rouge porte le nom de la commune voisine dans cette direction (`Vienne.voisine`, la plus proche à moins de 40° du cap) : Ligugé à l'ouest (moulin), Nouaillé-Maupertuis à l'est (bois), Saint-Benoît au nord (Passelourdin). Il ouvre la carte tournée vers elle, avec « Prendre la route », « Installer », ou, si personne ne l'a encore construite, la promesse qu'elle s'allumera. Pas de gare : Smarves n'en a pas ; une commune qui en a une pourra poser la sienne.
- **Où l'on est, où aller** (socle 1.18). En haut à gauche, le fil d'Ariane « France › Nouvelle-Aquitaine › Vienne » dit ce qu'on regarde, et chaque cran y remonte d'un clic. Dessous, « Où aller » liste les villes du département qui sont dans le jeu, ouvertes ou à installer, les plus proches d'abord avec leur distance ; au car, ce sont « Les arrêts du car ». Un nom de la liste désigne la ville : la carte s'en approche et un trajet en tirets blancs part de la commune où l'on est. La fiche d'une ville dit **ce qu'on y trouve** (ses salles de jeu et leurs jeux, son club, ses commerces, lus dans ses structures) et **le trajet** (« 33 km · 49 min en car départemental », `Carte.trajet(insee)`). D'un département à l'autre, on passe par les **chefs-lieux**, les gares des départements (socle 1.19) : le car départemental jusqu'au sien, le car régional vers un chef-lieu de la même région ou l'avion vers celui d'une autre région (de Poitiers-Biard pour la Vienne), puis le car jusqu'à la ville ; le retour fait le même chemin (« 313 km · 5 h 48 · car départemental jusqu'à Poitiers, puis car régional jusqu'à Bordeaux, puis car départemental jusqu'à Libourne »). Sur la carte d'un autre département, sa gare est un carré d'or, et le trajet en part. Au téléphone, un bouton « Carte » s'ajoute à « Vue », « Carnet » et « Menu » ; au clavier, la ligne d'aide dit « M : carte ».
- **La France, ses régions, ses départements** (socle 1.18). Dézoomer encore sur le département entier montre la France : les 13 régions cernées et nommées, la Vienne en or, la Nouvelle-Aquitaine teintée (le car régional en dessert les départements), un département où une ville est dans le jeu en vert d'eau. Sur la France entière, on désigne une **région** ; « Voir la région » s'en approche (`Carte.vers_region`) et l'on y désigne ses **départements**. Les douze départements de la Nouvelle-Aquitaine et, depuis le socle 1.19, les douze de l'Auvergne-Rhône-Alpes sont connus commune par commune (`Departements`, `communes/departements/<code>.json`, construits par `tools/departement_communes.py`) : « Voir ses communes », ou zoomer dessus, y descend (`Carte.vers_departement`), avec ses plus grandes villes pour repères. Ailleurs, la fiche dit comment on y ira, en car régional ou en avion depuis le chef-lieu d'où l'on part. Une commune de ces départements se greffe comme une commune de la Vienne et s'allume sur leur carte ; le portail et le SDK doivent encore l'accepter.
- **Les mises à jour.** Une ville installée dont le catalogue publie une version plus récente porte sous son nom une pastille d'or « mise à jour 0.2.0 » ; sa fiche dit « MISE À JOUR » et offre « Mettre à jour » à côté de « Y aller ». Une ville pas encore visitée dans la partie prend sa nouvelle version tout de suite ; une ville déjà visitée a son pack monté, que Godot ne sait pas remplacer : la nouvelle version attend le prochain lancement, et la fiche propose « Relancer maintenant » (la partie est enregistrée d'abord ; sur téléphone, on dit de fermer et rouvrir le jeu).
- **Un seul état, les mêmes mots partout.** `Communes.etat(id)` dit où en est une ville (« publiee », « telechargement », « attente », « echec », « a_relancer », « mise_a_jour », « a_jour ») ; `resume(id)` le dit en français et `geste(id)` donne le bouton à proposer (Installer, Mettre à jour, Réessayer, Relancer maintenant). La bienvenue, la carte et le carnet s'en servent tous, et écoutent `etat_change`. Les téléchargements passent un par un (les autres attendent leur tour) et montrent une `BarreProgres` ; un échec garde son message jusqu'au prochain essai.
- **Ce qui se fait tout seul.** Au lancement, le jeu relit sa version et le catalogue. Une ville publiée s'installe toute seule : le portail ne publie que des villes déjà validées avec leurs développeurs (« Nouvelle sur la carte : Vivonne »). Une ville installée mais pas encore ouverte dans la partie prend sa nouvelle version sans rien demander (« Ligugé s'est mise à jour toute seule »). Le reste attend un geste : mettre à jour une ville déjà ouverte (il faudra relancer), réessayer un échec, installer la nouvelle version du jeu.
- **Une seule place pour tout voir, dès l'écran titre.** Le panneau de la bienvenue est ancré à droite de l'écran titre, avec le compte Pyramides ; après « Jouer », plus de fenêtre ni de deuxième carte (elle reste un bouton de l'écran titre et la touche M). Son bloc « MISES À JOUR » résume (jeu, villes à mettre à jour, téléchargements, villes prêtes au prochain lancement) avec « Tout mettre à jour » et « Relancer maintenant » ; « Villes et mises à jour → » ouvre la liste détaillée. `tools/capture_mises_a_jour.gd` en prend les captures, chaque état posé à la main.
- **Un pack remplacé à la main pendant la partie** (une nouvelle version déposée dans `communes/` sans quitter le jeu) : s'il n'a pas encore été ouvert, on relit son manifeste et on ouvre la nouvelle version ; s'il l'a été, on refuse d'y entrer jusqu'au prochain lancement, plutôt que de lire le nouveau fichier aux places de l'ancien.

**La vue à pied est fournie par le jeu** (`scripts/socle/vue.gd`, autoload `Vue`) : dans toute commune dont la scène expose `player` (un `fp_player.gd`) et `camera` (un `orbit_camera.gd`), Tab et le bouton « Vue » de l'interface tactile alternent la vue de dessus, où la caméra à crans suit l'habitant, et la vue à la première personne, exactement comme à Smarves ; `Vue.basculee(topdown)` prévient la scène, qui peut adapter sa ligne d'aide. Une scène qui a sa propre méthode `set_fps()` (Smarves) garde la main. Le paquet n'a rien à coder (`tools/test_availles.gd` le vérifie). Au doigt, l'invite « E : … » devient un bouton ; une scène qui a une seconde action au clavier (la touche F) peut exposer `action_tactile()`, le texte du bouton quand rien n'est à portée de E (vide sinon) : le bouton joue alors F. Casino Minuit s'en sert pour frapper le PNJ qu'on vise.

**Rien à changer dans un paquet pour la carte** : elle lit le code INSEE, la scène, le nom, la version, l'auteur et la description, déjà au format. Une commune qui veut ouvrir la carte depuis sa propre caméra appelle `Carte.ouvrir()` (Ligugé le fait au-delà de son dernier cran, comme le village).

**Ligugé**, la commune d'essai (`tools/paquet_essai/liguge/`), est un paquet qui apporte son script : le prieuré Saint-Martin, le Clain et son pont, quelques maisons et le Café du Pont, fermé, construits en code, avec la caméra à crans de Smarves. Comme le kit de départ, elle expose `player` et `camera` : on y marche avec Tab, et `tools/test_commune.gd -- liguge --depuis=res://tools/paquet_essai/liguge/` le vérifie. `tools/test_carte.gd` l'emballe, la greffe, vérifie qu'elle s'allume, qu'on y va depuis la carte, qu'on rouvre la carte depuis Ligugé et qu'on rentre à Smarves :

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
| `auteur` | non | qui a fait la commune, tel qu'il s'affiche dans sa fiche (carte, carnet) ; « » par défaut |
| `version` | non (oui pour publier) | trois nombres (`0.1.0`), à monter à chaque dépôt |
| `description` | non | deux phrases, montrées dans le carnet du joueur ; « » par défaut |
| `socle_min` | non | la version du socle demandée (`1.0` par défaut ; le socle est aujourd'hui en `1.21`). Le kit de départ demande `1.12`, la version où `Cast.moi()` est arrivé : un jeu plus ancien refuse la commune proprement au lieu de planter |
| `ailleurs` | non | socle 1.5 : une destination hors de la Vienne, rejointe en avion (section « Les destinations lointaines ») ; `{ville, pays, aeroport, vol}`, la ville seule obligatoire. Avec lui, `insee` est absent ou vide |
| `insee` | oui (sauf `ailleurs`) | le code INSEE d'une commune actuelle de la Vienne (`86263` pour Smarves) ou, depuis le socle 1.18 (`"socle_min": "1.18"`), d'un autre département de la Nouvelle-Aquitaine (`33063` pour Bordeaux ; référentiels dans `communes/departements/`) et, depuis le socle 1.19, de l'Auvergne-Rhône-Alpes (`69123` pour Lyon) : c'est lui qui place la commune sur la carte, à sa vraie place ; deux communes développées ne peuvent pas avoir le même |
| `carte` | non | plus tard, la scène du petit socle posé sur la carte |
| `scene` | oui | la scène de la commune ; elle doit exister au chargement |
| `arrivee` | non | où l'on débarque : `lot` (la porte du village), `nom` (« La place de la Mairie », montré à l'arrivée et dans la fiche) et `par` (les communes d'où l'on vient, le car départemental) |
| `population` | non | le nombre d'habitants, s'il est connu ; à défaut (ou `0`), celui de `communes/vienne.json` (`Commune.population()`) |
| `licence` | non | la licence du plan et des photos de la commune (« ODbL et Licence Ouverte 2.0 », « CC BY 4.0 ») ; « » par défaut |
| `sources` | non | d'où viennent le plan et les photos : un texte ou une liste de textes (« © les contributeurs d'OpenStreetMap ») ; vide par défaut |
| `interieurs` | non | les scènes des intérieurs, par id |
| `lots` | non | d'où viennent les portes de la commune ; pour Smarves, le dictionnaire `lots` du nœud `Village` |
| `lieux` | oui | les lieux de jeu, dans l'ordre où ils s'ouvrent : `id`, `nom`, `jeu`, `seuil` (total gagné au jeu), `hote` (qui fait signe à l'ouverture), `accord` (`e`, `s` ou rien : « ouverte », « ouverts »). On ne joue pas dehors : un lieu de jeu se joue dans l'intérieur de même id (`interieurs`), sinon il reste fermé |
| `salles` | non | les salles fermées d'un intérieur, par intérieur : `id`, `nom`, `seuil`, `sur` (`staked` pour un seuil sur le total misé), `hote` |
| `personnages` | non | où sont les fiches des personnages, et la liste des personnages nommés |
| `banque` | oui | la banque de la commune et son banquier ; `preteur` est la clé de la dette envers cette banque dans le socle |
| `biens` | non | les biens et leurs vendeurs |
| `jeux.regles_serveur` | non | les règles versées au serveur pour le multi (vide tant que le multi n'existe pas) |
| `structures` | non | les structures de la commune qui comptent pour les autres communes : gare, arrêt de car, terrain de football (section « Les structures ») ; vide par défaut |
| `notaire` | non | le notaire de la commune et son registre : toutes les adresses à vendre et le plan de l'étude (section « Le notaire ») |
| `carnet` | non | socle 1.3 : les compteurs que la commune tient au carnet du joueur, une liste de 24 au plus `{id, libelle, genre, rubrique}` (section « Le carnet du joueur ») ; vide par défaut |
| `page_carnet` | non | la page de la commune d'origine dans le carnet, un script du jeu (`res://scripts/carnet_smarves.gd`) ; lu pour la commune d'origine seulement, jamais dans un paquet |

Les champs facultatifs gardent le format 1 : un manifeste qui ne les a pas reste valide et prend leur valeur par défaut. Présents, ils doivent avoir le bon type (un texte, un objet, un nombre entier positif, une liste de textes), sinon la commune est refusée, par le jeu comme par le portail. `Commune.auteur()`, `arrivee_nom()`, `population()`, `licence()` et `sources()` les lisent.

Le socle traduit `lieux` et `salles` dans la forme que le code connaissait déjà : `main.gd` lit `PLACES` et le casino `LOCKS` depuis le manifeste de Smarves, aux mêmes valeurs qu'avant (`tools/test_communes.gd` le vérifie lieu par lieu).

## Les structures

Une **structure** est quelque chose qu'une commune possède et qui compte pour les autres communes : une gare, d'où le train va aux autres gares ; un arrêt de car, d'où le car départemental va aux autres arrêts ; un terrain de football, qui donne à la commune un club dans le championnat de la Vienne (le cadrage est dans [`SUITE.md`](SUITE.md), section 6). **Le socle définit les types et leur comportement ; la commune ne fait que déclarer les siennes et les poser dans sa scène.** Aucune commune ne lit une autre commune : tout passe par le registre du socle.

```json
"structures": [
	{"type": "arret_car", "id": "arret", "nom": "L'arrêt de la place", "noeud": "ArretDeCar", "lot": "place"},
	{"type": "terrain_foot", "id": "stade", "nom": "Le stade des Prés", "noeud": "Terrain",
	 "club": "L'Étoile de Smarves", "court": "ETS", "couleurs": ["#1b3c8c", "#f2c94c"], "stade": "Le stade des Prés"}
]
```

| Champ | Obligatoire | Ce que c'est |
|---|---|---|
| `type` | oui | un type connu du socle : `gare`, `arret_car`, `terrain_foot`, `salle_jeu` (socle 1.1, `guichet` : 1.2), `commerce` (socle 1.4), `gymnase` (socle 1.9) ; la liste est `Structures.TYPES`, `scripts/socle/structures.gd` |
| `id` | oui | minuscules, chiffres et `_`, unique dans la commune ; la clé au registre est `<commune>/<id>` |
| `nom` | oui | le nom affiché (« La gare de Ligugé ») |
| `noeud` | non | le nom du nœud de la scène de la commune qui place la structure (un `Node3D`, cherché par son nom) ; sans lui, la structure compte pour les autres communes mais ne se voit pas chez soi |
| `lot` | non | la porte du village qui y mène, quand la commune a des lots |

Et par type : `gare` prend `quai` ; `arret_car` prend `abri` ; `terrain_foot` demande `club` (le nom du club) et prend `court` (le sigle), `couleurs` (deux couleurs, `#rrggbb`), `stade`, `habillage` (socle 1.6), `scene` (socle 1.8) et `modele` (socle 1.13) ; `gymnase` demande `club` et prend `court`, `couleurs` (deux couleurs), `habillage` et `scene` (socle 1.12) et `modele` (socle 1.14 : une salle de la bibliothèque, `"salle-de-quartier@1"`, ou une scène de la commune, branchée par ses ancres comme le stade ; voir [`docs/BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md)) ; `salle_jeu` demande `jeux` et prend `tenancier`, `graine`, `decor`, `repliques`, `enseigne`, `guichet` (plus bas) et `modele` (socle 1.21 : une salle de jeu de la bibliothèque, `"bar-des-sports@1"`, ou une scène de la commune, branchée par ses ancres ; voir [`docs/BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md)) ; `commerce` demande `genre` et `articles` et prend `tenancier`, `graine`, `repliques` et `enseigne` (plus bas). Une seule structure de chaque type par commune, sauf les salles de jeu et les commerces : une commune peut en avoir plusieurs.

**Le stade est une scène du socle.** Une commune qui déclare un terrain n'a pas de stade à construire : `scenes/stade.tscn` (`scripts/village/stade.gd`) est le même pour toutes, habillé de la structure. Il y lit **le nom du club** (`club`, sur la tribune et dans la bouche du commentateur), **le sigle** (`court`, au tableau d'affichage), **les couleurs** (`couleurs` : la première teint la tribune, les bancs, les toits, les casquettes et les maillots des supporters, la seconde les bas des joueurs), **le nom du stade** (`nom` de la structure, sur l'arche et la tribune : « Le stade des Prés » s'écrit « STADE DES PRÉS »), et **la porte du retour** (`lot`, sinon l'`id` de la structure : `Game.return_point` à la sortie). **L'habillage** (socle 1.6, `"socle_min": "1.6"`) : le champ `habillage` du terrain nomme une scène de la commune (`res://communes/<id>/….tscn`), que le stade pose autour de la pelouse (nœud `Habillage`) ; la pelouse, la tribune du club, le tableau d'affichage, le président et le match restent ceux du socle. La scène lit le club par son parent si elle en a besoin. **La scène du stade** (socle 1.8, `"socle_min": "1.8"`) : le champ `scene` du terrain nomme une scène de la commune (`res://communes/<id>/….tscn`) dont le script hérite du stade du socle (`extends "res://scripts/village/stade.gd"`) ; `Football.ouvrir_stade` ouvre alors cette scène à la place de `scenes/stade.tscn`. La commune y bâtit son propre stade (elle remplace `_tribune()`, `_tableau_affichage()`, `_le_president()`…) ; le match sur la pelouse, le président, la causerie, le mercato, le bureau et les obligations restent ceux du socle. Une scène rangée dans le dossier de la commune (`res://communes/<id>/…`) compte comme la commune elle-même (`Communes.actuelle()`) : la carte ouverte depuis le stade part de la commune. Casino Minuit s'en est servi pour le stade de la Fortune jusqu'à sa version 0.10.4 ; il passe depuis la 0.10.5 par `modele` (plus bas). **Le décor du stade** (socle 1.13, `"socle_min": "1.13"`) : le champ `modele` du terrain nomme un décor sans héritage, soit une brique de la bibliothèque commune (`"modele": "stade-de-campagne@1"`), soit une scène de la commune (`res://communes/<id>/….tscn`). Le décor montre des ancres (`Pelouse`, `Arrivee`, `Sortie`, `Tableau`, `President`, `Bureau`, `Panneau`, et s'il veut `TribuneClub` et `Buvette`) et le socle y pose le terrain, le match, le président, la gestion, le panneau et la sortie : le club reste celui du championnat. Un décor de commune peut aussi vivre (socle 1.20, `"socle_min": "1.20"`) : `nuit(stade)` fait la nuit à la place du socle, `brancher(stade)` reçoit le stade une fois posé, `interagir(cle, cible)` prend les interactions avant lui. C'est ainsi que Casino Minuit bâtit le stade de la Fortune (`tools/paquet_essai/casino_minuit/stade/fortune.gd`) : un bol à l'américaine à deux étages de tribunes sous une roue de roulette géante, son parvis, son hall, sa piscine et son lounge, qu'on rejoint en taxi ; le taxi est sa sortie. Au stade d'une commune, `Communes.actuelle()` est cette commune, même sur la scène du socle. `scene` et `modele` ne vont pas ensemble. Le contrat et le catalogue sont dans [`docs/BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md). Une commune peut aussi **proposer** un de ses décors à la bibliothèque : un dossier `bibliotheque/<brique>/` et sa fiche `brique.json`, examinés à la main (même fiche, section « Proposer une brique »). **Le président** est l'hôte (`hote`) du lieu du manifeste qui porte le terrain, celui dont l'`id` est le même que celui de la structure ou que son `lot` ; sans lieu, c'est « Le président ». La commune ouvre son stade depuis sa scène par `Football.ouvrir_stade("<id de la commune>")` (la porte de son terrain, le nœud `noeud`) ; la sortie du stade ramène à sa scène. Tant que le club attend la saison prochaine, on y regarde le match de la division suivie et le président n'a rien à décider. Un champ inconnu, un type inconnu, un champ du mauvais type ou un terrain sans club rendent le manifeste invalide : la commune n'est pas inscrite, et le portail refuse le paquet pour la même raison. Un type ajouté plus tard fera monter la version du socle ; un paquet qui s'en sert le demande par `socle_min`. Le championnat ne compte que les clubs inscrits : avec un seul terrain au registre, il n'y a pas de match, le club s'entraîne et le tableau dit qu'on attend un deuxième club ; deux terrains suffisent.

**Le gymnase** (socle 1.9, `"socle_min": "1.9"`) : le basket de la Vienne sur les résultats réels (autoload `Basket`, `scripts/socle/basket.gd`). Une commune qui déclare un gymnase a un club de basket, dont les joueurs sont de vrais joueurs de l'Euroleague et de l'EuroCup, notés chaque vendredi soir par le serveur. Les champs : `club` (le nom du club, obligatoire), `court` (le sigle), `couleurs` (deux couleurs, `#rrggbb`) ; le `nom` de la structure est le nom de la salle. Les groupes ont toujours huit clubs : les places libres sont tenues par des clubs figurants (des villages de la Vienne), et un club nouveau prend la place d'un figurant dès la journée suivante, avec ses points et son calendrier ; quand le niveau du bas est plein, un niveau s'ouvre dessous. On joue le samedi à 20 h, quatorze journées par saison. La salle est une scène du socle, la même pour toutes les communes ; la commune l'ouvre par `Basket.ouvrir_salle("<id de la commune>")` (ou `SalleBasket.ouvrir`), et la carte la propose au passage du car. **L'habillage et la scène de la salle** (socle 1.12, `"socle_min": "1.12"`), comme pour le stade : le champ `habillage` du gymnase nomme une scène de la commune (`res://communes/<id>/….tscn`), posée dans la salle du socle (nœud `Habillage`) ; le champ `scene` nomme la salle de la commune tout entière, une scène dont le script hérite de la salle du socle (`extends "res://scripts/village/salle_basket.gd"`), que `SalleBasket.ouvrir` ouvre alors à la place de `scenes/salle_basket.tscn`, derrière l'écran de chargement. La salle dérivée remplace les pièces qu'elle veut refaire (`_heron_geant()`, `_parking()`, `_echoppe()`, `_vivants()`, `_arret_du_car()`…) ; le parquet, le match, le cube, le bureau du président et les parts restent ceux du socle. Casino Minuit s'en sert pour le Dôme de Minuit (`tools/paquet_essai/casino_minuit/basket/`).

**La salle de jeu est une scène du socle** (socle 1.1 : un paquet qui en déclare une met `"socle_min": "1.1"`). La commune ne construit ni la pièce ni les jeux : `scenes/salle_jeu.tscn` (`scripts/socle/salle_jeu.gd`) bâtit la salle, pose une table ou une machine par jeu en rangs de trois depuis le comptoir, et fait tourner les jeux de Smarves, avec la même bourse et le même total gagné. Les tables sont **celles du casino de Smarves**, dernière version (plus bas, « Les tables du casino ») : on s'y assoit, la caméra glisse jusqu'à la place et le panneau du jeu devient la barre basse, habillé comme au casino. Le loto et les courses, qui n'ont pas de table au casino, gardent une table de café et leur panneau au milieu de l'écran. Un paquet n'a rien à reconstruire pour en profiter : la salle est au socle, chez le joueur.

```json
{"type": "salle_jeu", "id": "tripot", "nom": "Le tripot de la gare", "noeud": "PorteTripot", "lot": "place",
 "jeux": ["machine", "blackjack", "roulette"], "tenancier": "Mme Rivière", "graine": 17, "decor": "cafe",
 "enseigne": "Au Tripot", "repliques": ["« Ici on mise petit, mais on mise souvent. »"]}
```

| Champ | Ce que c'est |
|---|---|
| `jeux` | les jeux de la salle, une table chacun, parmi `machine`, `loto`, `blackjack`, `roulette`, `craps`, `baccara`, `poker`, `des`, `roue`, `courses` (`Structures.JEUX`) |
| `tenancier` | qui tient le comptoir ; un habitant dessiné comme ceux de Smarves, tiré de `graine` (un nombre : le même tenancier d'une partie à l'autre) |
| `decor` | `cafe` (carrelage et papier peint, par défaut), `salle` (parquet, une salle des fêtes) ou `cave` (dalles et pierre, une arrière-salle) |
| `repliques` | ce que dit le tenancier quand on lui parle ; des phrases du socle à défaut |
| `enseigne` | le nom écrit au fond de la salle ; `nom` à défaut |
| `guichet` | `true` (socle 1.2, `"socle_min": "1.2"`) : le banquier de la commune tient un bureau près de la porte, et prête pour jouer au nom de la `banque` du manifeste |

**Le prêt est celui de la banque de la commune.** Le guichet du socle (`scripts/loan_panel.gd`, celui de M. Brunet) prend le nom de la banque, son banquier, et ses phrases s'il y en a (`banque.repliques`, une liste ; des phrases du socle à défaut). L'argent emprunté va au prêteur de la commune (`banque.preteur`) : la dette se compte à part de celle du Crédit Smarvois, avec les mêmes frais et les mêmes intérêts. Hors d'une salle de jeu, la scène d'une commune ouvre le même guichet par `preload("res://scripts/loan_panel.gd").de_commune("<id>")`, un panneau à ajouter à son interface ; son signal `closed` dit quand le refermer. L'écran Échap (les réglages, autoload `Settings`) et le carnet (C) sont au socle : ils marchent partout, sans rien à déclarer.

**Le seuil** vient des `lieux` du manifeste : la salle de même `id` qu'un lieu reste fermée tant que le joueur n'a pas gagné son `seuil`, et son `hote` fait signe quand elle ouvre. Une salle sans lieu du même id est ouverte d'emblée. La commune ouvre sa salle depuis sa scène, à la porte du nœud `noeud` : `SalleJeu.ouvrir("<id de la commune>", "<id de la salle>")` rend `false` si elle est encore fermée (`SalleJeu.ouverte()` et `SalleJeu.seuil()` permettent de l'écrire sur la porte). La sortie ramène dans la scène de la commune, devant la porte (`lot`, sinon l'`id` de la salle). `tools/test_salle_jeu.gd` vérifie tout le chemin avec la commune d'essai `tools/fixtures/salle_jeu/`.

```sh
godot --headless --path . -s tools/test_salle_jeu.gd
```

**Les tarifs du poker d'une commune** (socle 1.7, `"socle_min": "1.7"`). Le poker du socle est celui des Ambassadeurs : blindes 25/50, 2 000 au plus engagés par donne. Une commune peut donner d'autres tarifs à sa table, sans écrire son propre poker, en appelant sur le panneau, avant de l'ajouter à la scène :

- **au solo** (`scripts/poker_panel.gd`) : `configurer_blindes(petite, grosse, plafond)`. Il faut au moins la grosse blinde en crédits pour s'asseoir ;
- **à plusieurs** (`scripts/jeux/poker_multi.gd`) : `configurer_table("<id>", petite, grosse, plafond)`. La table doit exister au serveur (la fonction casino du dépôt chtabay/addict, `SMARVES.tables` dans `supabase/functions/casino/smarves-poker.js`), qui seul fixe ses tarifs : un paquet ne peut pas les installer. Le serveur les renvoie dans chaque vue (`table` : `id`, `nom`, `blindes`, `plafond`) ; si ce ne sont pas exactement ceux annoncés, le panneau refuse de jouer, le dit, et se lève s'il était assis. Le tapis posé en s'asseyant ou en recavant va du plafond à 10 000 (au plafond même, s'il est plus haut). Rien n'est pris à l'entrée.

Les deux rendent `false`, sans rien changer, pour des tarifs incohérents. La table du serveur aujourd'hui ouverte aux communes :

| Table | Commune | Blindes | Plafond par donne | Tapis |
|---|---|---|---|---|
| `cloue:poker-cave` | Cloué, La Contrebande | 125/250 | 10 000 | 10 000 |

Une autre table se demande dans le dépôt chtabay/addict. Le test est `tools/test_poker_multi.gd`.

**Les tables du casino** (socle 1.10, `"socle_min": "1.10"`). Une commune qui bâtit sa propre salle de jeu, au lieu de la salle du socle, prend les tables du casino de Smarves par la classe **`Tables`** ([`scripts/socle/tables.gd`](../scripts/socle/tables.gd)) : ce sont les fichiers du casino lui-même, pas une copie, et quand le casino change ses tables, toutes les communes les ont au jeu suivant. **Ne fabriquez pas de table de jeu** avec les modèles de l'atelier (la machine Kenney de la famille `arcade` et la `table_jeu` de la brocante sont du décor), **et ne recopiez ni les panneaux ni leur thème** dans votre paquet : ils vieilliraient avec lui.

| L'appel | Ce qu'il fait |
|---|---|
| `Tables.table(jeu, titre = "")` | la table 3D du casino pour ce jeu : `machine` (la machine à vrais tambours), `blackjack` (le sabot), `roulette` (le cylindre), `craps`, `baccara`, `poker`, `des` (le Grand Hasard), `roue` ; `null` pour `loto` et `courses`, qui n'ont pas de table. La place du joueur est du côté +z ; `titre` s'écrit au fronton de la machine ou du baccara. Elle pose sa lampe, un projecteur ; le rendu web et mobile compte peu de lumières par objet : mieux vaut `with_lamp = false` avant de l'ajouter à la scène et une lampe ponctuelle de la salle au-dessus du tapis, comme dans la salle du socle |
| `Tables.EMPRISE[jeu]` | son emprise au sol (largeur en x, profondeur en z), pour la collision et la mise en place |
| `Tables.panneau(jeu, titre = "")` | le panneau du jeu, celui du casino ; il émet `played(mise, gain)` à chaque coup (à la commune d'encaisser : `Game.cash_in(gain)`) et `closed` quand on se lève. Il porte son bouton Règles, à côté de Quitter : les règles du jeu s'ouvrent par-dessus la table (`scripts/jeux/regles.gd`), sans rien à faire de la commune. Pour un poker à d'autres tarifs, `configurer_blindes` s'appelle sur ce panneau (plus haut) |
| `Tables.asseoir(table, panneau, camera, calque)` | le geste du casino : le panneau se lie à la table (cartes, bille, dés et jetons partent sur le tapis), la caméra glisse du regard du joueur (`player.camera`) jusqu'à sa place, le panneau devient la barre basse du `calque` (un `Control` plein écran) et la souris est libérée |
| `Tables.lever(table)` | se lever : la caméra revient au regard du joueur ; le panneau est à libérer par la commune |
| `Tables.theme()` | l'habillage des fenêtres du casino (laque sombre, filet d'or, boutons en pastille) : à poser sur le `calque`, et sur tout panneau ouvert hors d'une table |

**Les échecs du Cercle** (la brique `echecs@1`, classe **`Plateaux`**, [`scripts/plateaux/plateaux.gd`](../scripts/plateaux/plateaux.gd)). Les échecs du casino de Smarves, pour une commune qui en veut : le panneau de la partie (l'échiquier à la manière de chess.com, les pendules, les réglages de cadence, de couleurs et de mise, la feuille de partie et le bouton « Règles »), la table 3D qui montre la position, et la salle toute faite, le Cercle Philidor. Tout se joue sur le serveur (fonction casino du dépôt chtabay/addict, `smarves-plateaux.js`) : il vérifie les coups, fait jouer les robots, tient la pendule et dit ce que chaque mise retire ou rend ; le panneau l'applique aux crédits du joueur une seule fois par partie. Une table du serveur a un robot installé (on joue seul contre lui, de Novice à Expert, son niveau mesuré contre Stockfish), ou elle est vide et attend deux joueurs réels, qui fixent ensemble la cadence (5 minutes proposées), les couleurs et la mise. Une commune qui veut ses propres tables les fait ajouter au serveur, comme pour le poker, puis les nomme par leur identifiant.

| L'appel | Ce qu'il fait |
|---|---|
| `Plateaux.panneau(table, titre = "")` | le panneau d'une table du serveur (`cercle:echecs-1`, `cercle:echecs-lacroix`…) ; il s'assied en entrant dans la scène, se lève et émet `closed` quand on le quitte (se lever en partie, c'est abandonner) |
| `Plateaux.table()` | la table 3D (guéridon, échiquier, pièces tournées) ; `montrer(plateau)` y pose une position du serveur |
| `Plateaux.cercle(casino, scène, point)` | ouvre le Cercle de ce casino ; sa porte ramène à `scène`, au point `point` (`Game.return_point`) |

```gdscript
var t := Tables.table("roulette")
t.position = $PosteRoulette.position
add_child(t)
calque.theme = Tables.theme()
# … quand le joueur demande à jouer :
var p := Tables.panneau("roulette", "La roulette de la cave")
p.played.connect(func(_mise, gain): Game.cash_in(gain))
p.closed.connect(func():
	Tables.lever(t)
	p.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
Tables.asseoir(t, p, player.camera, calque)
```

La salle de jeu du socle s'en sert pour toutes ses tables, et le casino de Smarves pour l'habillage de ses fenêtres. `tools/test_salle_jeu.gd` vérifie que chaque jeu de la salle d'essai pose la table du casino, qu'on s'y assoit et qu'on s'en relève.

**Les jeux d'une commune** (socle 1.12, `"socle_min": "1.12"`). Une commune peut ajouter ses propres jeux à ceux du casino, sans rien changer à ceux de Smarves : `Tables.inscrire("<id de la commune>:<nom>", fiche)` les inscrit pour la partie, depuis sa scène, avant d'ouvrir une salle. La fiche donne `panneau` (obligatoire : le script d'un `PanelContainer` qui émet `played(mise, gain)` et `closed`, comme ceux du casino), `modele` (le script de sa table 3D, qui hérite de `scripts/jeux/table_3d.gd` ; sans lui, la salle pose une table de café), `emprise` (`Vector2`, sa place au sol en mètres), `invite` et `titre`. Le jeu se pose et se joue ensuite comme un jeu du casino (`Tables.table`, `Tables.panneau`, `Tables.asseoir`), et une `salle_jeu` du manifeste peut le nommer dans ses `jeux` par ce même nom (`"jeux": ["poker", "cloue:bonneteau"]`). Un nom sans commune (`"bonneteau"`) reste refusé : les noms courts sont ceux du socle, et un jeu du socle ne se remplace pas. `Tables.jeux()` les liste tous, `Tables.fiche(jeu)` rend la fiche d'un jeu. Les règles du jeu sont dans son panneau : un jeu à plusieurs, dont le serveur tient l'argent, demande encore ses règles au serveur (« Le multijoueur »). `tools/test_tables.gd` le vérifie.

**Le commerce est une scène du socle** (socle 1.4 : `"socle_min": "1.4"`). Les trois commerces de Smarves ont leur pareil pour toute commune, selon le `genre` : `tenue` (on n'en porte qu'une, comme chez Raymonde), `vehicule` (on n'en conduit qu'un, comme au garage Fradin) ou `meuble` (il se pose chez soi, comme chez Ginette Boutin). La commune nomme son commerçant et ses articles ; `scenes/commerce.tscn` (`scripts/socle/commerce.gd`) bâtit la boutique, pose le commerçant derrière son comptoir, met six articles au plus en vitrine (une silhouette à la couleur de la tenue, le véhicule, le meuble) et ouvre le bon de commande du village (`scripts/shop_panel.gd`).

```json
{"type": "commerce", "id": "mercerie", "nom": "La mercerie de la gare", "lot": "place", "genre": "tenue",
 "tenancier": "Mme Aubin", "graine": 23, "enseigne": "Mercerie Aubin",
 "articles": [{"id": "veste_chef", "nom": "La veste de chef de gare", "prix": 400, "couleur": "#1d3b6e",
               "phrase": "« Les boutons sont en vrai cuivre. »"}]}
```

| Champ d'un article | Ce que c'est |
|---|---|
| `id`, `nom`, `prix` | obligatoires ; l'`id` (minuscules, chiffres, `_`) est unique parmi tous les commerces de la commune |
| `standing`, `seuil`, `max` | facultatifs, des entiers : le standing qu'il donne (tiré du prix à défaut), le total gagné au jeu qui le met en vente (0), combien on peut en avoir (1) |
| `phrase` | ce que dit le commerçant sur la fiche |
| `couleur` | une tenue : sa couleur, `#rrggbb` |
| `modele` | un véhicule ou un meuble : un chemin `res://` (un modèle de l'atelier, ou de la commune) ; obligatoire pour un meuble, la Mobylette du socle pour un véhicule qui n'en donne pas |
| `emplacement` | un meuble : où il se pose chez soi, `lit`, `sol` (par défaut), `grand`, `mur`, `petit` ou `jardin` |

Vingt-quatre articles au plus par commerce. Au catalogue de `Biens`, un article est rangé sous `<commune>/<id>` comme les adresses du notaire ; une tenue ou un véhicule coûte des charges (un peu moins d'un centième du prix par recette), un meuble rien. On paie comptant ou à crédit auprès de la banque de la commune, et l'achat suit le joueur partout : la tenue se porte, le véhicule se conduit, le meuble se pose dans le logement qu'on habite. La commune ouvre son commerce depuis sa scène par `Commerce.ouvrir("<id de la commune>", "<id du commerce>")` ; la sortie ramène devant la porte (`lot`, sinon l'`id`). La commune d'essai `tools/fixtures/salle_jeu/` a une mercerie, un garage et une brocante, que `tools/test_salle_jeu.gd` vérifie.

**Le registre** (autoload `Registre`, `scripts/socle/registre.gd`) est reconstruit à chaque inscription de commune et à chaque lecture du catalogue : il tient les structures des communes **installées** chez le joueur et celles des communes **publiées** sur le portail, installées ou non (le catalogue porte les structures de chaque paquet publié). Chaque entrée dit sa commune, son code INSEE, son centre sur la carte et si l'on peut y aller (`installee`). Ce qu'il expose :

| | |
|---|---|
| `entrees` | toutes les structures : `cle`, `commune`, `insee`, `commune_nom`, `centre`, `installee`, `type`, `id`, `nom`, `noeud`, `lot`, `champs` (les champs propres au type) |
| `de_type(type, installees)`, `de_commune(id)`, `structure(cle)` | les filtres |
| `relies(cle, installees)` | ce qu'une structure relie d'après son type (les autres gares, les autres arrêts), les plus proches d'abord ; un terrain ne relie rien, c'est le championnat qui lit les terrains |
| `noeud(scene, entree)` | le nœud qui place la structure dans la scène de sa commune |
| `change` | signal : le registre vient d'être reconstruit |

La commune d'essai (`tools/commune_essai/`) déclare une halte et un stade ; `tools/test_structures.gd` vérifie le vocabulaire, le registre et la lecture du catalogue :

```sh
godot --headless --path . -s tools/test_structures.gd
```

## Le notaire

L'étude du notaire est une structure du socle : **la commune déclare son notaire et son registre, le socle en fait l'étude, les fiches et le plan.** Rien de l'étude n'est propre à Smarves (`scripts/socle/notaire.gd`, plan dessiné par `scripts/carte_biens.gd`).

```json
"notaire": {
	"nom": "Maître Garnier", "etude": "L'étude de Maître Garnier",
	"titre": "Étude de Maître Garnier, notaire à Smarves",
	"registre": {"source": "res://scripts/adresses.gd"}
}
```

`registre` est soit `{"source": "<script>"}`, un script dont `static func registre()` rend le registre (Smarves le calcule depuis les rangées de façades de son village, pour que le plan suive les maisons), soit le registre écrit dans le manifeste : `{"quartiers": [...], "adresses": [...]}`.

Le plan se dessine sur un papier de 1000 × 620 ; les rectangles s'écrivent `[x, y, largeur, hauteur]`.

| Un quartier (un onglet du plan) | |
|---|---|
| `id`, `nom` | la clé et le nom de l'onglet (« La rue du Clain ») |
| `style` | `plan` : chaque case porte son nom et son prix ; `rue` : des façades numérotées, l'enseigne couchée le long de la case quand elle est étroite |
| `decor` | des formes sous les cases : `{"forme": "rect", "rect", "teinte"}` ou `{"forme": "rond", "centre": [x, y], "rayon", "teinte"}` ; teintes : `place`, `route`, `chemin`, `jardin`, `cour`, `fond` |
| `textes` | `{"texte", "rect", "taille", "centre"}` : les noms de rues et de places |
| `liens` | `{"rect", "vers", "texte"}` : un bout de rue qui ouvre un autre quartier |

| Une adresse | |
|---|---|
| `id`, `quartier`, `rect` | la clé du bien, son onglet, sa case |
| `etiquette`, `numero`, `ligne` | ce qui s'écrit dans la case, le numéro de la façade (0 : pas de numéro), l'adresse sur la fiche (« 13, rue du Clain ») |
| `genre` | `maison` (un logement qu'on habite ou qu'on loue), `murs` (une boutique : on achète les murs, le commerçant paie), `public` (la commune reste et paie), `part` (l'`id` est un bien déjà au catalogue de `biens`) |
| `nom`, `prix`, `de`, `phrase` | la fiche : le nom de l'acte, le prix, qui cède, sa phrase |
| `interieur` | pour une maison : le gabarit de l'intérieur (`maisonnette_v1`, `maison_v1`, `maison_haute_v1`, `pavillon_v1`, ou un de ceux des logements de `Biens`) |
| `standing`, `seuil` | facultatifs ; un lieu à seuil se vend tout de suite mais n'ouvre qu'au seuil |

Le socle tire la fiche du prix : rente annoncée 10 % du prix par recette (8 % pour un bâtiment public), charges un cent-vingtième, standing selon le genre et le prix. Un manifeste sans `notaire` reste valide : l'étude prend « Le notaire » et un registre vide. `Commune` vérifie le champ (`notaire.verifier`), un quartier inconnu, un genre inconnu ou une adresse sans prix rendent le manifeste invalide.

**L'étude est une scène du socle.** Une autre commune que Smarves n'a pas d'étude à construire : `scenes/etude.tscn` (`scripts/socle/etude.gd`) bâtit la pièce, met le notaire derrière son bureau et ouvre le registre de la commune (le même plan et les mêmes fiches qu'à Smarves). La commune l'ouvre depuis sa scène par `Etude.ouvrir("<id de la commune>")`, et la porte ramène devant l'étude (`notaire.lot`, sinon `notaire`). Quatre champs facultatifs habillent l'étude : `graine` (un nombre : le visage du notaire, le même d'une partie à l'autre), `repliques` (ce qu'il dit quand on s'approche ; des phrases du socle à défaut), `lot`, et `modele` (socle 1.21 : une étude de la bibliothèque, `"etude-de-notaire@1"`, ou une scène de la commune, branchée par ses ancres à la place de la pièce du socle ; voir [`docs/BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md)).

**Les adresses d'une autre commune sont rangées sous son id.** Au catalogue de `Biens`, l'adresse `buffet` d'Availles est le bien `availles_limouzine/buffet` (`notaire.cle`), pour que deux communes puissent avoir chacune leur `maison_place` ; une adresse `part` garde l'id du bien qu'elle désigne. On l'achète comptant, ou à crédit auprès de la **banque de la commune** (`banque.preteur`), pas du Crédit Smarvois. Un bien d'une commune qui n'est plus inscrite reste dans la partie, mais il ne vaut ni ne rapporte rien tant qu'elle n'est pas revenue. La commune d'essai `tools/fixtures/salle_jeu/` a un notaire, et `tools/test_salle_jeu.gd` vérifie l'achat et l'étude.

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

**L'écran de chargement** (socle 1.11, autoload `Chargement`, [`scripts/socle/chargement.gd`](../scripts/socle/chargement.gd)). On entre dans une commune en pack derrière un écran animé (une roue de roulette, des ampoules qui défilent autour du nom de la commune) qui montre la progression. Pour un vol, le socle lit les ressources du pack (modèles, textures, scripts, shaders) dans des fils à part dès le décollage, pendant que l'avion vole ; à l'atterrissage la scène s'ouvre sans attendre la fin de cette lecture ; puis l'écran laisse quelques images au moteur (shaders, textures) avant de s'effacer. Une commune n'a rien à faire pour en profiter. Si sa scène est longue à bâtir, elle peut dire où elle en est et se bâtir sur plusieurs images (`"socle_min": "1.11"`) :

```gdscript
var chargement := 0.0        # de 0 à 1 : l'écran reste là tant qu'il n'est pas à 1
var chargement_etape := ""   # la phrase sous la barre (« On dresse les tables… »)

func _ready() -> void:
	var par_etapes := Chargement.actif()   # faux dans un test ou une capture : tout d'un bloc
	set_process(false)
	_batir_la_rue()
	chargement = 0.5
	if par_etapes:
		await get_tree().process_frame     # l'écran s'anime pendant une image
	_batir_le_casino()
	chargement = 1.0
	set_process(true)
```

Une porte qui ramène dans une scène de commune passe par `Chargement.changer(chemin)` plutôt que `change_scene_to_file` : derrière l'écran pour une commune en pack, d'un coup sinon. Le journal du jeu note les durées de chaque temps (`[chargement] …`).

**La scène gardée** (socle 1.12, 22 octobre 2026). Une porte qui mène de la scène de la commune à un de ses lieux passe par `Chargement.lieu(chemin)` (les lieux du socle le font déjà : `SalleJeu.ouvrir`, `Commerce.ouvrir`, `Etude.ouvrir`, `Prestation.ouvrir`, le Cercle) : la scène de la commune reste alors cachée et à l'arrêt pendant la visite, et `Chargement.changer` la rend au retour sans la rebâtir, l'habitant devant la porte. Elle se rebâtit quand même si un seuil de gagné au jeu de la commune est passé ou si les biens du joueur ont changé pendant la visite. Une scène qui montre autre chose de la partie peut donner sa signature (`func signature_garde() -> Variant`, en partant de `Chargement.signature_commune(self)`) et se remettre à jour au retour (`func revenir() -> void`). Détails dans [LENTEUR.md](LENTEUR.md).

Le mécanisme est éprouvé par `tools/test_communes.gd`, qui emballe la commune d'essai de [`tools/commune_essai/`](../tools/commune_essai/) en pack avec `PCKPacker`, l'inscrit sans la monter, l'ouvre, charge sa scène depuis le pack, puis vérifie qu'un pack qui voudrait remplacer `scripts/game_state.gd`, un pack avec du code natif, un pack abîmé et un dossier dont le manifeste ment sur son id sont refusés :

```sh
godot --headless --path . -s tools/test_communes.gd
```

## Publier sa commune

Une commune se publie sur **le portail des développeurs**, la page `/developpeur` de Pyramides (https://pyramides2.vercel.app/developpeur), réservée au rôle développeur de Pyramides (et à l'organisateur). Le jeu, lui, ne fait que lire un catalogue public et installer des paquets ; il n'a besoin d'aucun compte.

### Le geste

1. Sur la page, choisir sa commune parmi les 265 de la Vienne (Smarves et Poitiers exceptées) et **télécharger le kit de départ** : une commune minimale que le jeu accepte telle quelle, où l'on marche déjà (section « Le kit de départ »), et son mode d'emploi `LISEZMOI.md`.
2. Poser le dossier du kit dans `communes/` du SDK des communes (section « Le SDK des communes »), construire la commune, puis l'emballer :
   ```sh
   godot --headless --path . -s tools/emballer_commune.gd -- <id>
   ```
   L'outil écrit `build/<id>.pck` et le fait passer par les refus du jeu (`Communes.charger_pack`, montage, chargement de la scène). `--depuis=…/` emballe un autre dossier, dans le projet (`res://…/`, c'est ainsi qu'est fait le paquet d'essai, `tools/paquet_essai/`) ou hors de lui (le dépôt d'une commune, `--depuis=/chemin/vers/vegas`) : il est d'abord recopié sous `communes/<id>/`, sans `.git`, `tests/` ni `.md`, importé là par le moteur, emballé, puis retiré. Un modèle importé nomme ses textures par leur chemin : importé ailleurs, il chercherait dans le jeu des fichiers qui n'y sont pas. L'outil refuse un paquet dont une ressource importée nomme un chemin hors de `res://communes/<id>/`.
3. **Déposer** le `.pck` sur la page : il part directement du navigateur vers le stockage, puis le serveur le relit et affiche **le rapport de validation**, une ligne par règle. Un paquet valide est « prêt » ; **publier** le met au catalogue (une seule version publiée par commune, la nouvelle remplace l'ancienne), **dépublier** l'en retire. Chaque dépôt garde sa ligne : c'est l'historique des versions.

**Une version par dépôt.** Chaque dépôt doit porter une version plus grande que la dernière déposée pour cette commune (`0.1.0`, puis `0.1.1` ou `0.2.0`) : avant d'envoyer le fichier, la page lit dans le pack sa taille, son nombre de fichiers et sa version, les affiche, et refuse tout de suite un pack dont la version est inférieure ou égale à la dernière déposée (un vieux `.pck` oublié dans `build/` ne passe pas). Un dépôt refusé ne consomme pas sa version. Chez le joueur, **une mise à jour s'ouvre au lancement suivant** : la nouvelle version s'installe à côté et prend la place de l'ancienne au prochain démarrage du jeu.

Une commune est **tenue** par l'auteur de son premier paquet valide : lui seul y dépose et publie ensuite, avec l'organisateur.

### Le kit de départ

Le kit est un `.zip` à poser à la racine du SDK des communes. Il contient :

- `communes/<id>/commune.json` : le manifeste prérempli (`id`, `nom`, `insee`, `auteur`, `population`, `socle_min` à `1.12`, `arrivee` avec son nom, `licence` et `sources` vides, un lieu et une banque « à écrire ») ;
- `communes/<id>/commune.tscn` et `commune.gd` : **la scène de départ**, qui marche telle quelle. Une lumière réglable (`SOLEIL` : hauteur, direction, couleur) et un ciel, un sol avec sa collision, un repère `Arrivee` et trois repères de vue `Vue1_…`, `Vue2_…`, `Vue3_…`, un par scène forte de la note d'intentions, que suit `tools/parcours_commune.gd`. **Elle ne pose aucun décor** : un lieu se compose d'après sa note ([`CONCEPTION.md`](CONCEPTION.md)), pas en partant d'une placette type ; le script rappelle les appels de l'atelier et de la bibliothèque. Il crée l'habitant de Smarves (`fp_player.gd`) et la caméra à crans du village (`orbit_camera.gd`) et les expose sous les noms que le jeu attend, **`player` et `camera`** : c'est ce qui donne sans une ligne de code la bascule de vue (Tab, autoload `Vue`), les commandes tactiles (`Tactile`) et la carte de la Vienne en dézoomant ;
- `communes/<id>/INTENTIONS.md` : **la note d'intentions à remplir** avant le premier modèle ([`CONCEPTION.md`](CONCEPTION.md), « Avant de construire »), que l'emballeur laisse hors du paquet ;
- `LISEZMOI.md` : le mode d'emploi, de l'installation de Godot au dépôt.

Le modèle du kit vit dans Smarves, [`tools/kit/`](../tools/kit/) (les mêmes fichiers, avec `__ID__`, `__NOM__` et `__INSEE__` à la place des valeurs) ; le portail le recopie (`src/lib/communes/kit.ts` dans Pyramides2). Quatre outils du dépôt accompagnent le kit :

- **`tools/test_commune.gd`**, le test minimal : le pack s'ouvre comme chez un joueur, la scène expose `player` et `camera`, l'habitant se pose au sol et marche. Sans argument, il éprouve le kit lui-même ; avec `--pck=`, un paquet déjà emballé.
  ```sh
  godot --headless --path . -s tools/test_commune.gd -- <id>
  godot --headless --path . -s tools/test_commune.gd -- <id> --pck=build/<id>.pck
  ```
- **`tools/parcours_commune.gd`**, pour juger à hauteur de joueur : l'habitant posé sur chaque repère `Vue…` de la scène, trois captures par repère (de dessus, à pied, en se retournant), une marche d'un repère au suivant et un rapport, dans `user://parcours/<id>/` ; sans rendu (`--headless`), les marches seulement. Il prend aussi un paquet (`--pck=`) et des points donnés (`--point=x,y,z,lacet`). Voir [`CONCEPTION.md`](CONCEPTION.md), « Juger à hauteur de joueur ».
  ```sh
  godot --path . -s tools/parcours_commune.gd -- <id>
  ```
- **`tools/bourg_reel.py`**, pour partir de la vraie disposition du bourg, comme Availles-Limouzine : rues, places, bâtiments à leur place et à leur hauteur, eau, bois et relief, tirés d'OpenStreetMap, de la BD TOPO et du RGE ALTI de l'IGN. Le code INSEE du manifeste suffit : l'outil en tire le centre du bourg et un cadre de 1 km de côté, et écrit `bourg.json` et `sol.png` dans `communes/<id>/`. Les réglages (centre, cadre, lieux remarquables, nom de la rivière) se gardent dans `communes/<id>/bourg_reel.json` ; celui d'Availles-Limouzine sert d'exemple ([`tools/paquet_essai/availles_limouzine/bourg_reel.json`](../tools/paquet_essai/availles_limouzine/bourg_reel.json)), et sa scène ([`availles.gd`](../tools/paquet_essai/availles_limouzine/availles.gd)) montre comment construire le bourg depuis `bourg.json`. Les sources et leurs licences sont écrites dans `bourg.json` : recopiez-les dans `licence` et `sources` du manifeste.
  ```sh
  python3 -m pip install pillow
  python3 -I tools/bourg_reel.py <id>
  python3 -I tools/bourg_reel.py <id> --centre=0.656,46.1215 --cadre=-600,-330,460,420 --remarquables=lieux.json
  ```
- **`tools/emballer_commune.gd`**, qui écrit `build/<id>.pck` (section « Le geste »).

### Le SDK des communes

Un développeur n'a pas besoin du dépôt de Smarves, qui peut redevenir privé : **le SDK** est un projet Godot autonome, publié avec chaque version du jeu (`smarves-sdk.zip`, à côté de l'installateur dans la Release). Décision de Guillaume du 18 octobre 2026 : le socle y est **lisible**, mais le village de Smarves n'y est pas.

- **Ce qu'il contient** : le socle en clair (`scripts/socle/`, les dix jeux et leurs panneaux, les tables 3D du casino (`scripts/jeux/`), le stade, la salle de jeu, les façades, les figurants, l'habitant et sa caméra, la carte de la Vienne), les modèles, sons, matières et polices qu'ils utilisent, le kit de départ (`tools/kit/`), les outils (`test_commune`, `parcours_commune`, `emballer_commune`, `bourg_reel.py`, le serveur MCP et son `.mcp.json`), l'exemple technique d'Availles-Limouzine, ce document, la méthode de conception (`CONCEPTION.md`, avec sa note d'exemple et ses planches de référence) et les extraits communs de la bible et du cadrage (`BIBLE.md`, `SUITE.md` : le ton, l'époque, le vocabulaire, l'économie, la carte et les structures ; ce qui est propre à Smarves n'y est pas).
- **Ce qu'il ne contient pas** : la place, le casino, les intérieurs, les quartiers et les lieux cachés de Smarves. Le manifeste de Smarves y est réduit à ce que le socle lit d'une commune d'origine ; un **lanceur** (`scenes/main.tscn` du SDK) tient la place du village : il inscrit les communes posées dans `res://communes/<id>/` et ouvre celle qu'on choisit, comme chez un joueur.
- **Comment il est fait** : [`tools/sdk/construire_sdk.py`](../tools/sdk/construire_sdk.py) part des autoloads et des points d'entrée d'une commune, suit les liens (`res://…`, `preload`, classes nommées, dossiers de modèles) et s'arrête aux fichiers du village (`COUPE`) ; ceux que le socle nomme quand même sont remplacés par un bouchon (`tools/sdk/bouchons/`). Un lien dur vers le village sans bouchon arrête la construction. [`tools/sdk/test_sdk.sh`](../tools/sdk/test_sdk.sh) déballe le zip hors du dépôt et y passe le kit, l'atelier, la salle de jeu, Availles-Limouzine, le lanceur et le serveur MCP ; la construction de main le fait avant de publier.

```sh
python3 tools/sdk/construire_sdk.py            # écrit build/smarves-sdk-<date>-<commit>.zip
sh tools/sdk/test_sdk.sh                       # le déballe ailleurs et l'éprouve
```

Le mode d'emploi du développeur est le `LISEZMOI.md` du SDK ([`tools/sdk/LISEZMOI.md`](../tools/sdk/LISEZMOI.md)).

### L'atelier du socle

Ce que Smarves a construit, le jeu le prête aux communes : une commune s'en sert sans rien mettre dans son paquet, parce que ces ressources sont déjà chez le joueur (le pack d'une commune se monte par-dessus le jeu, `res://scripts/…` et `res://assets/…` y sont visibles). Elle ne pèse que son propre code, et ses maisons ressemblent à celles du reste de la Vienne.

Le catalogue est [`scripts/socle/atelier.json`](../scripts/socle/atelier.json), l'API la classe **`Atelier`** ([`scripts/socle/atelier.gd`](../scripts/socle/atelier.gd)). Les noms du catalogue sont un engagement : ils ne bougent pas quand le code de Smarves change, et `tools/test_atelier.gd` vérifie que chacun mène à quelque chose.

| Rubrique | Ce qu'il y a | L'appel |
|---|---|---|
| Modèles | huit familles de modèles 3D sous licence CC0 (Kenney, KayKit) : `nature` (arbres, rochers, fleurs, cultures), `ville` (bancs, lampadaires, panneaux), `voitures`, `mobilier`, `restaurant`, `arcade`, `marche`, `salon` | `Atelier.modele("nature/tree_oak")`, `Atelier.modele("ville/bench", 0.35)` : pied au sol, à la hauteur conseillée de la famille ou à celle donnée (l'habitant mesure 0,7). `Atelier.modeles("nature")` les liste |
| Maisons | les façades du Poitou de Smarves : calcaire, volets, tuiles canal, lucarnes, cheminées, vitrine avec enseigne | `Atelier.rue($Maisons, [[Transform3D, spec], …], graine)` ; les champs de `spec` sont dans le catalogue |
| Figurants | des habitants anonymes, dessinés comme ceux de Smarves, debout, assis ou qui marchent sur une route, en tenue de village ou de soirée | `Atelier.figurant(graine, "sit")` ; la graine fixe son allure d'une partie à l'autre |
| Personnages | (socle 1.12) des personnages 3D animés, plus réalistes que les figurants : dix-sept modèles Quaternius (CC0) et dix-neuf rôles habillés (client, croupier, barman, vigile, serveur, hôtesse, portier, voiturier, cuisinier, livreur, musicien…), avec leurs gestes (marcher, s'asseoir, parler, boire, téléphoner, applaudir…). Venus de Casino Minuit, ils sont dans le jeu : ils ne pèsent rien dans le paquet | `Atelier.personnage("croupier", 3)` habille un rôle (la graine fixe la tenue) ; `Atelier.personnage_modele("man-suit", {"Suit": "#1c2740"})` pose un modèle aux teintes données ; le nœud joue `jouer("talk")`, `regarder(point)`, `suivre(route)`. `Atelier.personnages()` donne le module entier (ses tables `TENUES`, `MODELES`, `GESTES`) |
| L'allure du joueur | les boutiques où l'on se fait retoucher, chaque retouche payée : couture (la tenue, un chapeau, des lunettes), coiffure, chirurgie (sexe, teint, nez, taille), salle de sport et restaurant (la corpulence). Fiche : [`docs/AVATAR.md`](AVATAR.md). Tout commerce de tenues a déjà la cabine d'essayage dans sa vitrine | `Atelier.ouvrir_prestation("restaurant", {"commune": "<id>", "lot": "<porte>", "nom": …, "tenancier": …, "tarif": 1.5, "formules": […]})` ouvre la boutique du socle ; `Atelier.prestation(métier, options)` donne le panneau seul ; `Atelier.allure_du_joueur()` habille l'habitant que dirige le joueur |
| Meubles | la brocante : fauteuil club, buffet Henri II, juke-box, billard, table de jeu… | `Atelier.meuble("juke_box")`, à l'échelle d'un intérieur |
| Sons | les bruitages (jetons, cartes, dés, gain…) et deux ambiances | `Atelier.son("dice")`, `Atelier.ambiance("village")` |
| Matières | les shaders : calcaire, tuiles, vitre éclairée, pavés, eau, tapis, damas, marbre, feutre, ciel de nuit ; et (socle 1.17) les matières en images de la bibliothèque commune, comme les dix-neuf de la DA de Casino Minuit ([`docs/BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md), « Les matières ») | `Atelier.matiere("cobbles")` ; `Bibliotheque.matiere("matieres-de-minuit@1", "marbre_noir")` |
| Données | (socle 1.15) les données JSON de la commune, en clair ou compressées en gzip (`.gz`) : une donnée de plus de 100 Ko part compressée ([`docs/BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md), « Les règles des paquets ») | `Atelier.donnees("res://communes/<id>/donnees/pnj.json")` lit `pnj.json`, ou `pnj.json.gz` s'il est seul |
| Polices | les trois polices du jeu | `Polices.texte()`, `Polices.gras()`, `Polices.titre()` |
| Scènes | le stade du socle (structure `terrain_foot`), la salle de jeu (structure `salle_jeu`) et le commerce (structure `commerce`), section « Les structures » ; l'habitant et la caméra, dans la scène du kit | `Football.ouvrir_stade(commune)`, `SalleJeu.ouvrir(commune, id)`, `Commerce.ouvrir(commune, id)` |
| Tables de jeu | les tables 3D du casino de Smarves et leurs panneaux, dernière version (socle 1.10, « Les tables du casino ») ; les machines `arcade` et la `table_jeu` de la brocante ne sont que du décor | `Tables.table("blackjack")`, `Tables.panneau("blackjack")`, `Tables.asseoir(…)` |

Les personnages nommés de Smarves (Josiane, M. Brunet…) restent à Smarves : une commune a ses propres habitants, l'atelier ne lui prête que des figurants.

```sh
godot --headless --path . -s tools/test_atelier.gd
```

### Le Claude du développeur

Le kit est aussi un **serveur MCP**, [`tools/mcp/kit_communes.py`](../tools/mcp/kit_communes.py) : le Claude du développeur y trouve les règles, l'atelier et les outils du dépôt sans avoir à les chercher. Il lit les mêmes fichiers que le jeu et lance les mêmes outils, donc ses réponses sont celles du jeu. Python 3.9 ou plus, aucune dépendance ; Godot 4.7 pour tester et emballer.

| Outil | Ce qu'il fait |
|---|---|
| `contrat` | les sections de ce document (le manifeste, les structures, le paquet, la publication) |
| `conception` | les sections de [`CONCEPTION.md`](CONCEPTION.md), la méthode de conception d'un lieu (intentions, trois scènes, continuité, palette, animation, critique) |
| `atelier` | le catalogue de l'atelier, une famille de modèles, ou une recherche par nom (« bench ») |
| `nouvelle_commune` | une commune depuis le kit, par son seul code INSEE (nom et population viennent de `communes/vienne.json`), avec sa note d'intentions à remplir |
| `verifier_manifeste` | les refus rapides d'un `commune.json` et ce que le portail affichera vide |
| `tester_commune` | `tools/test_commune.gd` sur la commune, le kit ou un `.pck` |
| `parcourir_commune` | `tools/parcours_commune.gd` : les poses et les marches entre les repères de vue, et les captures si Godot a un rendu |
| `emballer_commune` | `tools/emballer_commune.gd`, avec la taille du paquet face aux 32 Mo |
| `bourg_reel` | `tools/bourg_reel.py`, le plan réel du bourg |

Le dépôt n'est pas publié par le serveur : le paquet se dépose sur le portail des développeurs, qui montre ce qu'il contient avant l'envoi.

- **Claude Code** : le fichier [`.mcp.json`](../.mcp.json) à la racine du dépôt (et du SDK) le déclare. En ouvrant `claude` dans le SDK ou dans un clone de Smarves, Claude Code propose de l'activer ; `/mcp` montre son état. Sous Windows, si `python3` n'existe pas, remplacez-le par `py` dans `.mcp.json`.
- **L'application Claude** (bureau) : Réglages, Développeur, Modifier la configuration, puis ajoutez dans `claude_desktop_config.json`, avec le chemin du SDK (ou du clone) :
  ```json
  {"mcpServers": {"kit-communes": {"command": "python3", "args": ["/chemin/vers/smarves/tools/mcp/kit_communes.py"]}}}
  ```
  Si Godot n'est pas dans le PATH, ajoutez `"env": {"GODOT": "/chemin/vers/godot"}`.

```sh
python3 tools/mcp/test_kit_communes.py           # le protocole et les outils sans Godot
python3 tools/mcp/test_kit_communes.py --godot   # avec tester_commune sur le kit et une commune créée
```

### Le paquet

- Un **pack Godot 4** (`.pck`, formats 2 à 4, non chiffré), nommé par l'id de la commune. Pas une archive zip : c'est le format que le socle sait lire sans le monter.
- **Tout sous `res://communes/<id>/`**, plus seulement ce qu'un export ajoute de lui-même (`.godot/imported/`, `.godot/exported/`, `.godot/uid_cache.bin`, `.godot/global_script_class_cache.cfg`, `project.binary`). L'id est celui du manifeste ; le kit le tire du nom (« La Villedieu-du-Clain » → `la_villedieu_du_clain`).
- **Aucun code natif** : ni `.gdextension`, ni `.so`, `.dll`, `.dylib`, `.wasm`, `.framework`. Scènes, ressources et GDScript seulement.
- **Un son bouclé fabriqué en mémoire** (`AudioStreamWAV` rempli par le script) garde quelques centaines d'échantillons après `loop_end`, recopiés du début de la boucle : le mélangeur de Godot 4.7 lit au-delà de `loop_end` pour interpoler, et sur Android ce dépassement tombe sur une page interdite. Le jeu se ferme alors sans message (signal 11 dans le fil `AudioTrack`), au premier tour de boucle ; sur ordinateur rien ne se voit. Civaux 0.1.1 plantait ainsi sur Pixel 7 ; `scripts/sfx.gd` prend la même précaution pour l'ambiance du village.
- **32 Mo au plus**, refusé au-delà par la page avant même l'envoi.
- **Léger** (socle 1.15) : les grandes textures en WebP avec perte, les données lourdes compressées, rien de ce que le jeu a déjà. L'emballeur convertit les textures et dit ce qui pèse encore, la page aussi, sans refuser ([`docs/BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md), « Les règles des paquets »). Un fichier `emballage.json` garde sans perte ce qui est relu au pixel.
- **Dans les seuils** (socle 1.16) : chaque lieu du paquet (la scène de la commune, celles de ses structures) a un budget une fois bâti : 600 000 triangles, 2 500 surfaces dessinées, 80 lampes dont 8 à ombres, 96 Mo de textures, 8 000 nœuds, 250 scripts actifs, 250 étiquettes ([`docs/LENTEUR.md`](LENTEUR.md), « Le budget par lieu »). L'emballeur bâtit chaque lieu, le mesure, dit ce qui dépasse et range la mesure dans le paquet (`communes/<id>/budget.json`) ; la page la lit et la dit lieu par lieu, sans refuser. Un paquet fait par un emballeur d'avant le socle 1.16 n'a pas ce fichier : la page demande de le refaire avec le SDK à jour. `tools/budget_lieu.gd -- --pck=….pck` mesure un paquet sans l'emballer. Les triangles comptés sont ceux que le moteur dessine au regard le plus chargé (niveaux de détail, champ de la caméra) ; sans rendu (`--headless`), les multimaillages comptent en entier : emballer sans `--headless` les mesure au plus juste.
- Un seul manifeste, `res://communes/<id>/commune.json`, au format décrit plus haut, avec en plus pour la publication :
  - `insee` : la commune choisie sur la page, une commune actuelle de la Vienne de `communes/vienne.json`, ni Smarves (86263) ni Poitiers (86194) ;
  - `version` : trois nombres (`0.1.0`), plus grande que la dernière version déposée pour cette commune (un dépôt refusé ne consomme pas sa version) ;
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
- **Le carnet** (touche C) a un onglet « La Vienne » : chaque commune publiée, sa description, « → l'installer » (taille, auteur), puis « → y aller ». Une version plus récente au catalogue se propose à la place ; elle s'installe à côté et prend la place de l'ancienne au lancement suivant, parce qu'un pack déjà ouvert ne se remplace pas en cours de partie.
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
| `publiees()`, `installees()`, `au_catalogue(id)` | les deux listes pour la carte, et une entrée du catalogue (avec ses `structures`) |
| `installer(id)`, `installee`, `en_cours`, `installations` | installer une commune publiée ; versions installées |
| `visiter(id)`, `revenir()` | entrer dans une commune greffée (derrière l'écran de chargement, `Chargement`), et revenir à Smarves |

### `Commune` (classe, `scripts/socle/commune.gd`)

`Commune.lire(chemin)` lit et vérifie un manifeste ; `valide()` et `erreurs` disent s'il est bon. `lieux()`, `salles(interieur)` et `structures()` rendent les lieux et les salles dans la forme de `PLACES` et `LOCKS` ; `preteur()`, `banque()`, `interieur(id)` et `centre()` (la position réelle, d'après le code INSEE) lisent le reste.

### `Budget`, `Lointain`, `Memo` (classes, `scripts/socle/`) — socle 1.16

Ce que le socle fait de lui-même sur les lieux d'une commune, et qu'elle peut appeler ([`docs/LENTEUR.md`](LENTEUR.md)) :

| | |
|---|---|
| `Budget.mesurer(racine, points, directions)`, `Budget.points_de_vue(racine)`, `Budget.depassements(mesure)`, `Budget.resume(mesure)`, `Budget.SEUILS` | la mesure d'une scène bâtie (triangles et surfaces dessinés au regard le plus chargé, avec niveaux de détail et champ de la caméra, et au plus fin : `triangles_pleins` ; lampes, ombres, textures, nœuds, scripts actifs, étiquettes), les points de vue du joueur (caméra, zones d'interaction), ce qui dépasse les seuils du socle, une ligne de résumé ([`docs/LENTEUR.md`](LENTEUR.md), « Ce qui est vraiment dessiné ») |
| `Lointain.appliquer(racine)` | ce que `Chargement` fait à chaque scène 3D qui arrive : les primitives (sphères, cylindres, capsules, tores) ramenées aux segments de leur taille vue, et des niveaux de détail aux maillages de dix mille triangles et plus, calculés dans un fil. Une scène qui n'en veut pas pose la méta `sans_lointain` sur sa racine |
| `Memo.valeur(famille, script, cle, fabrique)`, `Memo.image(…)`, `Memo.bruit(famille, script, cle, texture)` | ce qu'un script fabrique à l'identique à chaque lancement (un maillage sommet par sommet, une image peinte, une `NoiseTexture2D`) se fabrique une fois et se relit du disque du joueur (`user://cache/<famille>/`) ; la famille est le nom de la commune, le script celui qui fabrique (son empreinte jette le rangement quand il change) |

### `Vienne` (classe, `scripts/socle/vienne.gd`)

Le référentiel : `Vienne.communes()`, `Vienne.commune(insee)`, `Vienne.centre(insee)`. `Commune.smarves()` est Smarves, lue une fois.

### Le carnet du joueur (autoload `Carnet`, `scripts/carnet.gd`) — socle 1.3

Le carnet est un cahier à intercalaires. **« Mon compte »** est au socle : ce qui suit le joueur d'une commune à l'autre (crédits, dette par banque au nom de la `banque` de chaque manifeste, biens, obligations des clubs, positions en bourse, fortune nette, bilan depuis le début), la semaine de l'agenda et les engagements en cours (tickets, obligations, positions). **« Mes cartes »** est au socle aussi : un classeur de cartes à collectionner, les villages l'un sous l'autre (l'origine d'abord, puis chaque commune où le joueur tient quelque chose), chacun en trois rubriques : ses biens (les articles du `commerce` et les adresses de l'`etude` de la commune, comme ceux de Smarves), ses clubs sportifs (le club du `terrain_foot` ou du gymnase, seulement si le joueur en tient une obligation, avec les neuf cartes : à lui, en vente, à d'autres joueurs) et ses établissements à parts (seulement si le joueur en tient une). Le panneau du stade, le registre des obligations et le tableau des parts de la salle de basket montrent les cartes de leur club. Une commune n'a rien à déclarer pour y figurer ([`scripts/carnet_cartes.gd`](../scripts/carnet_cartes.gd)).

Viennent ensuite **un onglet par commune** (l'origine d'abord, puis chaque commune qui déclare des compteurs ou où le joueur tient des cartes) et **« La Vienne »** (installer, visiter, les derniers passages). La page d'une commune rappelle en petit les cartes que le joueur y tient, et le renvoie à son notaire pour acheter autre chose ; ses compteurs `case` cochés y sont repris en tampons, sous « Mes réussites ». Les flèches ← → tournent les pages.

Une commune n'écrit jamais dans le transversal ; elle tient **sa page** par des compteurs, déclarés dans son manifeste et écrits par le socle :

```json
"socle_min": "1.3",
"carnet": [
	{"id": "parts_moulin", "libelle": "Parts du moulin", "genre": "nombre", "rubrique": "Mes affaires"},
	{"id": "caisse", "libelle": "Dans la caisse du café", "genre": "credits", "rubrique": "Mes affaires"},
	{"id": "surnom", "libelle": "Au club de pétanque", "genre": "texte"},
	{"id": "carte_peche", "libelle": "Carte de pêche", "genre": "case"}
]
```

- **Les champs.** `id` : minuscules, chiffres, `_`, unique dans la commune. `libelle` : 60 caractères au plus, écrit tel quel. `genre` : `nombre` (entier), `credits` (entier, écrit comme les crédits), `texte` (coupé à 80 caractères), `case` (vrai ou faux, écrit « oui » ou « — »). `rubrique` (facultative) : les compteurs d'une même rubrique se suivent sous ce titre, dans l'ordre du manifeste ; au-delà de quatorze lignes, la page continue à droite.
- **Écrire** : `Carnet.noter("<id de la commune>", "<id du compteur>", valeur)` rend vrai si c'est noté. Refusé (faux, et la raison dans `Communes.refus`) : une commune inconnue, une commune qui n'est pas celle où se trouve le joueur (`Communes.actuelle()` : on n'écrit que chez soi), un compteur non déclaré, une valeur d'un autre genre (`2.0` passe pour un nombre). **Lire** : `Carnet.lire(commune, cle, defaut)`.
- **Où c'est rangé.** Dans la sauvegarde du socle (`socle.save`, clé `carnet`), pas dans le tiroir : `{commune: {nom, compteurs, valeurs, vu}}`, avec une copie de la déclaration. La page se dessine donc de partout, sans monter le paquet et sans appeler son code, même si la commune est désinstallée ; elle dit la date du dernier passage (`vu`, noté à chaque arrivée et à chaque écriture). Elle part au compte avec le reste de la partie.
- **La vérification** (`Commune.verifier_carnet`, dans `verifier_facultatifs`) refuse le manifeste avec ces phrases, que le portail reprend : « carnet doit être une liste de compteurs », « carnet : 24 compteurs au plus », « carnet : compteur incomplet (id, libelle, genre) : … », « carnet : id invalide : « … » (minuscules, chiffres, _) », « carnet : compteur en double : … », « carnet : genre inconnu pour … : « … » (nombre, credits, texte, case) », « carnet : libelle de … trop long (60 caractères au plus) », « carnet : rubrique de … doit être un texte ».
- Test : `godot --headless --path . -s tools/test_carnet.gd`.

### La sauvegarde en tiroirs (`scripts/socle/sauvegarde.gd`)

| Fichier | Qui l'écrit | Ce qu'il tient |
|---|---|---|
| `user://socle.save` | `Game` | ce qui vaut pour toutes les communes : `bourse` (crédits), `gagne` (le total gagné au jeu, la clé de tous les seuils), `mise`, `pic`, `dettes` (par prêteur : `{"smarves": 4297}`) |
| `user://communes/<id>.save` | `Game`, pour chaque commune | le tiroir de la commune ; celui de Smarves tient `avances` (Josiane), `prets` (accordés par M. Brunet) et `accueil` |
| `user://smarves_biens.save` | `Biens` | les biens, comme avant (et les logements du fil Gestion) ; le fichier ne bouge pas |

- **Au premier lancement**, l'ancien fichier unique `user://smarves.save` est lu une fois, réécrit en tiroirs, puis renommé `smarves.save.ancien` : rien n'est perdu, et l'ancien fichier ne repasse jamais devant les tiroirs. Un outil lancé par `-s` lit l'ancien fichier sans le migrer. `tools/test_sauvegarde.gd` écrit une partie à l'ancien format, la migre, la relit, et relit aussi un fichier de biens à l'ancien format.
- **Une commune greffée range ses affaires** dans `Game.tiroir("<id>")`, un dictionnaire de valeurs JSON, écrit avec la partie à chaque `Game.changed`. Elle n'écrit jamais dans le socle.
- **La dette est tenue par prêteur.** `Game.borrow(montant, preteur)`, `Game.repay(montant, preteur)` et `Game.debt_of(preteur)` ; sans prêteur, c'est celui de la commune d'origine (`banque.preteur` du manifeste de Smarves, donc M. Brunet). `Game.debt` reste le total, et l'écrire ajuste le prêteur par défaut : le code d'avant (Biens, le guichet de M. Brunet, le carnet) garde le même sens. Les intérêts courent pour chaque prêteur, au même taux.
- **Effacer sa partie** (tout au fond de la bienvenue, `scripts/bienvenue.gd`, après avoir écrit EFFACER ; plus de « Nouvelle partie » dans le menu Échap) : `Game.reset()` efface le socle et tous les tiroirs.

### Ce qui existe déjà et reste à rendre générique

Ces API existent dans le code de Smarves ; le cadrage (SUITE.md, section 5) dit comment elles s'ouvriront aux autres communes, dans l'ordre des chantiers :

- `Game` : crédits, gagné au jeu (`won`, la clé partagée par toutes les communes), misé, dette par prêteur, `changed`, `brunet_calls`, `spend`, `cash_in`, `borrow`, `repay` ; plus tard une source (`commune/lieu`) sur `spend` et `cash_in`, et un signal `played(source, mise, gain)`.
- `Biens` : catalogue, `buy`, `sell`, la recette toutes les 20 mises ; plus tard `Biens.register(commune_id, items)`.
- `Carnet` : ses onglets, `show_slip`, `noter` et `lire` (section « Le carnet du joueur ») ; la page de Smarves est `scripts/carnet_smarves.gd`.
- `Village.lots` : les portes de Smarves, avec leur `Area3D` (métadonnée `action`) ; plus tard une classe `Lots` commune.
- Les seuils : aujourd'hui `PLACES` (main.gd) et `LOCKS` (casino), lus depuis le manifeste ; plus tard un registre `Seuils` qui annonce les ouvertures de toutes les communes.
- `Cast.NAMED` et `Cast.resolve()` : les personnages ; plus tard `Cast.register(commune_id, fiches)`.
