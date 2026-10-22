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

`bibliotheque/bibliotheque.json`, lu par `Bibliotheque` (`scripts/socle/bibliotheque.gd`), et recopié dans le portail (`STADES_DE_LA_BIBLIOTHEQUE` et `SALLES_DE_LA_BIBLIOTHEQUE`, `src/lib/communes/structures.ts` dans Pyramides2) pour qu’il refuse une référence inconnue : ajouter une brique au jeu, c’est aussi l’ajouter là.

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

- `genre` (`stade`, `salle` ou `decor`), `nom`, `auteur`, `licence` et `scene` sont requis ; `description` et `apercu` facultatifs. `scene` et `apercu` sont des fichiers du dossier de la brique.
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

## Les étapes du chantier

Chacune est utile seule, et rien ne change dans la première salle.

| # | Étape | Où | Taille |
|---|---|---|---|
| 1 | Contrat du stade, champ `modele`, catalogue et premier stade de la bibliothèque (socle 1.13) | smarves, portail | **fait** |
| 2 | Contrat de la salle de basket (parquet, cube, président, bureau, panneau, parts, sortie, arrivée), `modele` du gymnase et première salle de la bibliothèque (socle 1.14) | smarves, portail | **fait** |
| 3 | Règles d'emballage : l'emballeur convertit les textures et dit ce qui pèse encore (données en clair, fichiers déjà dans le jeu), le portail le dit aussi ; `Atelier.donnees` lit les données compressées (socle 1.15) | smarves, portail | **fait** |
| 4 | Les matières : une brique de genre `matieres` (les 19 matières de la DA de Minuit pour commencer), employée par nom | smarves | 2 jours |
| 5 | Proposer une brique : le dossier `bibliotheque/` des paquets et sa fiche, vérifiés par l'emballeur et signalés par le portail, puis intégrés à la main (`tools/integrer_brique.gd`). Pas de dépôt automatique. | smarves, portail | **fait** |
| 6 | Les auteurs reconstruisent leurs paquets : pour Minuit, le bol de la Fortune devient `stade-fortune@1` par ses ancres, le Dôme une salle, les matières passent à la bibliothèque, les textures et les données se compressent | paquets | 2 à 4 jours pour Minuit |

Il reste l'étape 4 (environ deux jours) et la 6 par les auteurs. Le format des paquets est arrêté avec l'étape 3 : le budget par lieu, vérifié par le portail, s'appuie sur lui, et Civaux, Minuit, L'Isle-Jourdain et Cloué ne seront repris qu'une fois, après ce budget.
