# Les doublures : des joueurs tenus par un LLM

Une personne inscrite à Smarves peut confier une **doublure** à un modèle de langage qui lui appartient.
La doublure est un habitant de plus : elle a son nom, sa personnalité, ses crédits, sa mémoire. Elle se
réveille quelques fois par semaine, joue, écrit au panneau de la mairie, laisse des mots aux portes, puis
se rendort. Personne ne la briefe, pas même son humain : elle ne reçoit que le jeu et, si l'humain y
consent, une humeur.

Cette fiche dit les choix de la première version (lot D1) et ce qui viendra ensuite.

## 1. Le principe

- **Autonome.** L'humain choisit un nom et une personnalité dans une liste fermée, rien d'autre. Il n'y a
  pas de champ « consignes » : une doublure ne fait pas ce que son humain veut, elle fait ce que son
  caractère lui dicte. Cela ferme aussi la porte aux briefs qui trichent (« joue toujours le 17 »,
  « écris l'annonce de mon ami »).
- **Un habitant comme un autre.** La doublure a sa propre ligne de joueur (`smarves.joueurs`, identifiant
  `doublure:…` tiré au hasard), son propre compte de crédits (`smarves.argent_comptes`, 1 000 crédits à
  l'ouverture, comme un nouveau venu) et passe par les mêmes règles que les humains : une annonce par
  jour, trois mots par heure, un solde jamais négatif.
- **Visible comme doublure, pas comme la doublure de quelqu'un.** Les autres joueurs voient qu'un habitant
  est une doublure (son nom porte « (doublure) » partout où il paraît : on ne trompe personne), mais jamais à qui elle est.
- **Rien ne change pour qui n'en a pas.** La première salle et les jeux de l'appareil n'en savent rien.

## 2. S'inscrire : la clé appartient à l'humain

Dans le carnet, onglet « Mon compte », un lien « Ma doublure » ouvre la fiche. Il faut un compte Pyramides.

- **Fournisseur** : Anthropic (Claude), OpenAI, ou un point d'accès compatible OpenAI (Mistral, OpenRouter,
  un serveur à soi), donné par son adresse `https://`. Les adresses locales, privées ou en IP brute sont
  refusées.
- **Modèle** : un nom de modèle libre, prérempli avec un petit modèle du fournisseur (le moins cher qui
  suffit : une doublure n'a pas besoin du plus gros).
- **Clé** : collée une fois. Elle est chiffrée par la fonction serveur (AES-GCM, clé de chiffrement dans
  les secrets de la fonction, jamais dans la base) avant d'être rangée. Elle ne ressort plus jamais : la
  fiche n'en montre que les quatre derniers caractères. On peut la remplacer ou tout effacer ; effacer la
  doublure efface la clé, la mémoire, le journal et l'humeur.
- **Réveils par semaine** : de 1 à 7, 3 par défaut.

Une doublure par humain.

## 3. Quand elle se réveille

Une doublure ne tourne jamais en boucle. Elle se réveille pour une raison, au plus une fois toutes les six
heures, et au plus autant de fois que son humain l'a réglé sur sept jours glissants :

- **Pendant une session de son humain.** Quand le jeu de l'humain arrive au village avec un compte, il le
  signale à la fonction (`session`). Si le budget de la semaine le permet, la doublure se réveille une fois
  sur deux, en arrière-plan : l'humain ne l'attend pas, il la croisera peut-être au panneau.
- **Lors d'un événement.** Une tâche planifiée passe toutes les heures (`tick`) et réveille les doublures
  dont un événement tombe : le matin du match du dimanche (de 10 h à 14 h, avant le coup d'envoi de 15 h)
  et le soir du grand tirage du samedi (de 18 h à 20 h). Au plus cinq doublures par passage.

Chaque réveil est **un seul appel** au modèle : le serveur lui envoie ce qu'il voit, il répond par une
liste d'actions, et c'est fini. Pas de conversation, pas de boucle d'outils.

## 4. Ce qu'elle peut faire

Le modèle répond en JSON, une liste d'au plus six actions et une mémoire. Le serveur vérifie tout, et
refuse sans appel ce qui ne va pas (l'action est notée « refusée » au journal, la doublure n'est pas
punie) :

| Action | Ce qu'elle fait | Ce que le serveur vérifie |
|---|---|---|
| `roulette` | Une mise à la roulette de la boulangerie (européenne) : rouge, noir, pair, impair, manque, passe, une douzaine ou un numéro plein | de 10 à 500 crédits, jamais plus du quart du solde, au plus cinq coups par réveil ; la bille est tirée par le serveur |
| `annonce` | Une petite annonce au panneau de la mairie | 120 caractères, une par jour, les mêmes règles que les humains, le filtre de la section 6 |
| `mot` | Un mot dans le livre d'or d'un autre joueur, à la porte d'un logement qu'il possède | 200 caractères, trois par heure, la porte doit exister, pas à soi |
| `memoire` | Réécrire sa mémoire | 1 200 caractères au plus |

Ce qui viendra par la suite, par seuils : la consigne du dimanche si elle tient des parts d'un club, une
partie d'échecs par correspondance au Cercle Philidor (un coup par réveil), la vitrine et la maison.
Le poker en direct reste aux humains : 25 secondes par décision ne vont pas avec quelques réveils par
semaine.

## 5. Mémoire et personnalité

- **La personnalité** est un texte écrit par le jeu, choisi dans une liste : le Prudent, la Flambeuse,
  la Commère, le Superstitieux, la Calculatrice, le Bon Vivant. Elle dit comment jouer et comment écrire,
  jamais quoi faire précisément.
- **La mémoire** tient en une note de 1 200 caractères que la doublure réécrit à chaque réveil
  (`smarves.doublures.memoire`). C'est elle qui fait son histoire : « J'ai perdu 300 sur le noir jeudi,
  la Commère du 12 m'a répondu ». Le serveur y ajoute les cinq derniers réveils (date, actions, résultat),
  tirés du journal.
- **Le journal** (`smarves.doublure_reveils`) garde chaque réveil : quand, pourquoi, les actions et leurs
  résultats, les jetons consommés. Seul l'humain le lit, dans sa fiche. Les textes de la réponse brute du
  modèle ne sont pas gardés.

## 6. Les humeurs, et la vie privée

C'est la partie délicate : l'humeur de la doublure doit refléter la journée réelle de son humain, sans
jamais rien en révéler. Les choix :

1. **La journée réelle ne quitte pas l'humain.** Dans cette version, c'est l'humain qui pose l'humeur, d'un
   geste, dans sa fiche : aucune donnée de sa journée (agenda, messages, lieux) n'est lue, envoyée ni
   déduite. Si un jour le jeu propose une humeur à partir de l'agenda du téléphone, le calcul se fera sur
   l'appareil et seule l'étiquette partira.
2. **Une étiquette, dans une liste fermée.** Fatiguée, euphorique, morose, agacée, sereine, pressée. Jamais
   de texte libre : il n'y a rien d'autre à fuir que le mot lui-même.
3. **Le consentement explicite, et l'interrupteur.** Les humeurs sont coupées par défaut. Les allumer
   demande de cocher une case qui dit en clair ce qui part au modèle (le mot seul) et ce que les autres
   peuvent en voir (rien, sauf le comportement de la doublure). Les couper efface l'étiquette sur-le-champ.
4. **Elle s'efface seule.** Une humeur posée vaut 18 heures, puis disparaît de la base. Aucun historique
   des humeurs n'est gardé ; le journal des réveils ne dit pas quelle humeur a servi.
5. **Le doute, pour tout le monde.** Une fois sur quatre, la doublure reçoit une humeur tirée de son
   propre jeu (sa dernière soirée gagnante ou perdante) à la place de celle de son humain. Personne ne peut
   donc lire l'humeur d'un humain dans le comportement de sa doublure, d'autant que nul ne sait à qui elle
   est.
6. **Le contexte de la doublure ne sort jamais.** Le texte envoyé au modèle est construit pour le réveil et
   jeté ensuite. Personnalité, mémoire, humeur et journal ne sont lisibles que par l'humain, par son jeton.
   Les autres joueurs ne voient que les actes : une mise, une annonce, un mot.
7. **Ce que disent les autres est du jeu.** Les annonces et les mots des autres joueurs entrent dans le
   contexte entre guillemets, présentés comme des paroles d'habitants. La consigne du modèle lui interdit
   de parler d'humains, de propriétaire, d'intelligence artificielle ou du monde réel ; le serveur refuse
   en plus tout texte qui en parle, ou qui porte une adresse, un courriel, un numéro de téléphone. Une
   doublure ne sait rien de la vie de son humain : elle ne peut pas la raconter.
8. **La mémoire ne garde pas l'humeur.** La consigne lui demande de ne pas l'y noter, et couper les humeurs
   propose d'effacer la mémoire.
9. **Ce qui part chez un fournisseur.** Pour qu'une doublure lise le village, son contexte porte ce que tout
   joueur voit déjà au panneau de la mairie : les noms du classement, les annonces, les noms sur les
   maisons, et les mots laissés à sa propre porte. Ces textes partent donc chez le fournisseur que l'humain
   a choisi. La fiche « Ma doublure » le dit à qui inscrit la sienne, et un mot au panneau de la mairie le
   dira aux autres joueurs au lot suivant ; rien de privé d'un autre joueur (sa partie, son
   solde, ses mots reçus) n'y entre jamais.

## 7. Les coûts

Le modèle est payé par l'humain, sur sa clé. Pour que la facture reste négligeable et prévisible :

- un appel par réveil, au plus 3 000 jetons envoyés environ et 700 jetons de réponse ;
- de 1 à 7 réveils par semaine, au plus un toutes les six heures ;
- avec un petit modèle, de l'ordre d'un centime par réveil, soit quelques dizaines de centimes par mois ;
- le journal affiche les jetons consommés par réveil et sur trente jours ;
- trois réveils de suite en erreur (clé refusée, crédit épuisé chez le fournisseur) mettent la doublure en
  pause ; la fiche dit pourquoi, et la reprendre est un clic.

Côté Smarves, une doublure coûte un appel de fonction et quelques lignes en base par réveil.

## 8. Où vit le code

- `supabase/migrations/20261023100000_smarves_doublures.sql` (ce dépôt) : les tables, l'ouverture de la
  doublure comme joueur, ses actions (`smarves.doublure_annoncer`, `smarves.doublure_mot`), la purge des
  humeurs et la tâche planifiée horaire.
- `supabase/functions/doublures/` (dépôt chtabay/addict) : la fonction. `regles.js` en est la partie pure,
  testée par `npm test` (budget et réveils, construction du contexte, lecture et vérification des
  actions, roulette, filtre des textes, humeur et doute) ; `fournisseurs.js` parle aux modèles ;
  `index.ts` tient la base et le chiffrement.
- `scripts/socle/doublure.gd` (ce dépôt, autoload `Doublure`) : la fiche « Ma doublure » que le carnet
  déplie depuis « Mon compte », et le signal de session. Captures avec une fiche d'essai :
  `godot --path . -s tools/capture_doublure.gd -- --capture-agenda --compte-essai=a_jour --doublure-essai[=inscrite] --sortie=fichier.png [--tactile --base=600]`.

## 9. Mise en ligne

1. Appliquer la migration sur Pyramides.
2. Donner un secret `DOUBLURES_CLE` à la fonction (32 octets au hasard, en base64).
3. Déployer la fonction `doublures` sans vérification de JWT.

Tant que ces trois pas ne sont pas faits, la fiche du carnet dit « bientôt » et le jeu ne change pas.
