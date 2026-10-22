# Concevoir un lieu

Le contrat ([`COMMUNE.md`](COMMUNE.md)) dit ce que le jeu accepte d'une commune. Cette page dit ce qui donne envie d'y rester : la méthode qui a fait passer L'Isle-Jourdain d'une maquette correcte (0.1) à un bourg que l'on parcourt avec plaisir (0.2), et les leçons de Casino Minuit, de Cloué et de Civaux. Rien ici n'est vérifié par l'emballeur ni par le portail : c'est une méthode, pour un auteur comme pour un Claude ou une équipe d'agents. Validée par Guillaume le 22 octobre 2026, puis complétée le même soir après la relecture d'un nouvel auteur parti de zéro : le niveau montré, les questions à poser avant de commencer, la note complète en exemple, le réel, ce qu'on joue, l'outil de parcours, le travail avec Guillaume et le ton.

Elle vaut pour un village, un quartier, un intérieur ou une salle de la bibliothèque. Les échelles changent (un bourg resserré, une vallée, un complexe nocturne, une campagne ouverte), la méthode reste.

## Le critère : le lieu surprend

**Un lieu réussi surprend.** Le joueur y découvre quelque chose en tournant la caméra, en prenant une traverse ou en revenant sur ses pas. Casino Minuit est la référence de cette sensation, dedans comme dehors : une **submersion** de lieux, de détails et de situations, pas cinq maisons et un point de vue.

**« Rien ne bloque » n'est pas « réussi ».** Le piège de chaque chantier est de laisser glisser, revue après revue, le critère de réussite vers « tout fonctionne et aucun défaut ne bloque la livraison ». C'est nécessaire, jamais suffisant. Chaque revue rend donc **deux verdicts séparés** :

1. *Ça marche* : le paquet passe `tester_commune` et l'emballeur, le lieu tient dans le budget ([`LENTEUR.md`](LENTEUR.md)), les accès, les collisions et la caméra fonctionnent, le chargement est raisonnable.
2. *Ça surprend* : les trois scènes sont fortes, le chemin entre elles est habité, la vie raconte quelque chose (sections suivantes).

Le second verdict ne s'obtient pas en comptant des bâtiments ou des objets ; il se juge à l'impression d'ensemble, à hauteur de joueur. Les tests automatiques et les revues de captures ne remplacent pas un essai par un humain.

## Le niveau visé, montré

Les références se regardent avant d'écrire la note, dans le jeu et sur ces planches :

- **Casino Minuit** (`casino_minuit`), la référence de la submersion, dedans comme dehors : [`references/minuit.jpg`](references/minuit.jpg) (la fontaine, la réception, les machines, le pit, le jardin d'hiver, le sports bar, le bar, la galerie, le foyer).
- **L'Isle-Jourdain 0.2** (`isle_jourdain` 0.2.2), le premier lieu construit avec cette méthode, que Guillaume a trouvé « très beau » : [`references/isle-jourdain.jpg`](references/isle-jourdain.jpg), prise par `tools/parcours_commune.gd` (par rangée : l'arrivée dans le bourg, le belvédère sur le viaduc, la berge sous les arches, la minoterie ; en vue de dessus, à pied, en se retournant). Sa note complète est l'exemple de [`exemples/INTENTIONS-isle-jourdain.md`](exemples/INTENTIONS-isle-jourdain.md).
- **Cloué** (`cloue`) : son sports bar est le repère de qualité d'un intérieur remarquable.

Ces paquets sont au catalogue (https://pyramides2.vercel.app/api/communes, le champ `paquet` de chaque commune) : dans le jeu, le carnet (C), « La Vienne », les installe ; `tools/parcours_commune.gd -- <id> --pck=<paquet>` les parcourt dans le SDK. Leurs sources ne sont pas dans le SDK (Minuit pèse à lui seul 15 Mo).

**Availles-Limouzine n'est pas un exemple de niveau.** C'est l'exemple technique du plan réel (`bourg_reel.py`) : 919 maisons du même modèle sur leurs emprises, rien ne s'y joue. Il montre comment lire `bourg.json`, pas à quoi doit ressembler un lieu.

## Avant de commencer : ce que sait le porteur du projet

Guillaume connaît des lieux ce qu'aucune source ne donne (pour Châtellerault : l'industrie, les difficultés sociales, la place du stationnement dans le centre). Avant la note, lui poser une fois, en un seul message :

1. **Ce qu'il sait du lieu** : ce qu'il y a vu, ce qu'on y fait, ce qui le caractérise pour lui, ce qu'il ne faut pas manquer ou pas montrer.
2. **Les visuels** : a-t-il des photos, des cartes, des souvenirs précis ; en veut-il de notre part (planches, croquis générés) avant de valider ?
3. **Les inspirations** : un film, un lieu, un jeu, une ambiance ; une commune déjà publiée dont il faut s'approcher ou s'écarter.
4. **Ce qu'on y joue** : les structures attendues (section « Ce qu'une commune offre en jeu »).

Ses réponses vont en tête de la note. S'il ne répond pas, on part des sources et on le dit dans la note.

## Avant de construire : la note d'intentions

Une note, écrite avant le premier modèle, qui sert de référence à tous ceux qui construisent. Elle se garde à côté de la commune (`communes/<id>/INTENTIONS.md` : l'emballeur ne met aucun `.md` dans le paquet). Le kit en donne le modèle vide ([`tools/kit/INTENTIONS.md`](../tools/kit/INTENTIONS.md)) ; **l'exemple complet est celui de L'Isle-Jourdain** ([`exemples/INTENTIONS-isle-jourdain.md`](exemples/INTENTIONS-isle-jourdain.md)), avec son équipe et l'auto-critique de sa 0.1. C'est le niveau de détail attendu.

- **L'intention en une phrase.** « Une ville qui descend vers son île, sous un viaduc beaucoup plus grand qu'elle. »
- **L'atmosphère** : l'heure, la saison, la lumière, ce qui se passe aujourd'hui (une fête qu'on prépare, un marché, une veille de match). Une fiction de mise en scène suffit, présentée comme telle.
- **Ce que sait le porteur du projet** (section précédente).
- **Les ancrages réels** : les repères que l'on doit reconnaître (un ouvrage, une silhouette, un matériau), leurs dimensions réelles et leurs sources (inventaire Mérimée sur pop.culture.gouv.fr, Atlas des paysages de la Vienne, sites de la commune et du tourisme). La carte peut recomposer les distances pour servir le jeu, mais garde les rapports d'échelle qui font le lieu (le viaduc de 300 m sur 40 domine les maisons). Signaler les **homonymes** (L'Isle-Jourdain du Gers n'est pas celle de la Vienne) et suivre « Représenter le réel ».
- **Ce que l'on y joue** (section « Ce qu'une commune offre en jeu »).
- **Les trois scènes fortes** (section suivante), chacune avec son **détail majeur**, et **la continuité** entre elles.
- **La palette chiffrée en familles**, **le soleil** (direction, hauteur, couleur), **la rugosité des matières** et **les caméras de contrôle** (plus bas).
- **L'équipe et l'ordre de travail** (« La méthode de travail »).
- **Ce qui est hors du périmètre** : pas de nouveau revenu, pari ou système de jeu inventé dans un décor ; les jeux existants passent par les structures et les tables du socle ([`COMMUNE.md`](COMMUNE.md), « Les structures »).

## Trois scènes fortes

Trois moments que le joueur racontera. Pour chacun, la note dit **où** il se trouve, **ce qu'il découvre en arrivant**, **ce qui l'attire au loin**, **ce qui l'étonne à hauteur de personnage** et **le détail majeur** qui sera soigné de près.

L'exemple de L'Isle-Jourdain : une rue étroite qui révèle soudain la vallée et le viaduc ; la berge sous les arches, humide, où la pile au premier plan donne l'échelle ; l'île et son moulin, avec un intérieur aussi travaillé que le sports bar de Cloué.

**Le joueur voit à la fois une destination lointaine et le début du chemin qui y mène.** Une scène se juge avec la caméra du jeu (celle du kit, `orbit_camera.gd`, et la vue à hauteur d'yeux) : une belle vue aérienne ne valide rien. Le grand repère peut sortir du cadre à l'approche ; voir toute la carte en permanence détruit la découverte.

## La continuité : un tissu habité

Les trois scènes sont les sommets d'un tissu continu. **Leurs liaisons demandent le même travail de composition que les scènes elles-mêmes.**

- **De l'épaisseur bâtie.** Des fronts de rue mitoyens, des retraits, des toitures en second plan, des annexes, des ateliers, des cours derrière les façades. Un commerce, son arrière-boutique, une maison basse et une remise forment un même morceau de rue. On doit sentir que le bourg continue derrière ce que l'on voit ; une collection de maisons détachées dont on aperçoit toutes les limites ne fait pas un bourg.
- **Des découvertes successives.** Un porche révèle une cour, un passage descend vers un atelier, une terrasse apparaît derrière un mur, la vue sur l'eau arrive par fragments avant de s'élargir.
- **Des usages distincts et lisibles.** Devantures, réserves, livraisons, potagers, lieux de rencontre, chacun avec ses détails propres. Un linge au fond d'une cour, des outils près d'un potager ou un vélo sous un appentis disent l'usage d'un endroit. Ces objets se placent selon les accès, le terrain et l'ombre : une dispersion uniforme d'accessoires ne crée pas de continuité.
- **Des respirations voulues.** Un espace dégagé a un cadrage, une destination et une raison sensible (sentir la taille d'un ouvrage, s'ouvrir sur l'eau). Un grand vide n'est pas une respiration par défaut. Les contrastes font la force du lieu : un passage resserré rend l'ouverture qui suit plus forte.
- **Un retour qui montre autre chose.** Le chemin inverse découvre l'arrière d'un atelier, une fenêtre sur le moulin, un accès jusque-là masqué. Une petite cour soignée suffit ; pas besoin d'une énigme ou d'une récompense partout.

**Pas de quota.** Dupliquer des maisons en changeant leurs couleurs ne répond pas à l'objectif. On compose d'abord des ensembles de rue, de cour et de rive, puis on approfondit leurs modèles. Les percées et les passages se dessinent en même temps que les pleins, et la densité ne doit ni cacher un accès, ni coincer l'habitant, ni gêner la caméra.

## La palette chiffrée

Une table de quelques familles (pierre, enduits, toitures, menuiseries et métal, eau, végétation, touches de vie) avec deux ou trois couleurs hexadécimales chacune. Les valeurs finales s'ajustent au rendu ; leur rôle est d'**éviter les dérives entre ceux qui construisent**, surtout quand plusieurs agents travaillent en parallèle.

| Famille | Direction | Repères |
|---|---|---|
| Pierre des ouvrages | calcaire chaud peu saturé, creux plus sombres | `#B9AC8B`, `#D3C7A7`, joint `#716E60` |
| Toitures | tuile variée pour le bourg, ardoise bleutée pour le moulin | `#9B624A`, `#B77B56`, `#424D56` |
| Eau | vert profond, plus clair dans le peu profond | `#284D4C`, `#48736B`, reflet `#8FAEB4` |

(Extrait des sept familles de L'Isle-Jourdain, complètes dans l'exemple.) La note fixe aussi, chiffrés, **le réglage de lumière de départ** (soleil venant de l'ouest-sud-ouest à 24–30°, crème légèrement chaud ; ciel bleu grisé et ombres douces), **la rugosité des matières** (pierre vers 0,85, bois 0,65, métal peint 0,45) et **les caméras de contrôle** (une vue à hauteur d'yeux, une vue de suivi au cran du jeu ; le grand repère peut sortir du cadre à l'approche). Le kit règle son soleil par `SOLEIL` dans `commune.gd`. Éviter une teinte globale (tout orange, tout bleu) qui écrase les matières ; les ombres restent lisibles. Avant de fabriquer une matière, regarder celles de l'atelier et de la bibliothèque (`Atelier.matiere`, `Bibliotheque.matiere`, [`BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md)).

## Représenter le réel

Les communes sont réelles ; ce que le jeu y met est une fiction, et elle doit se lire comme telle.

- **Fiction présentée comme telle.** Une fête, une livraison, un personnage, une intrigue sont des inventions de mise en scène ; la note et la `description` ne les donnent pas pour des faits ni pour des événements annoncés.
- **Aucune généralisation sur les habitants.** Une difficulté sociale, un métier, une communauté peuvent nourrir des personnages et des intrigues inventés ; ils ne valent jamais constat sur les gens du lieu. Pas de moquerie d'un lieu ni de ses habitants : le ton du jeu ([`BIBLE.md`](BIBLE.md)) vise le jeu d'argent, pas eux.
- **Des noms vérifiés.** Rues, monuments, rivières et lieux-dits gardent leur nom réel, vérifié sur deux sources ; les commerces, les habitants et leurs histoires sont inventés, et aucun personnage ne ressemble à une personne réelle (la règle de Smarves, [`BIBLE.md`](BIBLE.md), « La géographie »).
- **Des entreprises réelles.** Une entreprise, une association ou un club qui existe (un spectacle de rapaces, un circuit, un club de football) n'est ni nommé ni représenté par sa marque, son logo ou ses personnes : on invente un équivalent plausible, sous un autre nom, et on ne lui prête rien de négatif. Un monument public ou un paysage se représentent librement.
- **Des photos datées.** Une photo ou une page consultée ne prouve pas l'état actuel d'un bâtiment ; la note dit leur date. Les sources et leurs licences vont dans `licence` et `sources` du manifeste.

## Ce qu'une commune offre en jeu

Le joueur vient dans une commune pour s'y promener **et pour y jouer**. Les communes publiées offrent presque toutes **un stade** (`terrain_foot`, un club dans le championnat de la Vienne), **une salle de jeu** (`salle_jeu`, avec son tenancier et ses tables) et **un commerce** (`commerce`), souvent un arrêt de car ; Minuit a aussi son gymnase. C'est l'attendu par défaut d'une commune publiée ; une maquette visitable sans jeu (comme L'Isle-Jourdain 0.2) le dit dans sa `description` et dans sa note, et dit quand ses lieux ouvriront.

Tout passe par les **structures du socle** ([`COMMUNE.md`](COMMUNE.md), « Les structures ») et la bibliothèque commune ([`BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md)) : le stade de campagne et la salle de quartier s'y prennent tout faits. Un lieu ne fabrique ni ses tables ni ses règles, n'invente ni revenu ni pari, et suit la règle des lieux du monde : on joue à l'intérieur, et les gains au jeu ouvrent les salles par seuils ([`BIBLE.md`](BIBLE.md), « Les lieux »). Les noms et les répliques des tenanciers suivent le ton et le vocabulaire de la bible.

## L'animation et la vie

Un lieu immobile reste une maquette. **L'animation dit ce qui se passe aujourd'hui dans ce lieu** : elle n'est pas une couche posée à la fin, elle se conçoit avec les scènes et se reprend à chaque passe. Le retour sur L'Isle-Jourdain 0.1 était net : des habitants présents, mais aucune situation collective perceptible.

### Les habitants

- **Une situation, pas des figurants qui bougent.** Choisir ce que le lieu fait aujourd'hui (préparer une fête, livrer le moulin, attendre le car) et en tirer les gestes : des chaises portées vers la berge, une guirlande en pose, une livraison déchargée. Les usages se répondent : les chaises ont une destination, une personne qui quitte le café rejoint une occupation identifiable.
- **Des routines situées.** Chaque trajet a un départ, une arrivée et une raison ; chaque arrêt se fait à un endroit qui a un sens (un comptoir, un établi, un banc tourné vers la vue), avec le geste qui va avec. `Atelier.personnage(rôle, graine)` habille un rôle ; le nœud joue `jouer("talk")`, `regarder(point)` et `suivre(route, départ, vitesse, pause, geste_à_l'arrêt)` ([`COMMUNE.md`](COMMUNE.md), « L'atelier du socle »). Les figurants (`Atelier.figurant`) bavardent, s'assoient ou se promènent.
- **De la variété maîtrisée.** Deux voisins ne font pas le même geste au même instant (le socle décale déjà leur départ), les tenues suivent la graine, la densité de monde varie selon les zones : foule au café, solitude sous les arches.
- **Ne rien promettre.** Un habitant qui semble attendre le joueur, un comptoir qui invite, un objet mis en valeur annoncent une interaction : s'il n'y en a pas, on les compose autrement.

### Les mécanismes

Roues, transmissions, machines, horloges, enseignes tournantes, portes, barrières : **leur mouvement suit leur fonction**. Une transmission entraîne ce qu'elle relie, les vitesses sont plausibles, une machine à l'arrêt se lit comme à l'arrêt. Une mécanique illustrative (trois gros rouages qui tournent seuls) appauvrit le lieu ; une minoterie suggère des niveaux, des conduits, des courroies, des réparations et des traces d'usage. Le son vient de la source.

### L'eau, le vent et la lumière

- **L'eau** coule dans le sens de la pente, se trouble au contact des berges et des piles, reflète de façon incomplète. Le shader `water` de l'atelier sert de base ; il doit rester lisible sur tous les rendus du jeu (ordinateur, web, téléphone).
- **Le vent** est un seul vent pour tout le lieu : feuillages, linge, drapeaux, fumées de cheminée vont dans la même direction, avec des amplitudes faibles.
- **Les enseignes et les fenêtres** (néons, vitrines, `window_glow`) s'allument et clignotent avec un rythme ; un clignotement rapide et permanent fatigue. Quelques lampes chaudes annoncent le soir sans transformer le lieu en décor nocturne.

### Le son

Une ambiance par zone, des sources que l'on peut situer (l'atelier qu'on entend avant de le voir, l'eau sous les arches), des transitions douces entre zones, pas de grondement continu qui couvre tout. Un son bouclé fabriqué en mémoire suit la précaution du contrat ([`COMMUNE.md`](COMMUNE.md), « Le paquet »).

### Ce que coûte l'animation

Tout ce qui bouge se paie à chaque image, et le téléphone le sent d'abord. Le budget par lieu compte les scripts actifs (250 au plus, [`LENTEUR.md`](LENTEUR.md)).

- Préférer un shader (feuillage, eau, drapeau) ou un `AnimationPlayer` à un `_process` en GDScript.
- Un objet immobile ne tourne pas à chaque image : les personnages du socle s'arrêtent d'eux-mêmes hors de leur circuit. Ce qui est loin ou hors du champ peut s'arrêter (`VisibleOnScreenNotifier3D`).
- Ce qui s'anime reste hors des maillages fusionnés et des multimaillages : une fusion fige ce qu'elle avale. Les imposteurs du socle (les arbres au-delà de 120 m, dessinés par une image d'eux-mêmes) laissent de côté ce qu'un script anime.
- Ce qui se calcule au chargement (relief, grilles, placements) se garde sur l'appareil après la première fois plutôt que d'être refait à chaque arrivée (le relief de L'Isle-Jourdain, 8,6 s puis 2,5 s, paquet 0.2.2).

### Regarder la vie

À chaque scène forte, **regarder une minute sans bouger, puis écouter**. Repérer les boucles trop courtes, les gestes synchrones, ceux qui marchent sans but, ceux qui traversent un mur ou une table, les mécanismes sans cause, les sons sans source. Puis se demander : comprend-on ce qui se passe ici aujourd'hui ?

## La méthode de travail

**Trois rôles suffisent le plus souvent** : la direction (la note d'intentions, les arbitrages, la cohérence), la construction (découpée par zones quand le lieu est grand, chacune dans ses propres fichiers) et la critique indépendante. Ce sont les reprises qui font la qualité, plus que le nombre d'agents. Un grand lieu peut répartir la construction entre spécialistes (relief et parcours, ouvrages, bâti, intérieur remarquable, eau et paysage, vie et son), mais la direction garde le plan commun.

1. **Direction et maquette traversable.** La note d'intentions, puis le relief, les parcours, les accès et les points de vue, éprouvés avec l'habitant et la caméra du jeu avant toute production détaillée. Ce qu'offre déjà le socle (atelier, bibliothèque, structures, `bourg_reel`) se repère à ce moment.
2. **Construction.** Chaque zone part du plan commun : une convention d'échelle et d'origine, les points de raccord avec les zones voisines, les ressources partagées et une part du budget. Les raccords et les vues se vérifient régulièrement avec la caméra du jeu.
3. **Approfondissement, au moins deux passes.** Reprendre ce qui est générique, les raccords pauvres, les détails visibles de près ; installer la vie et le son dans des espaces déjà traversables ; étendre la qualité des trois scènes aux liaisons. Chaque passe se termine par le second verdict (« ça surprend ? »), pas seulement le premier.
4. **Critique indépendante, puis finition.** La finition ne vient qu'après les reprises de fond sur les volumes, les matières, les parcours et la vie.

## Juger à hauteur de joueur

[`tools/parcours_commune.gd`](../tools/parcours_commune.gd) parcourt n'importe quelle commune, en source ou en paquet, comme le ferait un joueur. La scène porte un `Marker3D` par point de vue, nommé `Vue1_…`, `Vue2_…` dans l'ordre de la promenade (le kit en pose trois, un par scène forte), son -Z tourné vers ce qu'on doit voir. L'outil y pose l'habitant, vérifie qu'il tient au sol, le fait marcher de chaque repère au suivant, et photographie chacun trois fois : en vue de dessus au cran du jeu, à pied à hauteur d'yeux, à pied en se retournant. Il range les images et un rapport (temps de chargement, poses, marches, blocages avec leur position et leur capture) dans `user://parcours/<id>/`.

```sh
godot --path . -s tools/parcours_commune.gd -- <id>                         # avec le rendu : captures et marches
godot --headless --path . -s tools/parcours_commune.gd -- <id>              # les marches seulement
godot --path . -s tools/parcours_commune.gd -- <id> --pck=build/<id>.pck    # le paquet tel que le joueur le reçoit
godot --path . -s tools/parcours_commune.gd -- cloue --pck=cloue.pck --point=x,y,z,lacet   # un endroit précis
```

Deux repères qui se suivent doivent se rejoindre à pied presque en ligne droite : pour un détour (un escalier, une porte, un pont), posez un repère au coude. Une marche bloquée signale un mur, une marche trop haute ou un accès manquant. Les captures servent au second verdict (« ça surprend ? ») et à la critique indépendante ; elles ne remplacent pas un essai par un humain.

## La critique indépendante

Un regard qui n'a pas construit le lieu, avec **un brief de joueur** : où il arrive et ce qu'on lui promet, sans explication de développement. Il parcourt avec `tools/parcours_commune.gd` puis à la main, prend ses captures à hauteur de joueur et juge à trois échelles : la silhouette dans le paysage, la composition d'un parcours, le détail à côté du personnage.

Il relève les répétitions, les ruptures d'échelle, les accès manquants, les zones faibles entre les scènes, les promesses d'interaction non tenues, la vie qui ne raconte rien. Il rend ses deux verdicts séparément, et dit ce qu'il n'a pas pu éprouver (fluidité sur téléphone, confort tactile, sons à l'écoute).

## Travailler avec Guillaume

Guillaume porte le projet. Il donne la direction et juge le résultat ; entre les deux, l'auteur a carte blanche.

1. **Les questions d'abord** (« Avant de commencer »), en un seul message.
2. **La note d'intentions et l'équipe, validées avant tout lancement.** On lui présente la note (au moins l'intention, les trois scènes, les ancrages, ce qu'on y joue) et l'équipe proposée avec son ordre de travail, puis on attend son accord. Aucun agent de production n'est lancé avant.
3. **Puis carte blanche.** Une fois validées, on construit sans redemander : les choix de composition, de noms de lieux et de personnages sont ceux de l'auteur. On ne revient vers lui que pour un choix qui change l'intention.
4. **La livraison** comprend toujours : le paquet (`build/<id>.pck`, emballé et passé par `test_commune` et `parcours_commune`), un mode d'emploi court (installer le paquet, la promenade conseillée, ce qui est nouveau), les sources (le dossier de la commune, la note d'intentions, les sources réelles et leurs dates) et des captures prises dans le jeu à hauteur de joueur. Le message dit, à part, ce qui reste à éprouver par un humain (fluidité sur sa machine et son téléphone, sons à l'écoute, confort tactile).
5. **L'auto-critique, quand il la demande** : franche, par rapport à l'objectif de départ et pas au seul « rien ne bloque » ; ce qui marche, les écarts importants, l'erreur de pilotage s'il y en a une, et ce qu'on reprendrait d'abord. L'exemple est celui de L'Isle-Jourdain 0.1 ([`exemples/INTENTIONS-isle-jourdain.md`](exemples/INTENTIONS-isle-jourdain.md), à la fin).
6. **La version précédente est conservée** : chaque livraison garde la précédente (son paquet et ses sources), et chaque dépôt sur le portail porte une version plus haute.

## Le ton du jeu

Les noms, les répliques des tenanciers, les enseignes et la `description` suivent la bible du monde, commune à toutes les communes : le ton (coloré et décalé, au premier degré, pour des adultes, jamais de morale), l'époque (un présent qui a gardé ses années 1980, sans portable ni internet), la règle des lieux et des seuils, l'économie en crédits et le vocabulaire. Dans le SDK, [`BIBLE.md`](BIBLE.md) en est l'extrait commun ; ce qui est propre à Smarves (ses lieux, ses personnages, son récit) n'y est pas, et chaque commune invente le sien dans sa propre géographie.

## Les pièges déjà rencontrés

- **Le critère qui glisse** vers « rien ne bloque » (L'Isle-Jourdain 0.1).
- **La maquette** : une rivière en canal rectiligne, des coteaux lissés, des chemins trop propres. Il manque les rapports naturels entre eau, rochers, végétation, soutènements et bâtiments.
- **Le vocabulaire habituel** : les mêmes encadrements, enduits et fenêtres partout. L'histoire d'un quartier construit et transformé ne se lit pas ; une façade de huit mètres n'a pas besoin de dix fenêtres identiques.
- **La vie en couche d'animation** : des habitants présents, aucune situation.
- **Deux surfaces à la même hauteur** (un tablier de pont et son sol) : elles clignotent. Décaler ou supprimer l'une des deux.
- **Une fusion de maillages** qui fait disparaître des éléments (des piles de pont) : vérifier après chaque fusion, de près et de loin.
- **Une marche infranchissable** : l'habitant enjambe seul les petites marches (`step_height`, `scripts/fp_player.gd`) ; au-delà, une rampe ou un vrai escalier.
- **Un calcul refait à chaque chargement** : le garder sur l'appareil.
