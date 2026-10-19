# L'argent tenu par le serveur

Le compte d'argent commun : première étape du « chantier 8, argent partagé » (`docs/SUITE.md`) et du change de Casino Minuit. Accord de principe de Guillaume ; la migration attend son accord pour la production.

## Ce que tient le serveur

- **Un solde par joueur**, en crédits, jamais négatif (`smarves.argent_comptes`).
- **Le journal de tous les mouvements**, où l'on ne fait qu'ajouter (`smarves.argent_mouvements`) : la source (`smarves` pour le jeu, l'identifiant d'une commune, `casino_minuit`), le motif (`ouverture`, `jeu`, `jetons`…), le montant, le solde après, l'heure, et **la clé tirée par l'appareil**, unique par joueur. Un déclencheur refuse toute modification ou suppression (seul l'effacement d'un joueur l'emporte en cascade). Le solde est toujours la somme du journal.
- **Des plafonds par jour et par source** (`smarves.argent_plafonds`, jour de Paris), dans chaque sens : ce qui peut arriver sur le solde, ce qui peut en partir. Ils se règlent dans la table, sans nouvelle migration. Seul le change de Casino Minuit en a un : **50 000 crédits par jour dans chaque sens** (valeur à confirmer par Guillaume).
- **Le change de Casino Minuit** : un jeton pour un crédit, en attendant sa doctrine économique.

Les fonctions, appelées par l'API REST du projet avec la clé publique et le jeton Pyramides du joueur (`p_jeton`, vérifié par `smarves.joueur`, comme pour la partie au compte) :

| Fonction | Ce qu'elle fait |
|---|---|
| `smarves_argent(p_jeton)` | le solde, les vingt derniers mouvements, ce qui reste du change aujourd'hui ; `{ouvert: false}` sans solde |
| `smarves_argent_ouvrir(p_jeton, p_solde, p_cle)` | ouvre le solde **une seule fois** avec la poche de l'appareil ; déjà ouvert, ne change rien et rend le solde du serveur |
| `smarves_argent_mouvement(p_jeton, p_cle, p_source, p_motif, p_montant)` | un mouvement ; une clé déjà reçue rend `deja` sans rien compter ; refus : `compte`, `solde` (il deviendrait négatif), `plafond`, `cle` (déjà prise par un autre mouvement) |

Migration : `supabase/migrations/20261019020000_smarves_argent.sql`. Elle ne dépend que de celle du compte.

## Ce que fait le jeu

Les jeux tournent toujours dans Godot, hors ligne compris, et font bouger `Game.credits` comme avant : rien ne change dans les salles, la première comprise. L'autoload `Argent` (`scripts/socle/argent.gd`) rapproche la poche et le solde du serveur quand le compte est à jour (au lancement, après la synchro de la partie), puis au plus une fois par minute et quand le jeu passe en arrière-plan :

1. **Première fois** : le solde s'ouvre avec ce que l'appareil a en poche. S'il est déjà ouvert (un autre appareil), l'appareil se range au solde du serveur.
2. **Ce que les jeux ont fait bouger** depuis le dernier rapprochement (la poche moins le solde de référence) part en un mouvement `jeu`, avec sa clé.
3. **Hors ligne**, les mouvements attendent dans une file et partent plus tard, dans l'ordre, sous la même clé : un mouvement dont la réponse s'est perdue est rejoué sans être compté deux fois.
4. **Le serveur fait foi** : à la fin, la poche prend l'écart entre le solde du serveur et celui qu'on croyait lui avoir laissé. Ce que Casino Minuit ou un autre appareil y a fait bouger arrive dans la poche ; un mouvement refusé (plafond) est défait.
5. Si les jeux ont perdu plus que ce que le serveur tient (un autre appareil a dépensé entre-temps), le serveur refuse ; le jeu envoie alors la perte bornée au solde : on perd ce qui reste, pas davantage.

Le solde de référence et la file sont rangés **dans la partie**, au tiroir `_argent` (`user://communes/_argent.save`) : ils partent au compte avec elle, et un appareil qui reprend la partie reprend aussi la file, que les clés rendent sans danger à rejouer. Un autre compte sur la même partie ouvre son propre solde.

Une commune ou le jeu peut aussi passer un mouvement nommé : `Argent.mouvement(source, motif, montant)`, fait tout de suite sur l'appareil, puis envoyé.

**Tant que la migration n'est pas appliquée**, la base répond « fonction inconnue » (404, PGRST202) : l'argent passe à l'état `absent`, le jeu reste local, ne dit rien au joueur et ne redemande qu'une demi-heure plus tard. Sans compte, rien ne part.

Tests : `tools/test_argent.gd` (faux serveur qui suit les règles de la migration).

## Ce que Guillaume doit trancher

- **Le plafond du change** de Casino Minuit : 50 000 crédits par jour dans chaque sens, proposé.
- **Les gains des jeux de Smarves ne sont pas plafonnés** : le serveur croit l'appareil, comme aujourd'hui. La suite prévue (`docs/SUITE.md`) est un plafond par heure sur la source `smarves`, comme la manche d'Addict ; il suffira d'une ligne dans `argent_plafonds`.
- **L'ouverture croit la poche de l'appareil** (jusqu'à un milliard de crédits), une seule fois par compte.
- **L'argent est celui du compte** : une fois le solde ouvert, « Nouvelle partie » ou garder la partie d'un appareil ne remettent pas la poche à 1 000 crédits ; elle se range au solde du serveur.
