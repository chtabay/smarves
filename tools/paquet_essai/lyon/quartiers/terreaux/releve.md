# Les Terreaux — relevé du site

30 octobre 2026, fil « Bâtir les Terreaux (Lyon) ». Plan tiré par `tools/bourg_reel.py lyon` sur le cadre `80,20,480,420` (x de 80 à 480 m, z de 20 à 420 m dans le repère de Sathonay), réglages dans `bourg_reel.json`. Sources : OpenStreetMap (ODbL) et IGN BD TOPO, RGE ALTI (Licence Ouverte 2.0), tirés le 30 octobre 2026. Toutes les cotes ci-dessous sont en mètres, dans le repère de la ville (x est, z sud).

Une note sur l'outil : `bourg_reel.py` s'arrête quand le plus grand plan d'eau du cadre ne contient aucun point du relief (ici le bord de la Saône effleure le coin ouest du cadre). Le plan a été tiré avec une garde locale (copie de l'outil hors du dépôt, rien de modifié) ; à signaler au chef de chantier pour le socle.

## Ce que dit le plan

**362 bâtiments, 438 voies, 110 arbres, relief 81 × 81 points de 5 m, de 167 à 184 m.** Attention : `bourg.json` est en unités du jeu (2,4 m) et met son zéro à 167 m ; la ville met le sien à 162 m (la Saône). Le quartier ne lit pas ce relief : il prend `hauteur(x, z)` de la commune.

| Ce qui fait le lieu | Où (x, z) | Cotes relevées |
|---|---|---|
| La place des Terreaux | coins NO (199, 178), NE (297, 162), SE (304, 204), SO (211, 220), voies de bord comprises : de 157 à 232 en z | environ 105 × 65 m entre façades, **tournée de −8°** (son axe est-ouest monte vers le nord-est) ; sol à 169 m, soit y ≈ 7 |
| L'Hôtel de Ville | façade ouest sur la place en x ≈ 306, de z 150 à 211 ; le corps de bâtiment va jusqu'à x ≈ 434 (place de la Comédie) | façade de 60 m ; BD TOPO donne 27 m à la gouttière ; le beffroi n'est pas dans les données (environ 45 m, à vérifier) |
| Le palais Saint-Pierre (musée des Beaux-Arts) | emprise de x 208 à 316, z 221 à 313, façade nord sur la place | 108 × 92 m, 27 m ; le cloître (jardin) au cœur, environ 60 × 50 m |
| La fontaine Bartholdi | l'encoche du polygone de la place, centre (249, 180), côté nord | bassin d'environ 17 m ; depuis 1994 dans l'axe du palais Saint-Pierre |
| Le front nord (rue Sainte-Catherine derrière) | z 135 à 160, de x 200 à 300 | dix immeubles de 25 à 31 m (six ou sept niveaux), tuile et pierre |
| L'Opéra et la place de la Comédie | (449, 167) | au bord du cadre, derrière l'Hôtel de Ville |
| Place Louis-Pradel | (458, 115) | hors du disque du quartier, vers le Rhône |

**Les voies qui comptent**

- **Rue Terme** : de la place Sathonay (113, 42) à l'angle nord-ouest des Terreaux (145, 188), en passant le carrefour de la rue de la Martinière (131, 98 à 136, 122). Elle tourne légèrement et descend d'environ 5 m.
- **Rue Sainte-Catherine** : piétonne, 4 m, **parallèle au côté nord de la place, un îlot plus haut** (z ≈ 110 à 123, de x 136 à 308). Elle ne relie pas Sathonay aux Terreaux : elle part de la rue Terme vers l'est.
- **Rue Sainte-Marie-des-Terreaux** : nord-sud, de la place des Capucins (185, 52) par un escalier, jusqu'au coin nord-ouest de la place (194, 175).
- **Rue d'Algérie** : de la Saône à l'angle nord-ouest (194, 175).
- **Rue Constantine**, **rue Paul-Chenavard** : à l'ouest et au sud-ouest, vers Saint-Nizier.
- **Rue Joseph-Serlin** (au sud de l'Hôtel de Ville), **rue Puits-Gaillot** (au nord) : vers la place de la Comédie.
- **Rue Président-Édouard-Herriot** : à l'est du palais Saint-Pierre, vers le sud et les Cordeliers.

## Anomalies et écarts

1. **Le sas de VILLE.md ne suit pas le réel.** VILLE.md nomme « rue Sainte-Catherine, de l'angle sud-est de Sathonay à l'angle nord-ouest des Terreaux ». Dans le plan, le chemin réel est **la rue Terme** (rue Sergent-Blandan depuis l'angle sud-est de Sathonay, puis la rue Terme vers le sud) ; Sainte-Catherine en est une traverse vers l'est. **Recommandation** : le sas est la rue Terme entre le carrefour de la Martinière (z ≈ 120) et l'angle nord-ouest de la place (z ≈ 185), environ 70 m, resserrée à 8 m entre façades, qui descend et tourne légèrement ; Sainte-Catherine reste une rue du quartier, vue en passant. Question posée au chef de chantier.
2. **Le recouvrement avec Sathonay.** Le cadre de Sathonay (`lyon.gd`) va jusqu'à x = 380 et z = 280 : `lyon.gd` dessine aujourd'hui en volumes toute la moitié nord des Terreaux, la place comprise. Il faudra que `lyon.gd` s'arrête à la limite des deux quartiers (proposée : la rue de la Martinière et la rue Terme, z < 120 ou x < 135). Pour l'essai sur ma branche, ces bâtiments sont enfouis par une scène d'essai, sans toucher à `lyon.gd`.
3. **Le relief de la commune s'arrête à z = 280.** Le sud du palais Saint-Pierre et la rue Paul-Chenavard sortent du terrain de `lyon.gd` (la hauteur y est prolongée au bord). Le terrain est plat sur la Presqu'île (167 à 170 m) : sans effet visible pour la maquette, à élargir par le chef de chantier.
4. **Le beffroi de l'Hôtel de Ville** n'est pas dans la BD TOPO (le bâtiment est à 27 m partout). Hauteur reprise des sources (environ 45 m au sommet du dôme, à vérifier sur photo).
5. **Les 69 jets et les 14 piliers** de l'aménagement de 1994 ne sont pas dans OSM. Ils sont posés d'après la description (Wikipédia) en grille orthogonale.
6. **Les arbres** : OSM n'en met aucun sur la place, ce qui est juste (place minérale). Les 110 arbres sont sur la place Louis-Pradel, la place de la Comédie et dans le cloître ; les essences du cloître ne sont pas vérifiées sur photo (Wikimedia refuse nos requêtes ce soir) : à reprendre avant la passe d'équipements.
7. **Les photos** : aucune photo de référence n'a pu être téléchargée (Wikimedia répond 429). Le dossier `references/` est à remplir ; en attendant, les descriptions de Wikipédia (Place des Terreaux, Hôtel de Ville de Lyon, consultées le 30 octobre 2026) et la mémoire du lieu.

## Rapports d'échelle qui font le lieu

- La place fait 105 × 65 m pour des façades de 25 à 30 m : un rapport de 1 à 2,5 en largeur, d'où l'effet de grande salle fermée.
- L'Hôtel de Ville ferme tout le petit côté est (60 m) ; son beffroi dépasse les toits d'environ 15 m : c'est le repère vu depuis le haut de la rue Terme.
- La fontaine est petite devant la place (17 m sur 105) mais haute (les chevaux cabrés à 6 ou 7 m) : elle tient l'angle nord, devant le palais.
