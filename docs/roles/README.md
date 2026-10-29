# L'équipe d'une carte

[`CONCEPTION.md`](../CONCEPTION.md) dit la méthode ; ces fiches disent **qui fait quoi, avec quelle exigence et dans quelle mesure**. Elles sont nées le 29 octobre 2026 du constat de Guillaume sur les trois premières cartes hors de la Vienne (Toulouse Saint-Georges, Lyon Sathonay, Belley) : les agents bâclaient certains aspects en restant superficiels. Chaque fiche porte donc les erreurs réellement commises sur ces chantiers, pour qu'on ne les refasse pas.

Elles valent pour un Claude seul comme pour une équipe d'agents, et pour un auteur humain.

## Le principe : un game designer, des casquettes, de la mesure

Une carte a **un seul responsable, le game designer** ([`game-designer.md`](game-designer.md)). C'est le fil de la carte lui-même. Il tient la note d'intentions, parle à Guillaume, décide de l'ordre et **convoque** les autres rôles quand l'étape en a besoin, ni plus ni moins.

Les autres rôles sont d'abord des **casquettes** : le fil les met l'une après l'autre, avec la fiche ouverte comme liste de contrôle. Un rôle ne devient un sous-agent que dans deux cas :

- **le juge**, toujours, parce qu'un regard qui n'a pas construit est la seule chose qu'on ne peut pas faire soi-même ;
- **la construction en parallèle** d'un grand lieu, une zone par agent, chacune dans ses fichiers (CONCEPTION, « La méthode de travail »).

**Calibrer, c'est doser.** Chaque fiche dit sa **dose** : combien de temps, combien de passes, quelle taille de livrable. Un rôle qui dépasse sa dose sans raison fait du zèle ; un rôle qui la bâcle laisse un défaut que Guillaume verra. La bonne exigence est **celle qui se voit à hauteur de joueur** : un défaut invisible en jeu ne justifie pas une passe, un défaut visible ne se laisse jamais.

Une étape se termine sur un livrable court (une planche, une liste, une note d'une page), pas sur un rapport. Guillaume voit des images, pas des procédures.

## Les rôles

| Rôle | Ce qu'il apporte | Quand on l'appelle | Dose |
|---|---|---|---|
| [Game designer](game-designer.md) | l'intention, l'ordre, les arbitrages, le lien avec Guillaume | tout le long | le fil lui-même |
| [Directeur artistique](directeur-artistique.md) | les partis pris tranchés, la palette, la lumière, la planche cible | avant le premier modèle, puis à chaque vague | une planche et une page de partis pris |
| [Relevé du site](releve.md) | la disposition réelle lue et comprise (OSM, IGN, plans, dessins de Guillaume) | avant la maquette ; à chaque nouveau tracé de Guillaume | un plan annoté et une liste d'anomalies, une heure au plus |
| [Bibliothécaire](bibliothecaire.md) | ce qui existe déjà, ce qui manque, ce qu'on demande | avant de modeler quoi que ce soit | une table « besoin → brique », un quart d'heure |
| [Metteur en scène](metteur-en-scene.md) | la composition des trois scènes, les cadrages, la vie | à la maquette, puis à chaque scène | une scène à la fois, cadrage d'abord |
| [Équipements de la ville](equipements.md) | sols, bordures, mobilier, éclairage public, stationnement, végétal planté | après la maquette, avant la finition | une passe par scène forte |
| [Intérieurs](interieurs.md) | les salles où l'on joue, au niveau du sports bar de Cloué | seulement quand la carte a des intérieurs | une salle à la fois |
| [Technicien Godot](technicien.md) | le meilleur rendu possible dans le budget, web et téléphone compris | à la maquette (choix structurants) et avant chaque livraison | une mesure et une liste de gains, pas une réécriture |
| [Juge](juge.md) | la cohérence entre le résultat et les exigences, chiffrée | à la fin de chaque étape montrée à Guillaume | un verdict d'une page, des écarts classés |

## L'enchaînement d'une carte

Chaque étape dit qui travaille, ce qui en sort, et qui la ferme.

1. **Cadrage** (game designer) : les quatre questions à Guillaume, en un message ; la commune ; le périmètre (« la place + 30 m » vaut mieux qu'un quartier entier à moitié fait).
2. **Relevé** (relevé du site) : le plan réel lu, ses anomalies signalées, les dessins de Guillaume reportés.
3. **Inventaire** (bibliothécaire) : ce qu'on prend, ce qu'on adapte, ce qu'on demande au fil de la bibliothèque.
4. **Direction** (directeur artistique) : partis pris, palette, lumière, planche cible ; **Guillaume valide** note et planche.
5. **Maquette traversable** (metteur en scène, avec le technicien pour les choix structurants : rendu visé, imposteurs, découpage) : volumes, parcours, caméras de contrôle aux points de vue des planches.
6. **Scène par scène**, une à la fois, montrée avant la suivante : composition (metteur en scène), équipements, intérieurs s'il y en a ; à la fin de chacune, **le juge**, puis Guillaume.
7. **Vagues** sur tout le lieu (lumière, matières, vie), chacune fermée par le juge.
8. **Livraison** (technicien puis game designer) : budget, `test_commune`, `parcours_commune`, emballage, PR.

Le juge ne remplace pas Guillaume : il passe avant lui, pour que Guillaume ne voie que des étapes qui ont déjà eu leur premier regard critique.

## Les erreurs communes aux trois premières cartes

Elles reviennent dans les fiches ; les voici rassemblées.

- **Le réel mal lu** : un kiosque d'OpenStreetMap habillé en bar au milieu de la rue (Toulouse), des terre-pleins et des bacs que Guillaume a dû dessiner en rouge, des platanes à la place des marronniers (Lyon).
- **La bibliothèque contournée** : une auberge et des maisons modelées à la main alors que `facadier-du-bugey@1` faisait exactement ce que montrait la planche (Belley) ; à l'inverse, des falaises de bibliothèque gardées alors qu'elles ne ressemblaient pas au réel.
- **La lumière plate** : ambiance plus forte que le soleil, noirs levés, saturation basse (Belley, mesuré par le juge) ; un espace de couleur mal compris qui rougit tout.
- **Le cadrage non tenu** : une caméra de comparaison presque de face là où la planche est en trois quarts ; des toits de premier plan qui mangent 40 % de l'image.
- **Le budget mal arbitré** : des façades appauvries pour tenir 600 000 triangles alors que Guillaume accepte de dépasser avec des imposteurs ; à l'inverse, des fenêtres en relief à un million de triangles.
- **Tout à la fois** : trois places ou 2 578 maisons lancées d'un coup, Guillaume qui doit rappeler « séquentiellement » et « item par item ».
- **Le silence** : de longues passes sans image, Guillaume qui demande deux fois « tu es bloqué ? ».
- **Le garde-fou ignoré** : un commit refusé par Guillaume poussé quand même.
