# Saint-Paul et le Change : relevé du site

30 octobre 2026. Plan tiré par `tools/bourg_reel.py lyon --insee=69123 --centre=4.83025,45.76925 --cadre=-560,60,-60,600 --riviere="La Saône" --dossier=tools/paquet_essai/lyon/quartiers/saint_paul` (OpenStreetMap, BD TOPO et RGE ALTI de l'IGN, lus le 30 octobre 2026). Repère de la ville : origine au centre de la place Sathonay, x vers l'est, z vers le sud, en mètres. Plan annoté : `planches/0-releve.png`.

## Ce que donne le plan

385 bâtiments, 444 voies, 258 arbres, la Saône ; relief de 162 à 283 m (y = 0 à la Saône, comme Sathonay).

| Repère | Position (x, z) | Sol (m au-dessus de la Saône) | Source |
|---|---|---|---|
| Débouché sud de la passerelle Saint-Vincent | (-202, 226) | 2,8 | `lyon.gd`, OSM way 242802641 |
| Église Saint-Paul (tour-lanterne romane, flèche) | (-248, 284), emprise 54 × 34 m | 5,2 | OSM way 60798750, MH |
| Gare Saint-Paul (façade à l'horloge sur la place) | (-263, 359), emprise 40 × 39 m, 22 m | 10,7 | OSM way 40702874 |
| Place Saint-Paul | (-214, 361) | 10,7 | OSM way 1456111620 |
| Rue Juiverie (nord-sud, 5 à 7 m entre façades) | x ≈ -227, z 376 à 514 | 11,8 au nord, 9,4 au sud | OSM |
| Hôtel Bullioud, galerie de Philibert Delorme (1536) | (-250, 424), côté ouest de la rue | 10,8 | OSM way 125783464, MH |
| Maison aux Lions | (-216, 496) | 9,5 | OSM way 125783681, MH |
| Loge du Change (Soufflot, 1748-1750 ; temple protestant) | (-178, 531), emprise 25 × 22 m, 17 m | 6,0 | OSM way 125782865, MH |
| Place du Change | (-152, 526) | 5,8 | OSM |
| Rue Saint-Jean, départ vers le sud | x ≈ -155, z 538 à 600 | 6,2 | OSM |
| Montée du Change (escalier vers Fourvière) | de (-231, 513) à (-286, 513) | de 9 à 31 | OSM |
| La colline (Fourvière, versant est) | (-400, 450) | 68 | RGE ALTI |

## Ce qu'il faut savoir lire

- **La Saône tourne** : elle coule d'ouest en est au nord du quartier (quai Pierre-Scize), puis vers le sud le long du quai de Bondy (x ≈ -90). Le quartier tient l'angle intérieur de ce coude, adossé à la colline.
- **Le sud de la passerelle est déjà dans le cadre de Sathonay** (relief et bâtiments jusqu'à z = 280, quai Pierre-Scize tenu par `lyon.gd`). Les bâtiments entre la Saône et z = 280 (place Gerson, la moitié nord de l'église, coupée au bord du cadre) sont aujourd'hui des volumes de `lyon.gd`. **À régler par le chef de chantier** : que `lyon.gd` cesse de bâtir la rive sud (au sud de `RIVE_SUD`), et que Saint-Paul la reprenne. Dans ma maquette d'essai, ces volumes sont enfouis.
- **Le relief de `lyon.gd` s'arrête à z = 280** : au-delà, `hauteur()` rend le bord. En attendant le cadre élargi de la commune, le banc d'essai (hors livrable) lit le relief de mon `bourg.json`, qui sort des mêmes données et se raccorde.
- **Le faisceau de la gare** (les voies, le parking SNCF, x -380 à -280, z 280 à 340) est un grand vide derrière la gare : il ne se joue pas, la gare le cache.
- **Les grands bâtiments scolaires** de la colline (lycées, gymnase, x < -300) : volumes simples, hors parcours.
- **Les petits polygones** dans les cours de la rue Juiverie et de la rue Lainerie sont des appentis et des tours d'escalier en cour, pas des maisons sur rue : ils restent des volumes bas, sans façade.
- **Les arbres** : peu dans les rues (aucun dans la rue Juiverie, c'est juste), des platanes en rangée sur le quai de Bondy et la place Gerson, la végétation de la colline. Essence à vérifier sur photo pour la place Gerson (platanes probables).
- **Les commerces nommés d'OSM** (pubs, restaurants) sont réels : aucun n'est repris, les enseignes sont inventées.

## Anomalies et écarts

1. L'église est coupée en deux par le bord du cadre de Sathonay (z = 280) : à reprendre en un seul monument dans le quartier.
2. La rue Juiverie de l'OSM est une ligne ; sa largeur réelle (5 à 7 m) se lit entre les emprises : c'est elle qu'on suit.
3. L'altitude BD TOPO des toits de la gare (22 m) comprend la halle : la façade sur la place est plus basse (deux niveaux et l'attique de l'horloge, environ 14 m).
4. Le nom « Juiverie » vient du quartier juif médiéval : **aucune trace d'argent (prêteur, dettes, mont-de-piété) n'est posée dans cette rue**, pour ne pas rejouer un vieux cliché. Le fil rouge passe par la place Saint-Paul et la place du Change.
