# La bibliothèque commune

Demande de Guillaume du 22 octobre 2026 : une bibliothèque d'assets embarquée dans le jeu, que les villes emploient par référence au lieu d'embarquer leurs propres modèles, et qu'elles alimentent à leur tour. Pour un stade, « le club de foot doit être lié et rester dans le fonctionnement normal des clubs et être intégré au championnat ». Les paquets existants seront reconstruits par leurs auteurs avec les nouvelles règles.

L'état des lieux du 20 octobre est dans le dossier du projet (`bibliotheque-assets/avis.md`).

## Le principe

- **Le décor se partage, le fonctionnement reste au socle.** Un stade de la bibliothèque est un décor : tribunes, club-house, tableau, haies. Le club, son effectif, le championnat, le match, le mercato, la causerie, les obligations et les paris restent ceux du socle, identiques pour toutes les villes. Aucune brique n'emporte sa propre gestion.
- **Le lien entre les deux est un contrat d'ancres** (`scripts/socle/ancres.gd`). Le décor montre quelques nœuds nommés ; le socle y pose ce qui est à lui. Un décor n'a pas à hériter d'un script du socle : il lui suffit de tenir le contrat.
- **Une brique a un identifiant et une version** (`stade-de-campagne@1`). Une version publiée ne change plus. Une retouche se publie en `@2`, dans un dossier à côté, et les villes restées sur `@1` la gardent telle quelle.
- **La liberté créative reste entière.** Une ville peut tout faire elle-même ; elle gagne seulement du poids quand elle réutilise. Trois niveaux, du plus simple au plus libre :
  1. **Référence** : `"modele": "stade-de-campagne@1"`, avec son club, ses couleurs et son nom.
  2. **Maison** : `"modele": "res://communes/<id>/….tscn"`, son propre décor, sans héritage, qui tient le contrat. Le club s'y branche de la même façon.
  3. **Héritage** (socle 1.8, inchangé) : `"scene"`, un stade dont le script hérite de `scripts/village/stade.gd`, comme le stade de la Fortune de Minuit.

## Le catalogue

`bibliotheque/bibliotheque.json`, lu par `Bibliotheque` (`scripts/socle/bibliotheque.gd`), et recopié dans le portail (`src/lib/communes/bibliotheque.ts` dans Pyramides2) pour qu'il refuse une référence inconnue.

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

## Les règles des paquets reconstruits

Pour les auteurs qui reconstruiront leur paquet :

1. **Référencer plutôt qu'embarquer** : ce qui est à l'atelier ou dans la bibliothèque ne part pas dans le paquet.
2. **Textures du décor en WebP avec perte** (au-delà de 256 px), sans perte seulement pour ce qui est relu au pixel (pièces d'écran, atlas de texte).
3. **Données lourdes compressées** (au-delà de 100 Ko).
4. **Un stade, une salle** se branchent par leur contrat d'ancres (`modele`), et l'héritage (`scene`) reste pour ce que le contrat ne couvre pas encore.

Les règles 2 et 3 seront vérifiées par l'emballeur et le portail (étape 3 ci-dessous).

## Les étapes du chantier

Chacune est utile seule, et rien ne change dans la première salle.

| # | Étape | Où | Taille |
|---|---|---|---|
| 1 | Contrat du stade, champ `modele`, catalogue et premier stade de la bibliothèque (socle 1.13) | smarves, portail | **fait** |
| 2 | Contrat de la salle de basket (parquet, cube, bureau, parts, sortie, arrivée) et `modele` du gymnase. Le gymnase a déjà `scene` et `habillage` depuis le socle 1.12. | smarves, portail | 2 à 3 jours |
| 3 | Règles d'emballage : l'emballeur convertit et compresse, le portail signale ce qui existe déjà dans le jeu et les textures sans perte trop lourdes | smarves, portail | 2 à 3 jours |
| 4 | Les matières : une brique de genre `matieres` (les 19 matières de la DA de Minuit pour commencer), employée par nom | smarves | 2 jours |
| 5 | Proposer une brique depuis le portail : dépôt d'un décor seul, contrôles automatiques (poids, polygones, échelle, licence, aucun script hors du décor, ancres vérifiées par un essai du jeu), capture, validation de Guillaume d'un clic, puis la brique entre au jeu à la version suivante avec le crédit de son auteur | portail, smarves | 1,5 à 2 semaines |
| 6 | Les auteurs reconstruisent leurs paquets : pour Minuit, le bol de la Fortune devient `stade-fortune@1` par ses ancres, le Dôme une salle, les matières passent à la bibliothèque, les textures et les données se compressent | paquets | 2 à 4 jours pour Minuit |

En tout, quatre semaines environ, dont la moitié pour l'étape 5. Les étapes 2, 3 et 4 sont indépendantes et peuvent avancer ensemble.
