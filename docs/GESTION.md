# Les biens et la gestion du village

Ce que le joueur peut posséder à Smarves, ce que ça rapporte, ce que ça coûte, et comment M. Brunet s'en mêle. Le système est dans `scripts/biens.gd` (autoload `Biens`), la simulation dans `tools/sim_gestion.gd`.

## En une phrase

Au premier degré, posséder est la suite logique de gagner : le village vend ses parts, Maître Garnier signe les actes, M. Brunet finance, et chaque bien verse sa rente à chaque recette ; les rentes ne valent jamais tout à fait celles de la brochure, et la recette ne tombe que si l'on joue.

## Les choix tranchés

1. **Le temps se compte en mises.** Comme les intérêts de M. Brunet (bible, section 3), les biens ne rapportent rien pendant qu'on dort : toutes les **20 mises**, c'est **la recette**. Chaque bien verse sa rente et coûte ses charges. Pas de revenu hors ligne.
2. **Les rentes ne comptent jamais dans le total gagné au jeu.** Elles vont dans les crédits, pas dans « Gagné au jeu ». Les seuils restent la seule affaire du jeu, et leurs valeurs ne bougent pas.
3. **Les vendeurs proposent un bien quand le lieu concerné est ouvert** : la commandite du fournil quand la boulangerie l'est (3 000 gagnés), la part du comité des fêtes avec la salle Rabelais (8 000), l'action du casino avec le Salon privé (5 000). C'est la seule façon dont les biens touchent aux seuils : ils les lisent, ils ne les changent pas.
4. **La brochure ment un peu, sans le savoir.** Chaque fiche annonce une rente ; la recette réelle est tirée entre 35 % et 100 % de l'annonce (65 % en moyenne). Personne ne s'en excuse : « la recette du soir ».
5. **La recette suit l'animation du village, et l'animation, c'est le joueur.** Elle n'est pleine que si l'on a misé au moins 500 crédits sur les 20 mises (25 par mise en moyenne) ; en dessous, elle est réduite d'autant. Celui qui ne mise que des pièces de 5 ne touche que le cinquième de ses rentes.
6. **M. Brunet finance tout.** Chez chaque vendeur, deux boutons : payer comptant, ou « financer au Crédit Smarvois ». Le prix s'ajoute à la dette avec les frais de dossier (5 %), et les intérêts courent comme pour tout prêt.
7. **Le standing.** Les maisons, certaines parts, la tenue qu'on porte et le véhicule qu'on conduit donnent des points de standing. Le standing ne donne rien au jeu : il fait grossir **les montants que M. Brunet propose** (500 × (1 + standing / 2) au minimum) et le prix de la tournée générale. Un client bien mis mérite des prêts à sa hauteur.
8. **Revendre, c'est 60 %.** Maître Garnier, Raymonde et Roger Fradin reprennent tout, au prix de reprise : 60 % du prix payé. La valeur des biens affichée dans le carnet est ce prix de reprise.
9. **Les charges impayées passent au Crédit Smarvois.** Si les charges d'une recette dépassent les crédits, M. Brunet règle le reste de lui-même et l'ajoute à la dette : « Ne vous occupez de rien. »
10. **La reprise.** Quand la dette dépasse 10 000 crédits et quatre fois la valeur des biens, M. Brunet reprend le bien le plus cher au prix de reprise, pour « alléger le dossier », au plus une fois toutes les cinq recettes. Il le présente comme un service, et c'en est un, à ses yeux.
11. **La tournée générale**, au café : 120 crédits, plus 40 par point de standing. Josiane remet une avance dans le tiroir (une des deux avances de 200, si on l'a déjà prise) et toute la terrasse applaudit.

Rien de tout cela n'est commenté. Le carnet aligne les chiffres (rentes annoncées, rentes versées, charges, dette, fortune nette) et laisse le joueur faire la soustraction.

## Les vendeurs

| Où | Qui | Ce qu'on y achète |
|---|---|---|
| L'étude de Maître Garnier, notaire | Maître Garnier (le Notaire de Passelourdin, mais ici on l'appelle Maître) | les parts du village et les maisons |
| Raymonde, couture et retouches | Raymonde Chauvet | les tenues |
| Le garage Fradin | Roger Fradin | les véhicules |
| Le Café de la Place | Josiane | la tournée générale |

Les noms viennent de la réserve de la bible (section 7). Les parts sont « cédées » par leur tenancier, qui reste aux commandes : Josiane, Lucien, Mme Ferrand, M. Gaudin, Monsieur Armand pour l'action du casino.

## Le catalogue

Prix du premier exemplaire ; les parts se rachètent plusieurs fois, chaque exemplaire coûte une fois et demie le précédent (1,4 pour les actions du casino). Rente et charges : par recette (20 mises), par exemplaire.

| Bien | Vendeur | Prix | Max | Rente annoncée | Charges | Standing | Proposé à partir de |
|---|---|---:|---:|---:|---:|---:|---|
| Une part de la Smarvoise | notaire (Josiane) | 200 | 5 | 20 | — | — | dès le départ |
| Une part du tableau des cotes | notaire (Lucien) | 500 | 4 | 50 | — | — | 1 000 gagnés (pétanque) |
| Une commandite au fournil | notaire (Mme Ferrand) | 1 200 | 4 | 120 | — | — | 3 000 gagnés (boulangerie) |
| Une action du Casino de Smarves | notaire (Monsieur Armand) | 6 000 | 10 | 600 | — | 1 | 5 000 gagnés (Salon privé) |
| Une part du comité des fêtes | notaire (M. Gaudin) | 3 000 | 3 | 300 | — | 1 | 8 000 gagnés (salle Rabelais) |
| La chambre au-dessus du café | notaire | 800 | 1 | 80 | 5 | 1 | dès le départ |
| La maison de la rue de l'Église | notaire | 5 000 | 1 | 480 | 40 | 3 | 3 000 gagnés |
| La maison de maître sur la place | notaire | 20 000 | 1 | 1 900 | 180 | 6 | 20 000 gagnés (parvis) |
| Le costume du dimanche | couture | 250 | 1 | — | 3 | 1 | dès le départ |
| Le trois-pièces prince-de-galles | couture | 900 | 1 | — | 8 | 2 | 1 000 gagnés |
| Le smoking de soirée | couture | 3 000 | 1 | — | 20 | 4 | 5 000 gagnés |
| La Mobylette bleue | garage | 500 | 1 | — | 5 | 1 | dès le départ |
| La 2 CV | garage | 2 200 | 1 | — | 20 | 3 | 1 000 gagnés |
| La DS 21 | garage | 9 000 | 1 | — | 70 | 6 | 20 000 gagnés |

On ne porte qu'une tenue et on ne conduit qu'un véhicule à la fois : seuls ceux-là comptent pour le standing et les charges. La tenue portée habille le personnage du joueur.

La rente annoncée vaut 10 % du prix par recette : sur la brochure, un bien se rembourse en dix recettes, soit 200 mises, un petit quart d'heure. En vrai, à 65 % de l'annonce, il en faut plutôt quinze, si l'on mise assez pour que la recette soit pleine.

### Toutes les adresses du village

Chez le notaire, chaque adresse du village s'achète : une cinquantaine, posées sur un plan en trois onglets (la place, la rue du Clain, la route du Bois), chaque façade à sa place et à sa largeur, numérotée, impairs au nord et pairs au sud. Une maison ou un pavillon devient un logement, qu'on habite, qu'on meuble ou qu'on loue (le prix suit la largeur et les étages, l'intérieur aussi : maisonnette, maison, maison haute, pavillon). Une boutique se vend en murs : le commerçant reste et paie son loyer. Un bâtiment public (mairie, église, école, bibliothèque, poste, banque) se vend plus cher et la commune paie un loyer plus sage (8 %). Les cafés, les salles et le casino gardent leurs parts. Le registre est celui du manifeste de la commune (`docs/COMMUNE.md`, section « Le notaire ») ; pour Smarves, `scripts/adresses.gd` le calcule depuis les rangées de façades du village.

## La courbe de la première heure

Simulation : `godot --headless --path . res://tools/sim_gestion.tscn`. Ce sont les 300 joueurs moyens de `sim_progression` (un coup toutes les 5 secondes, une mise d'un dixième des crédits, avances de Josiane puis M. Brunet), joués avec les mêmes tirages sans rien acheter, puis en achetant : le bien le moins cher proposé (une fois sur deux, le moins cher qui rapporte) dès qu'on a trois fois son prix en poche. Trois profils : le joueur moyen (un sur quatre fait financer), celui qui n'achète que comptant, celui qui fait toujours financer ce qu'il n'a pas de quoi payer trois fois.

Ce qui en sort :

- **Les seuils ne bougent presque pas.** Acheter, c'est autant de moins sur le tapis : la boulangerie arrive deux minutes et demie plus tard (16,3 min au lieu de 13,7), le reste à une minute près. Les biens ne retardent pas l'histoire.
- **Le premier achat tombe vers deux minutes** : une part de la Smarvoise, pour tout le monde.
- **Comptant, on achète peu** : quatre biens dans l'heure, 60 crédits de rente annoncée à la fin. Les crédits fondent au jeu bien avant de s'accumuler.
- **Financé, on achète tout** : vingt-deux biens, une rente annoncée qui passe de 20 à 1 640 par recette, standing 10, et c'est lui qui va le plus loin dans le village (49 000 gagnés au lieu de 19 000, un sur quatre aux zèbres). Sa dette atteint 57 000, sa fortune nette −24 000. C'est la courbe d'Addict, et c'est la démonstration, sans un mot.
- **La reprise** touche un joueur sur cinq dans l'heure, presque toujours sur une petite part ; elle devient la règle au-delà, quand la dette s'emballe.

```
=== 300 joueurs, 60 minutes : sans biens / avec biens ===
Casino : La Salle des Ambassadeurs         seuil     500   100 % · 2.1 min   |   100 % · 2.2 min
Lieu : La pétanque de la place             seuil    1000   100 % · 4.0 min   |   100 % · 3.9 min
Casino : La Loggia                         seuil    2000   100 % · 8.2 min   |   100 % · 8.3 min
Lieu : La boulangerie                      seuil    3000   100 % · 13.7 min   |   100 % · 16.3 min
Casino : Le Salon privé                    seuil    5000   100 % · 26.7 min   |   100 % · 27.9 min
Lieu : La salle François-Rabelais          seuil    8000    98 % · 37.2 min   |    98 % · 37.8 min
Casino : Le Salon de musique               seuil   10000    93 % · 41.9 min   |    92 % · 41.3 min
Lieu : Le parvis Saint-Félix               seuil   20000    57 % · 49.4 min   |    61 % · 47.6 min
Lieu : L'allée des trois zèbres            seuil   50000    18 % · 52.1 min   |    24 % · 48.8 min
Casino : Les Salons particuliers           seuil   50000    18 % · 52.1 min   |    24 % · 48.8 min
Lieu : Le Moulin des Dames                 seuil  120000     5 % · 54.2 min   |     7 % · 52.1 min
Lieu : Les rochers de Passelourdin         seuil  300000     0 % · 59.7 min   |     0 % · 59.8 min
Premier prêt de M. Brunet           88 % · 30.2 min   |    71 % · 30.8 min
Dette médiane à 30 min / 60 min    0 / 4 297   |   525 / 6 218
Gagné au jeu médian à 60 min       22 590   |   25 410
Fortune nette médiane à 60 min (crédits + biens - dette)   -1 989   |   -2 526

--- Les biens : joueur moyen (un sur quatre fait financer) | n'achète que comptant | fait toujours financer ---
Premier achat (médiane)                   1.7 min |    2.4 min |    1.8 min
Achats à 30 min                                 2 |          1 |         11
Achats à 60 min                                 6 |          4 |         22
Rente annoncée par recette à 60 min           110 |         60 |      1 640
Rente versée en moyenne par recette            24 |         18 |        314
Charges par recette à 60 min                    3 |          3 |         53
Standing à 60 min                               1 |          1 |         10
Dépensé en biens dans l'heure               2 200 |      1 200 |     33 610
Reçu en rentes dans l'heure                   786 |        583 |     10 748
Payé en charges dans l'heure                   79 |         51 |        643
Dette à 60 min                              6 218 |      5 003 |     56 766
Fortune nette à 60 min                     -2 526 |     -2 206 |    -24 373
Gagné au jeu à 60 min                      25 410 |     19 320 |     49 035
Reprise par M. Brunet dans l'heure            18 % |        20 % |        18 %
Rente annoncée médiane, joueur moyen :  5 min : 20  10 min : 20  15 min : 20  20 min : 20  30 min : 20  40 min : 40  50 min : 60  60 min : 110
Rente annoncée médiane, comptant :  5 min : 20  10 min : 20  15 min : 20  20 min : 20  30 min : 20  40 min : 20  50 min : 40  60 min : 60
Rente annoncée médiane, financé :  5 min : 20  10 min : 60  15 min : 110  20 min : 180  30 min : 280  40 min : 500  50 min : 1 040  60 min : 1 640
```

## Le carnet

Touche **C**, partout (village, casino, boutiques) : le carnet du joueur, un cahier d'écolier à petits carreaux, à l'encre bleue. Pas de tableau de bord. On y lit, à la main :

- **Mes biens** : chaque bien, combien d'exemplaires, la rente annoncée, la dernière recette versée, les charges ; la tenue portée et le véhicule conduit (on en change d'un clic).
- **La dernière recette** : ce qu'a versé chaque bien, et l'animation du village (« recette pleine », « recette à moitié »).
- **Mes comptes** : crédits, valeur des biens (« estimation de Maître Garnier »), dette au Crédit Smarvois, et la ligne du bas, fortune nette. Depuis le début : dépensé en biens, reçu en rentes, payé en charges.
- **Adresses** : l'étude, la couture, le garage, et la tournée au café.

Une petite fiche de papier glisse en bas de l'écran à chaque recette (« La recette : 86 versés, 8 de charges. ») et à chaque reprise de M. Brunet.

## Chez les vendeurs

Chaque vendeur a son intérieur, à la première personne, comme le casino : l'étude de Maître Garnier (bureau, dossiers, horloge), l'atelier de Raymonde (mannequins, rouleaux de tissu, miroir), le garage Fradin (la voiture du moment sur le pont, l'établi, la pompe). On parle au vendeur (E) ; il ouvre sa vitrine : un acte de vente chez le notaire, un bon de commande chez Raymonde et Roger Fradin. Chaque fiche montre le prix, la rente annoncée, les charges, le standing, la phrase du tenancier, et deux boutons : « Payer comptant » et « Financer au Crédit Smarvois ». Le vendeur reprend aussi ce qu'il a vendu, à 60 %.

## Ce qu'il faut dehors

Les devantures et les entrées appartiennent au fil « Extension du village » (voir `docs/VILLAGE.md`). Les intérieurs sont dans `scenes/notaire.tscn`, `scenes/couture.tscn`, `scenes/garage.tscn` (un seul script, `scripts/shop_interior.gd`) ; on y entre par `Biens.SELLERS[id].scene`. En attendant les portes, le carnet y mène directement. À la sortie, `Game.return_point` vaut `notaire`, `couture` ou `garage`, pour réapparaître devant la bonne porte.

- La tournée générale se déclenche par `Biens.offer_tournee()` (faux si les crédits manquent ; prix : `Biens.tournee_price()`).
- Le véhicule conduit se pose avec `Biens.build_vehicle(Biens.driven)`, à l'échelle des voitures KayKit de la maquette ; la Mobylette est dessinée dans le code.
- La tenue portée habille le personnage du joueur (`Biens.outfit_color()`, dans `main.gd`).
- Les maisons possédées : `Biens.count("maison")`, `Biens.count("maison_place")`.

Captures : `godot --path . res://scenes/notaire.tscn -- --capture=sortie.png [--open=vitrine] [--carnet] [--biens=smarvoise,dimanche] [--won=9000] [--at=x,z,lacet,tangage]`.
