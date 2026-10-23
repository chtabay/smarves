# La bibliothèque commune

Demande de Guillaume du 22 octobre 2026 : une bibliothèque d'assets embarquée dans le jeu, que les villes emploient par référence au lieu d'embarquer leurs propres modèles, et qu'elles alimentent à leur tour. Pour un stade, « le club de foot doit être lié et rester dans le fonctionnement normal des clubs et être intégré au championnat ». Les paquets existants seront reconstruits par leurs auteurs avec les nouvelles règles.

L'état des lieux du 20 octobre est dans le dossier du projet (`bibliotheque-assets/avis.md`).

## Le principe

Deux règles de Guillaume (22 octobre 2026) passent avant tout le reste :
- **La créativité des producteurs n'est jamais réduite.** La bibliothèque est une offre, jamais une contrainte. Une ville peut tout faire elle-même et rien ne l'oblige à employer une brique. Seuls le club de foot et le club de basket ont un contrat, les ancres, pour qu'ils restent dans le championnat ; le décor autour est libre.
- **Pas de dépôt automatique.** Une brique n'entre dans la bibliothèque que si Guillaume l'accepte, à la main, après l'avoir regardée. Cela évite une bibliothèque qui gonfle sans contrôle. Une ville propose ; elle ne publie pas dans la bibliothèque.

- **Le décor se partage, le fonctionnement reste au socle.** Un stade de la bibliothèque est un décor : tribunes, club-house, tableau, haies. Le club, son effectif, le championnat, le match, le mercato, la causerie, les obligations et les paris restent ceux du socle, identiques pour toutes les villes. Aucune brique n'emporte sa propre gestion.
- **Le lien entre les deux est un contrat d'ancres** (`scripts/socle/ancres.gd`). Le décor montre quelques nœuds nommés ; le socle y pose ce qui est à lui. Un décor n'a pas à hériter d'un script du socle : il lui suffit de tenir le contrat.
- **Une brique a un identifiant et une version** (`stade-de-campagne@1`). Une version publiée ne change plus. Une retouche se publie en `@2`, dans un dossier à côté, et les villes restées sur `@1` la gardent telle quelle.
- **La liberté créative reste entière.** Une ville peut tout faire elle-même ; elle gagne seulement du poids quand elle réutilise. Trois niveaux, du plus simple au plus libre :
  1. **Référence** : `"modele": "stade-de-campagne@1"`, avec son club, ses couleurs et son nom.
  2. **Maison** : `"modele": "res://communes/<id>/….tscn"`, son propre décor, sans héritage, qui tient le contrat. Le club s'y branche de la même façon.
  3. **Héritage** (socle 1.8, inchangé) : `"scene"`, un stade dont le script hérite de `scripts/village/stade.gd`, comme le stade de la Fortune de Minuit.

## Le catalogue

`bibliotheque/bibliotheque.json`, lu par `Bibliotheque` (`scripts/socle/bibliotheque.gd`), et recopié dans le portail (`STADES_DE_LA_BIBLIOTHEQUE`, `SALLES_DE_LA_BIBLIOTHEQUE`, `SALLES_DE_JEU_DE_LA_BIBLIOTHEQUE` et `ETUDES_DE_LA_BIBLIOTHEQUE`, `src/lib/communes/structures.ts` dans Pyramides2) pour qu’il refuse une référence inconnue : ajouter une brique au jeu, c’est aussi l’ajouter là.

```json
"stade-de-campagne": {
	"genre": "stade", "nom": "Le stade de campagne", "description": "…",
	"auteur": "Smarves", "licence": "celle du jeu",
	"versions": {"1": {"scene": "res://bibliotheque/stade-de-campagne/1/stade.tscn", "socle": "1.13"}}
}
```

Chaque version vit dans `res://bibliotheque/<id>/<version>/`. `socle` est le socle à partir duquel elle existe : un jeu plus ancien ne la propose pas. `auteur` est le crédit de la ville ou du créateur qui l'a apportée.

| Fonction | Ce qu'elle rend |
|---|---|
| `Bibliotheque.est_reference(ref)` | si `ref` a la forme `id@version` |
| `Bibliotheque.brique(ref)` | la brique et sa version (`id`, `version`, `genre`, `nom`, `auteur`, `licence`, `scene`, `socle`), ou `{}` |
| `Bibliotheque.scene(ref, genre)` | la scène, ou `""` si la référence est inconnue, d'un autre genre ou trop récente |
| `Bibliotheque.references(genre)` | toutes les références d'un genre |

## Le contrat du stade (socle 1.13)

Une ancre est un nœud 3D nommé (un `Marker3D`, le plus souvent), n'importe où sous la racine du décor. Son axe **+Z regarde le visiteur** : c'est la face lisible d'un `Label3D`, et la direction où regarde un personnage posé dessus.

| Ancre | Requise | Ce que le socle y pose |
|---|---|---|
| `Pelouse` | oui | le terrain : la pelouse de 36 × 22 (longueur selon x), ses lignes, ses buts, les bancs, la main courante, les quatre pylônes, le ballon, les vingt-deux joueurs et le match. **À l'origine du décor, sans rotation.** Le terrain et ses abords occupent ±23 × ±15 : le décor commence au-delà. |
| `Arrivee` | oui | le visiteur, à son entrée, tourné vers le +Z de l'ancre |
| `Sortie` | oui | la porte du retour vers la ville |
| `Tableau` | oui | le centre de la face du tableau d'affichage : le score (0,4 au-dessus), la minute (0,35 au-dessous), l'affiche (0,85 au-dessous), une lampe, et la feuille du dernier match au pied |
| `President` | oui | le président du club (l'hôte du lieu), son nom et sa causerie |
| `Bureau` | oui | la gestion du club : effectif, tactique, mercato, registre des obligations |
| `Panneau` | oui | le panneau du club : classement, prochain match, obligations |
| `TribuneClub` | non | le nom du club et du stade, aux couleurs du club, sur le fronton |
| `Buvette` | non | la tenancière et ses phrases |

Le décor apporte ses propres collisions (sol compris, au-delà du terrain), ses lumières et sa foule s'il en veut. Il ne lit ni le club ni le championnat. Un décor introuvable, ou qui ne tient pas le contrat, est laissé de côté : le stade du socle prend sa place, et le journal dit pourquoi (`Ancres.verifier_stade`). Le portail vérifie la forme de la référence et son existence ; l'essai d'un décor maison se fait avec le kit : `godot --path . -s tools/capture_stade_modele.gd -- --modele=<référence ou chemin> --capture=sortie.png`.

**Le décor vivant** (socle 1.20). Un décor de commune qui fait plus que se laisser poser (une foule qui suit la semaine, sa propre nuit, des interactions à lui) peut avoir trois méthodes, toutes facultatives (`Ancres.CROCHETS`) :

| Méthode | Quand | Ce qu'elle fait |
|---|---|---|
| `nuit(stade)` | avant la pelouse | la nuit du stade (le ciel, la lune, les projecteurs), à la place de celle du socle et de ses quatre pylônes |
| `brancher(stade)` | une fois le stade posé (terrain, président, match, visiteur) | ce qui a besoin du stade : la vie de la semaine, les annonces, un président habillé autrement, le score recopié sur d'autres écrans |
| `interagir(cle, cible) -> bool` | à chaque interaction, avant le socle | les interactions du décor, ou les siennes à la place de celles du socle (la sortie qui devient un taxi) ; vrai s'il l'a prise |

Un tel décor connaît le stade : c'est un décor de commune, pas une brique de la bibliothèque, qui se suffit de ses ancres. Casino Minuit s'en sert depuis sa version 0.10.5 pour le stade de la Fortune (`stade/fortune.gd`) : le bol, la roue et l'écran à 360°, le parvis et la station de taxis sont son décor ; la pelouse, le match, M. Castellane et sa gestion, le panneau et le tableau sont ceux du socle, posés sur ses ancres. Rien n'a changé à l'écran.

Premier stade de la bibliothèque : **`stade-de-campagne@1`**, un terrain de village (tribune de bois couverte, club-house et sa véranda où le président a son bureau, buvette, tableau à volets, haie de charmille et portail). Test : `godot --headless --path . -s tools/test_bibliotheque.gd`.

## Le contrat de la salle de basket (socle 1.14)

Le champ `modele` du gymnase nomme une salle de la bibliothèque (`"modele": "salle-de-quartier@1"`) ou une scène de la commune, comme pour le stade, et `scene` et `modele` ne vont pas ensemble. Le club de basket reste celui du championnat : son match, son effectif, ses parts et son bureau sont ceux du socle. Les ancres suivent la même règle que celles du stade (+Z vers le visiteur).

| Ancre | Requise | Ce que le socle y pose |
|---|---|---|
| `Parquet` | oui | le terrain : le parquet de 28 × 15 (longueur selon x), ses lignes et le rond central aux couleurs du club, les deux paniers, les bancs et la table de marque, les fauteuils du bord, les joueurs, la mascotte, les danseuses et le match. **À l'origine du décor, sans rotation.** Le parquet et ses abords occupent ±18 × ±11,5 : le décor commence au-delà. Le socle éclaire le parquet par quatre rampes, 2 m au-dessus du centre du cube. |
| `Arrivee` | oui | le visiteur, à son entrée, tourné vers le +Z de l'ancre |
| `Sortie` | oui | l'arrêt du car, qui ramène à la place de la ville |
| `Cube` | oui | le centre du cube d'écrans (7,6 m de côté, l'anneau lumineux 2,3 m sous son centre) : le score sur quatre faces, l'entraînement ou le prochain match. Le plafond du décor passe au moins 3,5 m au-dessus. |
| `President` | oui | le président du club, qui suit le visiteur des yeux, et sa causerie |
| `Bureau` | oui | la gestion de l'équipe (l'écran du bureau du fil basket) |
| `Panneau` | oui | le panneau du club : classement, prochain match, effectif |
| `Parts` | oui | le tableau des parts du club : les porteurs, l'achat de parts |
| `Fronton` | non | le nom du club et de la salle, aux couleurs du club |

Avec un décor, le socle ne pose rien du Clain Garden : ni les gradins et leur foule, ni le hall, la coursive et ses échoppes, ni le parvis, ni la pièce à part du bureau du président. Le décor apporte ses murs, son sol au-delà du parquet, ses lumières et sa foule s'il en veut. Un décor introuvable ou qui ne tient pas le contrat est laissé de côté : c'est la salle du socle (`Ancres.verifier_salle`). L'essai d'une salle : `godot --path . -s tools/capture_salle_modele.gd -- --modele=<référence ou chemin> --capture=sortie.png` (la salle de Smarves sur ce décor).

Première salle de la bibliothèque : **`salle-de-quartier@1`**, un gymnase municipal (murs de brique et plinthe bleue, charpente de métal, six rangs de gradins au nord, le bureau du club vitré à l'ouest, le panneau et le tableau des parts à l'est, la porte sous l'enseigne, le parvis et l'abribus).

## Les intérieurs : la salle de jeu et l'étude (socle 1.22)

Deux genres de briques de plus, pour les intérieurs que le socle tient déjà : la salle de jeu (structure `salle_jeu`) et l'étude du notaire (champ `notaire`). Le `modele` de la salle de jeu, ou `notaire.modele`, nomme une brique de la bibliothèque (`"modele": "bar-des-sports@1"`, `"modele": "etude-de-notaire@1"`) ou une scène de la commune. Le socle ne bâtit alors pas sa pièce : il pose le décor et y branche ce qui est à lui par ses ancres (`Ancres.SALLE_JEU`, `Ancres.ETUDE`), avec la même règle que pour le stade (+Z vers le visiteur). Les jeux, leurs tables, la bourse, le registre et la sortie restent ceux du socle. Le décor apporte ses murs, ses lumières (sans `WorldEnvironment` à lui, il prend celui des salles du socle), son mobilier et ses figurants. Un décor introuvable ou qui ne tient pas le contrat est laissé de côté : c'est la pièce du socle.

La salle de jeu :

| Ancre | Requise | Ce que le socle y pose |
|---|---|---|
| `Arrivee` | oui | le visiteur, à son entrée, tourné vers le +Z de l'ancre |
| `Sortie` | oui | la porte du retour vers la commune |
| `Comptoir` | oui | le tenancier, derrière son comptoir ; on lui parle du côté +Z, jusqu'à 3 m devant l'ancre |
| `Table1`, `Table2`… `Table9` | la première | une table du casino par jeu de la structure, dans l'ordre : l'ancre au sol, au centre de la table, son +Z vers la place du joueur. Un jeu sans ancre n'est pas posé. |
| `Guichet` | non | le banquier de la commune, si la salle a un `guichet` |
| `Enseigne` | non | l'enseigne de la salle (`enseigne`, sinon son nom) |

L'étude :

| Ancre | Requise | Ce que le socle y pose |
|---|---|---|
| `Arrivee` | oui | le visiteur, à son entrée, tourné vers le +Z de l'ancre |
| `Sortie` | oui | la porte du retour vers la commune |
| `Notaire` | oui | le notaire, derrière son bureau ; on consulte le registre du côté +Z. Avec la méta `assis` à vrai, il est assis (le bassin sur une assise de 0,53 m). |
| `Registre` | non | un second endroit où consulter le registre, un comptoir d'accueil |
| `Enseigne` | non | le nom de l'étude |
| `Plaque` | non | le nom du notaire, sur la plaque du bureau |
| `Plan` | non | le premier quartier du registre, dessiné sur un papier de 3,2 × 1,45 m centré sur l'ancre |

Les textes que le socle écrit sur une ancre se règlent par ses métas : `hauteur` (la taille des lettres, en mètres), `largeur` (la place qu'ils ne dépassent pas), `couleur`, et `espace` (en capitales espacées, comme une enseigne peinte). L'essai d'un intérieur : `godot --path . -s tools/capture_interieur_modele.gd -- --modele=<référence> --capture=sortie.png [--at=x,z,lacet]` (le tripot ou l'étude de la commune d'essai sur ce décor).

Les deux premiers viennent de Cloué 1.6.2 (Atelier des communes, MIT, notice gardée dans `LICENCE.txt`), sans Cloué :

- **`bar-des-sports@1`**, le Sport Bar de Selim : une salle de 28 × 24 m en brique et bois sombre, le comptoir cannelé de 11 m sous un portique de trois écrans, le mur de bouteilles, le lounge et les alcôves, l'alcôve des tables tapissée de vert, le salon du club et sa vitrine. Ses dix écrans passent une séquence de football dessinée (`animation_football.gd`), sans rencontre ni score réels : les relevés de l'original sont restés à Cloué. Quatre places de table, deux dans l'alcôve et deux dans la salle ; pas de guichet.
- **`etude-de-notaire@1`**, l'étude des Sources : 12,4 × 11,2 m de boiseries vert sauge, l'accueil du clerc et son registre, le cabinet derrière une travée ajourée, la bibliothèque des archives, le cabinet à plans sous le cadre du plan, le salon d'attente. Le notaire s'y assoit dans son fauteuil.

## Les matières (socle 1.17)

Une brique de genre `matieres` est une boîte d'images de matières (marbres, bois, moquettes, étoffes…), chacune avec sa taille réelle et ses réglages, qu'une commune emploie par leur nom au lieu de les mettre dans son paquet. Rien n'oblige à s'en servir : une commune garde ses propres textures si elle veut.

```gdscript
var sol := Bibliotheque.matiere("matieres-de-minuit@1", "marbre_creme")
var nuit := Bibliotheque.matiere("matieres-de-minuit@1", "marbre_creme", {"teinte": Color(0.6, 0.57, 0.55)})
```

| Fonction | Ce qu'elle rend |
|---|---|
| `Bibliotheque.matiere(ref, nom, reglages = {})` | un `ShaderMaterial` neuf, prêt à poser : l'image en dalles de taille réelle, sans UV (`shaders/matiere.gdshader`), avec les réglages de la brique ; `reglages` les remplace (`teinte`, `dalle`, `origine`, `rugosite`, `metal`, `speculaire`, `lueur`, `contraste`). `null` si la référence ou le nom est inconnu |
| `Bibliotheque.texture(ref, nom)` | l'image seule, pour un matériau à soi |
| `Bibliotheque.matieres(ref)` | les matières de la brique, par nom, avec leurs réglages |

Le shader pose l'image vue d'en haut en (x, z) et vue de côté en (horizontale, −y), dans le repère de l'objet : un maillage fusionné sans UV la reçoit à la bonne taille. Les images sont rangées tête-bêche, comme le veut le glTF, et le shader les relit à l'endroit.

La version vit dans `res://bibliotheque/<id>/<version>/`, avec ses images et un fichier `matieres.json` que le catalogue nomme (`"matieres": "res://bibliotheque/<id>/1/matieres.json"`, à la place de `scene`) :

```json
{
	"format": 1,
	"matieres": {
		"marbre_noir": {"image": "marbre_noir.png", "nom": "Marbre noir", "dalle": [2, 2], "rugosite": 0.25, "metal": 0.05}
	}
}
```

- Le nom d'une matière s'écrit en minuscules, chiffres et soulignés ; `image` est une image du dossier (png, jpg, webp), sans chemin ; `dalle` est la taille réelle d'une répétition de l'image, en mètres.
- Les réglages facultatifs et leurs bornes : `rugosite`, `metal`, `speculaire`, `contraste` (0 à 1), `lueur` (0 à 4).
- La planche d'une brique (chaque matière sur un bloc, avec son nom) : `godot --path . -s tools/planche_matieres.gd -- --ref=<référence> --capture=planche.png`.

Première brique de matières : **`matieres-de-minuit@1`**, les dix-neuf matières de la direction artistique de Casino Minuit, de Guillaume : trois marbres (crème, noir, rouge) et leur damier, le bois clair et le bois laqué, cinq moquettes (de la salle, du salon, du poker, du foyer, des machines), le velours à galon, le capiton rouge, l'onyx rétroéclairé, la mosaïque, le dallage de jardin, le plafond à caissons, l'eau de bassin et le ciel peint. Ce sont les images de Minuit à l'octet près (1,8 Mo), avec les réglages de son kit, compressées pour la carte graphique à l'import (S3TC ou ETC2 : ce sont des surfaces unies, la perte ne se voit pas). Minuit les prend dans la bibliothèque depuis sa version 0.10.1 (`socle_min` 1.17) : son kit les nomme (`Bibliotheque.texture`) et les matières de son décor les désignent par leurs extras (« matiere »), que `decor.gd` remplit au chargement. Son paquet n'en emporte plus de copie.

## Les décors

Une brique de genre `decor` est un modèle ou un ensemble à poser tel quel, sans comportement ni contrat d'ancres : la commune instancie sa scène (`Bibliotheque.scene(ref, "decor")`) où elle veut. Ses réglages sont les propriétés de la racine de la scène, à donner avant de l'ajouter à l'arbre.

Premier décor : **`facadier-du-poitou@1`**, le façadier de Chauvigny 0.2.2 (Le duke, licence MIT, notice dans `LICENCE.txt` du dossier). Une maison de bourg composée par type et graine : dix types (`medievale`, `echoppe`, `balet`, `vigneron`, `notable`, `tailleur`, `grange`, `quai`, `ouvriere`, `forte`) et quatre axes de diversité (la silhouette, la matière, la décoration, l'habillage végétal), si bien que deux voisines ne sont jamais pareilles.

```gdscript
var m = load(Bibliotheque.scene("facadier-du-poitou@1", "decor")).instantiate()
m.type = "notable"
m.graine = 12
m.options = {"w": 8.0, "quartier": "basse", "pente": 0.4}
add_child(m)
var largeur: float = m.get_meta("w")   # pour aligner la suivante
```

- **Le repère** : la façade regarde +Z, l'origine est au pied de la façade, au milieu, et le corps s'étend vers −Z. Les mesures sont en mètres : une commune à l'échelle du village de Smarves (1 unité = 2,4 m) pose la maison à l'échelle 1/2,4.
- **Les options**, toutes facultatives : `w` et `d` (largeur et profondeur), `niveaux`, `quartier` (la palette des menuiseries : `cite` en teintes sourdes, `basse` franches, `quai` en couleurs de bateau, `montee` entre les deux), `pente` (le dénivelé sous la façade, de gauche à droite : la porte va du côté haut), `lumiere` (la part des fenêtres allumées), `histoire` (les traces de transformation imposées : une liste, ou `false`), `vegetal` (`vigne`, `lierre`, `glycine`, `rosier`, `jardinieres`, `treille` : un nom, une liste, `true` ou `false`), `porte` (sa position en x).
- **Après la construction**, la racine porte les métadonnées de la maison : `type`, `graine`, `w`, `d`, `faite`, `porte` (le seuil de la porte principale), `vegetal`, `traces`.
- **Le coût** : une maison fusionne sa géométrie en six surfaces au plus (quatre genres de matière, le feuillage, les fenêtres allumées), avec ses collisions dans un seul corps. La matière est procédurale (`matieres.gdshader`, sans image) : la brique pèse 0,3 Mo, aperçu compris.
- **On peut aussi appeler le façadier sans scène**, pour bâtir une rangée dans un seul groupe : `load(<dossier de la brique> + "facadier.gd").maison(parent, position, type, graine, options)`.

La planche (les dix types sur trois graines) : `godot --path . -s tools/planche_facadier.gd -- --ref=facadier-du-poitou@1 --capture=planche.png` (`--rang=0` pour une rangée de près, `--scene=` pour une maison proposée par une commune).

Deux monuments de pierre, venus eux aussi de Chauvigny 0.2.2 (MIT), chacun posé sur un sol plat à y = 0, ses murs plongeant de 1 à 2 m dessous pour absorber une pente douce. Chaque dossier porte les **primitives de pierre** de Chauvigny (`pierre.gd` : blocs, arcs, toits, pignons, révolutions, tours, donjons, murailles, murs ruinés, rochers, voûtes, portes de ville, escaliers, rampes et soutènements aux collisions justes, fenêtres romanes, lanternes, arbres, fusion par genre de matière), qu'une commune peut appeler pour bâtir les siens : `load(<dossier de la brique> + "pierre.gd").tour(parent, position, rayon, hauteur)`.

- **`donjon-en-ruine@1`** : le donjon du château baronnial, roman et éventré, 12 × 16 m et 14 à 32 m de haut ; la fenêtre géminée, les contreforts plats chaînés, les trous de boulin, les traces des planchers et deux cheminées murales dedans, la tour demi-ronde au nord, la tourelle d'escalier au nord-est, l'aiguille isolée, le lierre et les éboulis. On y entre par la brèche du mur est (+x). Les petits objets s'effacent à 70 m et les trous de boulin à 150 m, comme à Chauvigny. Environ 11 000 triangles.
- **`eglise-romane@1`** : la collégiale Saint-Pierre, 36 × 24 m centrée sur l'origine, la nef selon x (portail à l'ouest, −x ; chevet à l'est, +x) : nef et bas-côtés, transept à oculus, clocher carré sur la croisée, chevet en pièce montée (abside, déambulatoire, chapelles rayonnantes), portail ouest, porte sud et parvis pavé. Pleine, vue du dehors : on n'y entre pas. Réglage : `hauteur_clocher`, la tour sans son toit (34 m par défaut ; 50 à Chauvigny, exagérée pour la ligne d'horizon vue du pont). Environ 17 000 triangles.

Les vues d'un décor (deux trois-quarts et le dessus) : `godot --path . -s tools/capture_decor.gd -- --ref=donjon-en-ruine@1 --capture=dossier/` (`--scene=` pour un décor proposé par une commune).

## Proposer une brique

Une ville qui a fait un décor réutilisable le range, dans son propre paquet, sous `res://communes/<id>/bibliotheque/<id de la brique>/` avec une fiche `brique.json` :

```json
{
	"genre": "stade",
	"nom": "Le stade de la Fortune",
	"description": "Un bol à l'américaine à deux étages de tribunes sous une roue de roulette géante.",
	"auteur": "Guillaume",
	"licence": "celle du jeu",
	"scene": "stade.tscn",
	"apercu": "apercu.png"
}
```

- `genre` (`stade`, `salle`, `decor` ou `matieres`), `nom`, `auteur`, `licence` et `scene` sont requis ; `description` et `apercu` facultatifs. `scene` et `apercu` sont des fichiers du dossier de la brique. Une brique de matières nomme son fichier `matieres` (un `.json` du dossier, section « Les matières ») à la place de `scene`, et ses matières sont vérifiées.
- L'id du dossier s'écrit en minuscules, chiffres et tirets (`stade-fortune`).
- Une brique se suffit : elle ne nomme aucun fichier de sa ville hors de son dossier. Elle peut employer l'atelier et la bibliothèque du jeu.
- La ville s'en sert comme de ses propres fichiers, par son chemin (`"modele": "res://communes/<id>/bibliotheque/stade-fortune/stade.tscn"`). Proposer ne change rien au jeu.
- L'emballeur (`tools/emballer_commune.gd`) dit les briques proposées et refuse une fiche fautive ou un stade, une salle, qui ne tient pas le contrat d'ancres. Le portail les signale dans son rapport.

**L'acceptation est un geste de Guillaume.** Après avoir regardé la brique, il la fait entrer avec `godot --headless --path . -s tools/integrer_brique.gd -- <commune> <brique> --depuis=<dossier de la commune>`. L'outil recopie la brique dans `res://bibliotheque/<brique>/<version>/`, change ses chemins et l'inscrit au catalogue avec le crédit de son auteur et de sa ville. Un nom déjà pris par un autre auteur est refusé, et une nouvelle proposition du même auteur devient la version suivante. La brique entre au jeu à la version suivante du jeu. La ville publie alors une v2 de son paquet qui la référence (`"modele": "stade-fortune@1"`) au lieu de l'embarquer.

## Ce que Casino Minuit gagnerait (mesure du 22 octobre 2026)

Lecture directe du répertoire de `casino_minuit.pck` (27,5 Mo, 538 fichiers). Attention : monter le paquet avec `ProjectSettings.load_resource_pack` puis parcourir `res://` compte aussi les ressources du jeu lui-même ; c'est ce qui avait donné « 63 Mo déballé » et des personnages qui ne sont plus dans le paquet.

| Contenu | Poids | Ce qui peut changer |
|---|---|---|
| Textures du décor (`decor/tex/`, 124 images) | 16,4 Mo | importées **sans perte** : en WebP avec perte (qualité 85), environ 4,8 Mo. Les 19 matières de la DA (marbres, bois, moquettes, velours, ciel, eau : `DA_TEX` de `kit.gd`, environ 2,2 Mo) peuvent monter dans la bibliothèque ; les enseignes, les tapis au logo et les écrans sont propres à Minuit. |
| Zones du décor (42 scènes) | 7,8 Mo | propres à Minuit ; les maillages instanciés de l'original ont été cuits en maillages simples, les ré-instancier allègerait sans changer l'image |
| Données JSON | 1,5 Mo | `pnj_monde.json` (1,4 Mo) passe à 0,2 Mo compressé |
| Code | 1,05 Mo | propre |
| Écrans, polices, shaders | 0,5 Mo | propres |

Les personnages (5,7 Mo) sont déjà sortis du paquet le 21 octobre (PR #186). **Ce que la bibliothèque prendrait encore à Minuit est modeste : 2 à 4,5 Mo.** Le gros gain vient des règles d'emballage : avec elles, Minuit passerait d'environ 27,5 Mo à 11 à 13 Mo. La bibliothèque paie surtout pour les villes à venir : une ville bâtie sur ses briques ne pèse que son code et ce qui lui est propre (Availles-Limouzine, faite du seul catalogue de l'atelier, pèse 1 Mo).

## Les règles des paquets (socle 1.15)

Pour les auteurs qui construisent ou reconstruisent leur paquet. Aucune ne refuse un paquet : l'emballeur applique ce qu'il peut, et l'emballeur comme le portail disent ce qui pèse encore (« À alléger : … »).

1. **Référencer plutôt qu'embarquer** : ce qui est à l'atelier ou dans la bibliothèque ne part pas dans le paquet. L'emballeur compare chaque fichier à ceux du jeu (`res://assets/`, `res://bibliotheque/`) et dit ceux qui y sont déjà.
2. **Textures du décor en WebP avec perte** (qualité 0,85) au-delà de 256 px. L'emballeur les convertit lui-même quand il recopie la commune (`--depuis=…`, le cas d'un dépôt de commune) : il règle leur `.import` avant l'import, sans toucher aux fichiers de l'auteur. Ce qui est relu au pixel (pièces d'écran, atlas de texte) reste sans perte s'il est nommé dans `emballage.json`, à la racine du dossier de la commune, qui ne part pas dans le paquet : `{"sans_perte": ["ecrans/", "ui/atlas.png"]}` (un dossier finit par `/`). Une texture réglée pour la carte graphique (VRAM) reste comme elle est. Le portail repère une texture sans perte dans le paquet par son en-tête (PNG, ou WebP `VP8L`).
3. **Données lourdes compressées** au-delà de 100 Ko (`.json`, `.txt`, `.csv`…, hors manifeste) : `gzip -9 donnees/pnj.json` donne `donnees/pnj.json.gz`, et la commune lit ses données par `Atelier.donnees("res://communes/<id>/donnees/pnj.json")`, qui prend le fichier en clair s'il existe, sinon sa version `.gz`. Le code n'a pas à savoir laquelle est là.
4. **Un stade, une salle** se branchent par leur contrat d'ancres (`modele`), et l'héritage (`scene`) reste pour ce que le contrat ne couvre pas encore.

Le code des règles est `tools/regles_paquet.gd` (test : `godot --headless --path . -s tools/test_regles_paquet.gd`) et `aAlleger` dans `src/lib/communes/paquet.ts` (Pyramides2).

**Mesure sur Minuit** (22 octobre 2026, paquet refait par l'emballeur sans rien changer au dossier, et non republié) : **27,5 Mo → 17,8 Mo**, 76 textures passées en WebP avec perte (les 53 autres font 256 px ou moins). Il ne reste à alléger que `pnj_monde.json` (1,4 Mo, environ 0,2 Mo compressé), qui demande à Minuit de le lire par `Atelier.donnees`. Les matières de la DA (étape 4) et le stade par ses ancres viendront à la reconstruction du paquet.

**Reprise de Minuit 0.10.0** (22 octobre 2026, socle 1.16) : `pnj_monde.json` part en `.gz` (206 Ko) et le paquet tombe à **14,7 Mo**, sans plus rien à alléger côté règles. Au budget, la scène du casino passe de 16 498 à 7 701 nœuds (les collisions d'une zone partagent un seul corps), de 256 à 36 scripts actifs, de 255,7 à 199,7 Mo de textures (textures du décor bornées à 1024 px) et sous le seuil de triangles (580 567). Les 110 Mo de textures restants sont les tapis des tables du socle (un SubViewport par table) : les ramener sous 96 Mo est une décision du socle. Le Dôme hors match passe de 938 816 à 359 072 triangles (seuls les sièges occupés sont dessinés).

## Les étapes du chantier

Chacune est utile seule, et rien ne change dans la première salle.

| # | Étape | Où | Taille |
|---|---|---|---|
| 1 | Contrat du stade, champ `modele`, catalogue et premier stade de la bibliothèque (socle 1.13) | smarves, portail | **fait** |
| 2 | Contrat de la salle de basket (parquet, cube, président, bureau, panneau, parts, sortie, arrivée), `modele` du gymnase et première salle de la bibliothèque (socle 1.14) | smarves, portail | **fait** |
| 3 | Règles d'emballage : l'emballeur convertit les textures et dit ce qui pèse encore (données en clair, fichiers déjà dans le jeu), le portail le dit aussi ; `Atelier.donnees` lit les données compressées (socle 1.15) | smarves, portail | **fait** |
| 4 | Les matières : une brique de genre `matieres`, employée par nom (`Bibliotheque.matiere`), et la première, `matieres-de-minuit@1` (socle 1.17) | smarves, portail | **fait** |
| 5 | Proposer une brique : le dossier `bibliotheque/` des paquets et sa fiche, vérifiés par l'emballeur et signalés par le portail, puis intégrés à la main (`tools/integrer_brique.gd`). Pas de dépôt automatique. | smarves, portail | **fait** |
| 7 | Le budget par lieu (socle 1.16) : l'emballeur bâtit et mesure chaque lieu du paquet, range la mesure dans le paquet (`budget.json`), le portail la dit lieu par lieu ; les objets lointains simplifiés par le socle ([`docs/LENTEUR.md`](LENTEUR.md)) | smarves, portail | **fait** |
| 8 | Les décors : le premier, `facadier-du-poitou@1`, venu de Chauvigny 0.2.2 (MIT) ; la planche du façadier | smarves | **fait** |
| 9 | Les monuments de pierre de Chauvigny : `donjon-en-ruine@1`, `eglise-romane@1` et leurs primitives de pierre ; les vues d'un décor (`tools/capture_decor.gd`) | smarves | **fait** |
| 10 | Les intérieurs : genres `salle_jeu` et `etude`, leurs contrats d'ancres, `modele` de la salle de jeu et du notaire ; `bar-des-sports@1` et `etude-de-notaire@1`, venus de Cloué 1.6.2 (socle 1.22) | smarves, portail | **fait** |
| 6 | Les auteurs reconstruisent leurs paquets : pour Minuit, le bol de la Fortune par ses ancres, le Dôme une salle, les matières passent à la bibliothèque, les textures et les données se compressent | paquets | Minuit : fait, sauf le Dôme (0.10.5, 23 octobre 2026) ; L'Isle-Jourdain 0.2.3 dans les seuils |

Il ne reste que l'étape 6, par les auteurs. Le 23 octobre 2026, Minuit passe le stade de la Fortune par ses ancres (0.10.5, socle 1.20 : le bol pourra devenir une brique, `stade-fortune@1`, une fois qu'il ne connaîtra plus le stade) et L'Isle-Jourdain repasse sous les seuils (0.2.3, [`docs/LENTEUR.md`](LENTEUR.md)). Le format des paquets est arrêté avec l'étape 3 et le budget par lieu avec la 7 : Civaux, Minuit, L'Isle-Jourdain et Cloué sont repris une fois, avec le SDK à jour, et l'emballeur dit à chaque auteur ce que ses lieux ont à alléger.
