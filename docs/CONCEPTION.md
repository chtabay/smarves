# Concevoir un lieu

Le contrat ([`COMMUNE.md`](COMMUNE.md)) dit ce que le jeu accepte d'une commune. Cette page dit ce qui donne envie d'y rester : la méthode qui a fait passer L'Isle-Jourdain d'une maquette correcte (0.1) à un bourg que l'on parcourt avec plaisir (0.2), et les leçons de Casino Minuit, de Cloué et de Civaux. Rien ici n'est vérifié par l'emballeur ni par le portail : c'est une méthode, pour un auteur comme pour un Claude ou une équipe d'agents. Validée par Guillaume le 22 octobre 2026.

Elle vaut pour un village, un quartier, un intérieur ou une salle de la bibliothèque. Les échelles changent (un bourg resserré, une vallée, un complexe nocturne, une campagne ouverte), la méthode reste.

## Le critère : le lieu surprend

**Un lieu réussi surprend.** Le joueur y découvre quelque chose en tournant la caméra, en prenant une traverse ou en revenant sur ses pas. Casino Minuit est la référence de cette sensation, dedans comme dehors : une **submersion** de lieux, de détails et de situations, pas cinq maisons et un point de vue.

**« Rien ne bloque » n'est pas « réussi ».** Le piège de chaque chantier est de laisser glisser, revue après revue, le critère de réussite vers « tout fonctionne et aucun défaut ne bloque la livraison ». C'est nécessaire, jamais suffisant. Chaque revue rend donc **deux verdicts séparés** :

1. *Ça marche* : le paquet passe `tester_commune` et l'emballeur, le lieu tient dans le budget ([`LENTEUR.md`](LENTEUR.md)), les accès, les collisions et la caméra fonctionnent, le chargement est raisonnable.
2. *Ça surprend* : les trois scènes sont fortes, le chemin entre elles est habité, la vie raconte quelque chose (sections suivantes).

Le second verdict ne s'obtient pas en comptant des bâtiments ou des objets ; il se juge à l'impression d'ensemble, à hauteur de joueur. Les tests automatiques et les revues de captures ne remplacent pas un essai par un humain.

## Avant de construire : la note d'intentions

Une page, écrite avant le premier modèle, qui sert de référence à tous ceux qui construisent. Elle se garde à côté de la commune (`communes/<id>/INTENTIONS.md` : l'emballeur ne met aucun `.md` dans le paquet).

- **L'intention en une phrase.** « Une ville qui descend vers son île, sous un viaduc beaucoup plus grand qu'elle. »
- **L'atmosphère** : l'heure, la saison, la lumière, ce qui se passe aujourd'hui (une fête qu'on prépare, un marché, une veille de match). Une fiction de mise en scène suffit, présentée comme telle.
- **Les ancrages réels** : les repères que l'on doit reconnaître (un ouvrage, une silhouette, un matériau), avec leurs sources. La carte peut recomposer les distances pour servir le jeu, mais garde les rapports d'échelle qui font le lieu (le viaduc domine les maisons).
- **Les trois scènes fortes** (section suivante) et **la continuité** entre elles.
- **La palette chiffrée** (plus bas).
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

(Extrait de la palette de L'Isle-Jourdain.) La note fixe aussi un réglage de lumière de départ : direction et hauteur du soleil, couleur du ciel et des ombres. Éviter une teinte globale (tout orange, tout bleu) qui écrase les matières ; les ombres restent lisibles. Avant de fabriquer une matière, regarder celles de l'atelier et de la bibliothèque (`Atelier.matiere`, `Bibliotheque.matiere`, [`BIBLIOTHEQUE.md`](BIBLIOTHEQUE.md)).

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

## La critique indépendante

Un regard qui n'a pas construit le lieu, avec **un brief de joueur** : où il arrive et ce qu'on lui promet, sans explication de développement. Il parcourt, prend ses captures à hauteur de joueur et juge à trois échelles : la silhouette dans le paysage, la composition d'un parcours, le détail à côté du personnage.

Il relève les répétitions, les ruptures d'échelle, les accès manquants, les zones faibles entre les scènes, les promesses d'interaction non tenues, la vie qui ne raconte rien. Il rend ses deux verdicts séparément, et dit ce qu'il n'a pas pu éprouver (fluidité sur téléphone, confort tactile, sons à l'écoute).

## Les pièges déjà rencontrés

- **Le critère qui glisse** vers « rien ne bloque » (L'Isle-Jourdain 0.1).
- **La maquette** : une rivière en canal rectiligne, des coteaux lissés, des chemins trop propres. Il manque les rapports naturels entre eau, rochers, végétation, soutènements et bâtiments.
- **Le vocabulaire habituel** : les mêmes encadrements, enduits et fenêtres partout. L'histoire d'un quartier construit et transformé ne se lit pas ; une façade de huit mètres n'a pas besoin de dix fenêtres identiques.
- **La vie en couche d'animation** : des habitants présents, aucune situation.
- **Deux surfaces à la même hauteur** (un tablier de pont et son sol) : elles clignotent. Décaler ou supprimer l'une des deux.
- **Une fusion de maillages** qui fait disparaître des éléments (des piles de pont) : vérifier après chaque fusion, de près et de loin.
- **Une marche infranchissable** : l'habitant enjambe seul les petites marches (`step_height`, `scripts/fp_player.gd`) ; au-delà, une rampe ou un vrai escalier.
- **Un calcul refait à chaque chargement** : le garder sur l'appareil.
