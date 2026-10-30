# Lyon, Saint-Paul et le Change — note d'intentions

30 octobre 2026. Quartier n° 3 du pilote de Lyon en quartiers (`cartes/lyon/VILLE.md`), direction : Claude (fil « Bâtir Saint-Paul et le Change »), chef de chantier : le fil « Cadrer les grandes villes en quartiers ». Une composition inspirée du Vieux-Lyon nord, fidèle à sa disposition réelle, pas une visite patrimoniale. Le quartier se pose sous la commune `lyon` par `saint_paul.gd` et ne touche ni à `lyon.gd`, ni à `commune.json`.

## Ce que le porteur du projet sait du lieu

Les quatre questions ne sont pas reposées : les réponses de Guillaume pour Sathonay valent pour toute la ville (VILLE.md, section 7). Pour ce quartier, elles se lisent ainsi :

1. **Ce qui fait le lieu** : à Sathonay, Guillaume a désigné les monuments, les cafés et les terrasses, et retiré ce qui ne servait pas (les boulistes). Ici, les monuments qui se reconnaissent sont l'église Saint-Paul et sa tour-lanterne, la gare et son horloge, la galerie de Philibert Delorme, la Loge du Change.
2. **La référence** : pas de planche de Guillaume pour ce quartier. La cible est la bible visuelle de la ville (VILLE.md, section 2) et le niveau atteint à Sathonay ; la planche cible du quartier est faite de captures de la maquette et du relevé.
3. **L'ambiance** : la fin d'après-midi de septembre de toute la ville, le soleil de `lyon.gd`.
4. **Ce qu'on y joue** : pas d'intérieur pour le moment. Les portes qui pourraient s'ouvrir (la Loge, le comptoir de la banque, le café de courses) sont fermées et se liront comme des seuils à venir.

## L'intention

**La ville Renaissance au pied de la colline, où le soir tombe par le haut.** On passe la Saône sur la passerelle et l'on entre dans une ville plus ancienne, plus basse, plus serrée que la Presqu'île : une église romane dont la lanterne octogonale domine les toits, la gare et son horloge au pied de la colline verte, puis la rue Juiverie, si étroite que le pavé est déjà dans l'ombre quand le haut des façades flambe encore, et qui débouche sur la place du Change, une salle dorée où sort une noce.

**L'atmosphère** : le même soleil que Sathonay (azimut 258°, 31°, `#FFE1B0`). Ici, il vient de derrière la colline et des toits : il prend les façades tournées vers l'ouest à partir du deuxième étage et laisse les rues dans une ombre chaude. **Ce partage, le haut doré et le bas dans l'ombre, est le parti pris principal du quartier** ; il se compose par l'orientation des vues, toutes prises dos ou de flanc au soleil.

## Les partis pris

| | Ce que l'on fait | Pourquoi |
|---|---|---|
| **On exagère** | **l'étroitesse.** La rue Juiverie garde ses 5 à 7 m entre façades, mais les façades montent à quatre ou cinq niveaux sans retrait ; la rue Lainerie et la rue de la Loge aussi. Le ciel ne fait qu'une fente (3 à 6 % de l'image). | C'est l'inverse de Sathonay, la place plate et ouverte : le joueur doit sentir qu'il a changé de ville en passant l'eau. |
| **On exagère** | **les trois silhouettes** : la tour-lanterne de Saint-Paul (un étage d'arcatures de plus pour qu'elle dépasse franchement les toits depuis la passerelle), l'horloge de la gare (un cadran de 2,5 m, lisible de la place), la colonnade de la Loge du Change. | Chacun des trois est le repère d'une scène et doit se lire au premier regard. |
| **On exagère** | **la couleur des enduits** : les ocres rouges et roses de la Renaissance (`#C98A62`, `#D4A074`, `#B9705A`), plus saturés que la réalité, contre la pierre grise des encadrements (`#A9A294`). | À l'ombre, une façade pâle devient grise ; un ocre rouge reste chaud. |
| **On simplifie** | **les façades** en trois familles : la maison gothique étroite (deux travées, fenêtres à accolade, rez-de-chaussée de boutique en arc), l'hôtel Renaissance (croisées à meneaux, cordons de pierre, porche sur cour), l'immeuble classique du quai (façade plate, fenêtres hautes, toit bas). Une seule cour ouverte, celle de l'hôtel Bullioud. | La rue se lit par une grammaire tenue, pas par une variété au hasard ; et une seule cour ouverte vaut mieux que dix porches entrouverts sur du vide. |
| **On simplifie** | **la colline** : un versant vert et raide, des murs de soutènement, quelques toits de couvents ; les lycées et le gymnase sont des volumes calmes. | Elle sert de fond et ferme l'ouest ; Fourvière est un autre quartier. |
| **On omet** | les voies et le faisceau de la gare (cachés derrière elle), les voitures, les enseignes réelles (pubs et restaurants du relevé), le mobilier d'aujourd'hui, le funiculaire désaffecté. | L'époque du jeu et la règle des marques (CONCEPTION, « Représenter le réel »). |

**La densité de vie** suit la règle de la ville : du monde sur les deux places (les voyageurs du soir devant la gare, la noce et les terrasses au Change), la rue Juiverie presque vide (une habitante à sa fenêtre, un livreur, un chat sur une marche).

## Ancrages réels

Vérifiés sur deux sources (OpenStreetMap et Mérimée par l'OSM, Wikipédia, Ville de Lyon, consultés le 30 octobre 2026 ; ils ne prouvent pas l'état actuel) :

- **L'église Saint-Paul** : collégiale fondée au VIe siècle, reconstruite aux XIIe et XIIIe ; tour-lanterne octogonale romane sur la croisée, clocher à flèche gothique du XIXe ; horloge de 1676. Emprise 54 × 34 m, au nord de la place. [Ville de Lyon](https://www.lyon.fr/node/28569), OSM way 60798750.
- **La gare Saint-Paul** (1876) : une façade de pierre à deux niveaux sur la place, l'horloge au fronton, la colline juste derrière. OSM way 40702874.
- **La rue Juiverie** : rue du quartier juif médiéval puis des hôtels des banquiers et marchands florentins de la Renaissance ; au n° 8, l'**hôtel Bullioud** et sa **galerie de Philibert Delorme** (1536), une galerie à deux arcades portée par deux trompes au-dessus de la cour ; plus bas, la maison aux Lions. OSM way 125783464 (MH), [Vieux Lyon, Wikipédia](https://en.wikipedia.org/wiki/Vieux_Lyon).
- **La Loge du Change** : loge des changeurs des foires, bâtie de 1631 à 1653 (Simon Gourdet), reprise par Soufflot de 1748 à 1750 ; cinq arcades au rez-de-chaussée, un étage néoclassique, deux horloges ; temple protestant depuis 1803. Elle regarde l'est, sur la place. [Temple du Change, Wikipédia](https://en.wikipedia.org/wiki/Temple_du_Change), OSM way 125782865.
- **Le relief** : la Saône à 162 m, le quai à 165-168, la place Saint-Paul à 173, la rue Juiverie de 174 à 171, la place du Change à 168, le versant de la colline à 230 m à 250 m de là (RGE ALTI).
- **Les matières** : pierre grise et dure (Villebois, Couzon) des encadrements, enduits ocres rouges et roses, tuile canal à faible pente sur génoise, galeries et tours d'escalier dans les cours.

**Homonymes** : la place Saint-Paul et l'église Saint-Paul existent dans d'autres villes ; la Loge du Change n'est pas la Bourse (palais de la Bourse, Presqu'île).

## Le fil rouge

Le Change est le lieu de l'argent de Lyon depuis les foires de la Renaissance : le quartier le dit par des traces, une par scène, **jamais dans la rue Juiverie** (relevé, anomalie n° 4).

- **Place Saint-Paul** : le café de courses en face de la gare (« Le Départ », nom inventé), l'ardoise des cotes sous le store, des tickets froissés au pied de la terrasse, un voyageur qui court vers la gare un journal de turf à la main.
- **Rue Juiverie** : aucune trace d'argent ; une affiche de la loterie des foires sur un mur, comme on en voit partout, et rien d'autre.
- **Place du Change** : le comptoir de la Caisse de la Grande-Côte (la banque de la commune), porte close, plaque de cuivre ; à côté, la vitrine d'un prêteur sur gages (une montre, une alliance, des clés de voiture, un saxophone) ; une boutique « fermée pour cause de saisie » dont l'enseigne a été repeinte au nom du créancier.

## Ce que l'on y joue

Rien pour le moment : un décor où l'on se promène, comme Sathonay. La Loge, le comptoir de la banque et le café de courses sont des portes closes, prêtes à devenir des seuils.

## Trois scènes fortes

### 1 Le pied de la passerelle

**Lieu** : le débouché sud de la passerelle Saint-Vincent, sur le quai, puis la rue Saint-Nicolas vers la place Saint-Paul. Repère `Vue1_Passerelle` en (-200, 238), tourné vers le sud-sud-ouest (lacet 190°). C'est aussi le sas vers Sathonay.

On descend les marches de la passerelle : devant, une rue courte et étroite file vers le sud, ses façades de gauche dorées par le soleil de flanc ; au-dessus des toits à droite, la tour-lanterne de Saint-Paul et sa flèche ; au fond, la tache claire de la place Saint-Paul et le cadran de l'horloge. **Ce qui attire au loin** : la flèche et l'horloge. **Ce qui étonne de près** : le chevet roman de l'église, ses arcatures de pierre jaune et grise, presque contre la rue.

**Détail majeur** : la tour-lanterne octogonale (deux étages d'arcatures, colonnettes, toit bas) et la flèche.

### 2 La rue Juiverie

**Lieu** : de la place Saint-Paul à la rue de la Loge, 140 m. Repère `Vue2_Juiverie` en (-226, 385), tourné vers le sud (lacet 180°).

La place s'est refermée : une fente de ciel, les façades à croisées de pierre qui montent, le haut de celles de gauche doré, le pavé dans l'ombre chaude. À droite, un porche ouvert sur une cour : au fond, la galerie de Philibert Delorme, suspendue sur ses trompes, avec un trait de soleil sur sa corniche. La rue tourne à peine et descend : on ne voit pas son bout. **Ce qui attire au loin** : la lumière au bout de la rue, où elle débouche. **Ce qui étonne de près** : la cour et sa galerie, que l'on découvre en tournant la tête.

**Détail majeur** : le porche, la cour et la galerie à deux trompes (arcades, pilastres, corniche, la tour d'escalier à côté).

### 3 La place du Change

**Lieu** : la sortie de la rue de la Loge sur la place. Repère `Vue3_Change` en (-163, 514), tourné vers le sud-sud-est (lacet 165°).

La rue s'ouvre sur une petite place en pente douce, une salle dorée : les façades de l'est en plein soleil, les terrasses, et à droite la Loge du Change, ses cinq arcades et ses colonnes dans l'ombre fraîche, d'où sort une noce. Au fond, la rue Saint-Jean file vers le sud, droite et étroite, et l'on devine au bout la cathédrale (le quartier suivant). **Ce qui attire au loin** : la rue Saint-Jean. **Ce qui étonne de près** : la noce sur les marches, le riz par terre, le photographe.

**Détail majeur** : la façade de la Loge (cinq arcades, ordre de colonnes à l'étage, deux cadrans, balustrade).

## La continuité entre les scènes

- **De la passerelle à la place Saint-Paul : l'église que l'on longe.** La rue Saint-Nicolas puis la rue du Docteur-Augros, le chevet et le flanc de l'église, une boulangerie, un atelier de reliure, les fenêtres à géraniums ; la place s'ouvre avec la gare de face.
- **La place Saint-Paul : un parvis de gare.** La façade et l'horloge, le café de courses et sa terrasse, les voyageurs, la station de taxis (`Arrivee_SaintPaul`).
- **De la place au Change : la ruelle.** La rue Juiverie, puis la rue de la Loge qui tourne à gauche et descend vers la place du Change ; au carrefour, la montée du Change grimpe à droite vers la colline (fermée au-delà de la première volée).
- **Le retour : par la rue Lainerie et le quai.** Une autre rue étroite, parallèle, avec ses maisons gothiques, puis le quai de Bondy, la Saône et la Presqu'île en face dans le soleil, jusqu'à la passerelle.

## La vie

La situation du jour : **le train du soir et une noce**. Devant la gare, des voyageurs sortent avec leurs valises, un employé ferme la grille de la consigne, un couple attend sous l'horloge. Au Change, la noce sort de la Loge : le couple sur les marches, des invités qui lancent du riz, un photographe accroupi, des enfants qui courent ; les terrasses regardent. Rue Juiverie, presque personne. Pas de groupe au milieu d'une chaussée.

## Palette et matières

La bible de la ville (VILLE.md, section 2), avec la famille du Vieux-Lyon en premier plan :

| Famille | Direction | Repères |
|---|---|---|
| Enduits du Vieux-Lyon | ocres rouges et roses, terre ; plus pâles au quai | `#C98A62`, `#D4A074`, `#B9705A`, quai `#D8B08A`, `#CDB08E` |
| Pierre des encadrements et des monuments | grise et dure aux croisées, dorée à l'église et à la Loge | `#A9A294`, `#C7C3B6`, dorée `#C9A66B`, joint `#7A6E5A` |
| Toitures | tuile canal rouge orangé, pentes faibles | `#C4502C`, `#B0452A`, `#C85A33` |
| Menuiseries et fer | portes de bois brun, volets brun rouge et gris vert, ferronneries noires | `#5E4B3C`, `#6E2E27`, `#7D8C7A`, `#2A2A28` |
| Sols | pavé à joints sombres dans les rues, dalle claire sur les places | `#A39B93`, `#B3A998` |
| Eau, végétation | celles de la ville | Saône `#3D5B57`, verts `#7DB83A`, `#3F6A2E` |
| Vie | la noce en blanc et crème, les stores du café vert et crème | `#F4F0E6`, `#2F5A3A`, `#B8352E` |

**Rugosité** comme Sathonay : pierre 0,85, enduit 0,9, tuile 0,8, bois 0,65, fer 0,45.

## Lumière et caméras

Le soleil, le ciel et l'environnement sont ceux de la commune. **Les vues se prennent le soleil dans le dos ou de flanc** : la passerelle vers le sud-sud-ouest, la rue Juiverie vers le sud, le Change vers le sud-sud-est ; jamais vers l'ouest à hauteur d'œil (le contre-jour de la colline). Caméras de contrôle : à hauteur d'yeux (1,65 m, champ de 65°) aux trois repères ; la vue d'ensemble depuis le nord-est, au-dessus de la Saône : `--libre` à (-60, 90, 200) en mètres, regard vers le sud-ouest, tangage -35°. Les vues des sas : depuis le pied de la passerelle vers Sathonay (nord-est), et depuis la place du Change vers la rue Saint-Jean.

## L'inventaire (besoin → brique)

| Besoin | Brique et options | Ou demande |
|---|---|---|
| Façades ordinaires des rues | `facadier-lyonnais@1` : `immeuble`, `etroite`, `classique`, `traboule` ; `enduit` en hexa (Vieux-Lyon), `niveaux` 3 à 4, `rdc` `boutique` ou `pierre`, `persiennes` faux, `pente` 22, `tuile` | **Demande** : une façade Renaissance du Vieux-Lyon (croisées et demi-croisées à meneaux de pierre, fenêtres à accolade, cordons, porte en arc surbaissé, encorbellement), en option `style: "renaissance"` du façadier lyonnais ; en attendant, le façadier tel quel, persiennes ôtées, encadrements gris. |
| Café de courses, boutiques | `facadier-lyonnais@1` `cafe` (`enseigne`, `toile`), `rdc: boutique` | |
| Le reste des bâtiments | volumes au shader des murs de la commune (`_materiau_murs`, `_materiau_toits` de `lyon.gd`) | exposition demandée (VILLE, section 6) |
| Église Saint-Paul, gare, Loge du Change, galerie Delorme | dans le paquet du quartier (monuments uniques) | |
| Arbres du quai et de la place Gerson | `arbres-d-ombriere@1` `jeune_platane`, `platane` | |
| Terrasses, bancs, réverbères, bornes | `mobilier-lyonnais@1` `terrasse`, `banc`, `lampadaire` (éteint), `borne`, `colonne` | |
| Mur de quai, parapet | `quais-lyonnais@1` `mur_quai_bas`, `mur_quai_haut` | |
| Noce, voyageurs, passants | `Atelier.personnage`, `Atelier.figurant` du socle | |

## Hors du périmètre

Pas d'intérieur, de jeu, de revenu ni de pari. Rien ne change dans la première salle de Smarves, ni dans `lyon.gd`, ni dans `commune.json`. Saint-Jean, Fourvière et la Presqu'île sont d'autres quartiers : on les voit au loin, on ne les bâtit pas.

## L'équipe et l'ordre de travail

Ce fil est le game designer et met les casquettes l'une après l'autre ; le juge est le fil « Juger les cartes face aux planches cibles ».

1. Relevé (`releve.md`), inventaire et cette note ; compte rendu au chef de chantier.
2. Maquette traversable (`saint_paul.gd`) : les volumes, les rues, les trois repères, les sas, les monuments en masses ; un banc d'essai qui pose le quartier sous la commune sur la branche du fil.
3. Les trois scènes, une à la fois : cadrage, masses, matières, détails, vie ; les captures dans `planches/`.
4. Le juge ; compte rendu au chef de chantier avec planches, verdicts et budget.
