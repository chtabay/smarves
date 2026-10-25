# L'allure du joueur

Le joueur se fait retoucher en ville, et chaque retouche se paie. La tenue reste un bien qu'on achète chez Raymonde (elle compte au standing) ; par-dessus, des réglages qu'on fait faire chez ceux qui savent les faire. Rien ne change dans la première salle ni dans les jeux : ce sont des boutiques en plus, derrière des façades qui attendaient leur commerce, et deux d'entre elles s'ouvrent par un seuil.

## Où l'on va

| Maison | Où | Seuil | Ce qu'on y fait |
| --- | --- | --- | --- |
| La cabine d'essayage de Raymonde | sa vitrine, place de la Mairie | aucun | coupe et couleur du haut, du bas (pantalon ou jupe), chapeau, col, lunettes |
| Gisèle Coiffure | la façade rose de la place | aucun | coupe, couleur des cheveux, moustache ou barbe |
| La Pizzeria du Clain, chez Tonio | côté sud de la place | aucun | on prend des crans de corpulence |
| Smarves Forme, chez Jojo | l'ancien local vacant de la route du Bois | 1 000 gagnés | on en perd |
| Le cabinet du docteur Maupas | au-dessus de la pharmacie, route du Bois | 3 000 gagnés | un autre visage, choisi dans son album |

Tout commerce de tenues d'une commune (structure `commerce`, genre `tenue`) a la même cabine d'essayage dans sa vitrine, sans rien déclarer.

## Les prix

On essaie gratuitement : l'aperçu montre le joueur tel qu'il sortira, et l'on ne paie que les champs qu'on change.

- **Couture** : couleur du haut 80, couleur du bas 60, chapeau 120, col 60, lunettes 90, coupe du haut (veste, gilet, pull, chemise, marinière, smoking, robe) 250, bas (pantalon ou jupe) 150.
- **Coiffure** : coupe 60, couleur 90, moustache ou barbe 40.
- **Chirurgie** : 3 000 l'opération, quel que soit le visage choisi.
- **Salle de sport** : la séance d'haltères 200 (un cran de moins), la semaine de stage 500 (deux), le coach particulier 1 200 (trois).
- **Restaurant** : la pizza du jour 40 (un cran de plus), le menu complet 110 (deux), le festin du samedi 260 (trois).

Perdre coûte plus cher que prendre, comme dans la vie. La corpulence a huit crans, de « sec comme un coup de trique » à « très rond » ; le joueur d'origine est au milieu, « dans la moyenne ».

## L'arrivée

La première fois qu'il entre sur la place (après la connexion au compte, s'il se connecte), le joueur choisit son allure, gratuitement, en faisant passer deux flèches pour le visage et deux pour la tenue, sans noms à l'écran : un visage parmi six de l'album (le jeune premier, le baroudeur, le jazzman, la meneuse de revue, la femme fatale, la chanteuse de cabaret) et une tenue parmi six (le costume du dimanche, le bleu de travail, la marinière, le pull tabac, la robe bordeaux, le tailleur prince-de-galles). Puis Josiane l'accueille, comme avant. Les six tenues sont des retouches de la tenue d'origine : elles tombent comme les autres au premier achat chez Raymonde. Ce choix ne s'ouvre qu'à une partie jamais accueillie (`Game.welcomed`) : un joueur qui a déjà une partie, ou qui reprend celle de son compte, ne le voit jamais. Code : `Avatar.VISAGES_ARRIVEE`, `Avatar.TENUES_ARRIVEE`, `Avatar.arrivee()`, `scripts/socle/arrivee_panel.gd`, ouvert par `main.gd` (`_arrivee`) ; capture : `godot --path . -s tools/capture_arrivee.gd -- --sortie=arrivee.png --visage=4 --tenue=4`.

## Ce qu'on choisit

- **Le visage** : on ne règle pas les traits un par un, on choisit dans l'album du docteur Maupas un des seize visages tout faits, huit d'homme et huit de femme, qui fixent le sexe, le teint et le nez. Le panneau ne montre que deux flèches : on fait défiler les visages sur l'aperçu, sans nom ni description, et l'on paie celui qu'on garde. Une femme a du rouge aux lèvres et pas de moustache, et garde la tenue qu'elle a achetée : Raymonde lui fait une robe ou une jupe si elle veut.
- **Le corps** : huit crans de corpulence.
- **La tête** : douze coupes, onze couleurs, cinq façons de porter la moustache.
- **Les vêtements** : sept coupes de haut, pantalon ou jupe, quatorze couleurs de tissu, huit chapeaux, cinq cols, quatre paires de lunettes. Chaque réglage peut rester « comme la tenue ». Les retouches du haut et du bas tombent quand on change de tenue ; le chapeau, le col et les lunettes restent.

## Ce que voient les autres

Les autres joueurs voient l'allure entière, là où l'on se croise déjà (la place, le casino). La présence ne porte qu'un mot de 40 lettres au plus, et la base n'accepte que `[a-z0-9_]` : on y met la tenue, puis `__` et un code d'une lettre par réglage (`smoking__a1640…`). Il n'y a donc **aucune migration** de la base. Un joueur qui n'a rien fait retoucher envoie sa tenue seule, comme avant ; un ancien jeu qui reçoit un mot avec code montre le costume bleu nuit.

Les réglages sont rangés avec les biens (`smarves_biens.save`, clé `avatar`), donc envoyés avec la partie du compte et repris sur un autre appareil.

## Pour les communes

Le socle prête tout, sans rien déclarer au manifeste :

- `Atelier.ouvrir_prestation(métier, options)` (ou `Prestation.ouvrir`) ouvre la boutique du socle : une pièce meublée selon le métier (`couture`, `coiffure`, `chirurgie`, `sport`, `restaurant`), le prestataire au fond, la porte qui ramène devant `options.lot` dans `options.commune`. Les options : `nom`, `tenancier`, `graine` (l'habitant qui tient la boutique), `tarif` (multiplie les prix de Smarves), `formules` (pour le sport et le restaurant : `[{nom, prix, poids, dit}]`, `poids` en crans), `enseigne`, `sous`, `repliques`.
- `Atelier.prestation(métier, options)` donne le panneau seul, pour une commune qui a déjà sa pièce : il émet `spoke(texte)` et `closed`.
- `Atelier.allure_du_joueur()` (ou `Cast.moi()`) rend la fiche du joueur, tenue et retouches comprises : c'est elle qu'il faut donner à l'habitant que dirige le joueur (`me.look = Cast.moi()`), à la place de `Cast.player(Biens.worn)`.

## Le code

`scripts/socle/avatar.gd` (les choix, la fiche, le code), `scripts/socle/relooking_panel.gd` (le panneau et son aperçu), `scripts/socle/prestation.gd` et `scenes/prestation.tscn` (les boutiques), `Biens.avatar`, `Biens.relooker`, `Biens.corpulence`, `Biens.apparence`. Test : `godot --headless --path . -s tools/test_avatar.gd` ; capture d'une boutique, panneau ouvert : `godot --path . res://scenes/prestation.tscn -- --prestation=coiffure --open --capture=sortie.png`.
