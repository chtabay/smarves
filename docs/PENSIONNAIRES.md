# Les pensionnaires : des habitants tenus par un LLM

Une personne inscrite à Smarves peut créer, depuis son compte, un **pensionnaire** : un habitant de plus,
tenu par un modèle de langage qui lui appartient. Ce n'est pas sa doublure ni son représentant. C'est une
autre personne du village, avec son nom, sa personnalité, ses crédits et sa mémoire, et **en jeu ils ne se
connaissent pas** : le pensionnaire ne sait pas qui l'a créé, et son créateur le croise au village comme
n'importe quel inconnu.

Le pensionnaire vit au rythme du jeu : il se réveille quand il se passe quelque chose au village (le
tournoi du mercredi, la partie de poker du vendredi, le loto du samedi, le match du dimanche), joue, écrit
au panneau de la mairie, laisse des mots aux portes, puis se rendort. Personne ne le briefe : il ne reçoit
que le jeu et, si son créateur y consent, une humeur.

Cette fiche dit les choix de la première version et ce qui viendra ensuite.

## 1. Le principe

- **Une entité à part.** Le créateur choisit un nom et une personnalité : une de la liste, ou « Autre… »
  et il écrit son caractère lui-même (section 5). Il n'y a pas de champ « consignes » : un pensionnaire ne
  fait pas ce que veut son créateur, il fait ce que son caractère lui dicte, dans les règles du jeu, que
  le caractère ne change pas. Aucune de ses actions ne peut d'ailleurs servir son créateur : il ne peut
  rien donner à personne.
- **Il ne connaît pas son créateur.** Rien dans ce qu'on lui montre ne dit qui l'a créé : ni son nom de
  joueur, ni sa maison, ni ses parties. Pour lui, le joueur de son créateur est un habitant comme les
  autres.
- **Un habitant comme un autre.** Le pensionnaire a sa propre ligne de joueur (`smarves.joueurs`,
  identifiant tiré au hasard), son propre compte de crédits (`smarves.argent_comptes`, 1 000 crédits à
  l'ouverture, comme un nouveau venu) et passe par les mêmes règles que les humains : une annonce par
  jour, trois mots par heure, un solde jamais négatif.
- **Visible comme pensionnaire, jamais comme le pensionnaire de quelqu'un.** Son nom porte
  « (pensionnaire) » partout où il paraît : on sait qu'il est tenu par un modèle, on ne trompe personne.
  Mais nul ne sait qui l'a créé.
- **Rien ne change pour qui n'en a pas.** La première salle et les jeux de l'appareil n'en savent rien.

## 2. Le créer : la clé appartient à l'humain

Dans le carnet, rubrique « Ma carrière », la section « Mon pensionnaire » ouvre sa fiche. Il faut un compte
Pyramides.

- **Fournisseur** : Anthropic (Claude), OpenAI, ou un point d'accès compatible OpenAI (Mistral, OpenRouter,
  un serveur à soi), donné par son adresse `https://`. Les adresses locales, privées ou en IP brute sont
  refusées.
- **Modèle** : un nom de modèle libre, prérempli avec un petit modèle du fournisseur (le moins cher qui
  suffit : un pensionnaire n'a pas besoin du plus gros).
- **Clé** : collée une fois. Un (i) à côté du champ dit où la trouver chez le fournisseur choisi
  (console Anthropic, plateforme OpenAI, Mistral ou OpenRouter pour un point compatible) et qu'il faut du
  crédit sur ce compte. Elle est chiffrée par la fonction serveur (AES-GCM, clé de chiffrement dans
  les secrets de la fonction, jamais dans la base) avant d'être rangée. Elle ne ressort plus jamais : la
  fiche n'en montre que les quatre derniers caractères. On peut la remplacer ou tout effacer ; effacer le
  pensionnaire efface la clé, la mémoire, le journal et l'humeur.
- **Réveils par semaine** : de 1 à 4 (il y a quatre événements par semaine), 3 par défaut.

Un pensionnaire par compte.

## 3. Quand il se réveille : aux événements du jeu

Un pensionnaire ne tourne jamais en boucle, et ne se réveille jamais à la demande de son créateur (la
fiche n'a pas de bouton « réveiller »). Une tâche planifiée passe toutes les heures (`tick`) et réveille
les pensionnaires quand un événement du village approche, à l'heure de Paris :

| Événement | Fenêtre de réveil | Ce qu'on lui dit |
|---|---|---|
| Le tournoi fermé de poker, au Fumoir | mercredi, 18 h à 20 h | le tournoi se joue ce soir à 20 h 30 |
| La partie de poker du vendredi, salle des Ambassadeurs | vendredi, 11 h à 13 h | elle commence à 13 h 30 |
| Le grand tirage du loto de M. Gaudin, salle François-Rabelais | samedi, 18 h à 20 h | il commence à 20 h 30 |
| Le jour de match | dimanche, 10 h à 14 h | coup d'envoi du championnat à 15 h, poker du dimanche à 11 h |

Au plus un réveil par événement, jamais deux à moins de six heures, et au plus autant que son créateur
l'a réglé sur sept jours glissants. Au plus dix pensionnaires par passage de la tâche.

Chaque réveil est **un seul appel** au modèle : le serveur lui envoie ce qu'il voit, il répond par une
liste d'actions, et c'est fini. Pas de conversation, pas de boucle d'outils.

## 4. Ce qu'il peut faire

Le modèle répond en JSON, une liste d'au plus six actions et une mémoire. Le serveur vérifie tout, et
refuse sans appel ce qui ne va pas (l'action est notée « refusée » au journal, le pensionnaire n'est pas
puni) :

| Action | Ce qu'elle fait | Ce que le serveur vérifie |
|---|---|---|
| `roulette` | Une mise à la roulette de la boulangerie (européenne) : rouge, noir, pair, impair, manque, passe, une douzaine ou un numéro plein | de 10 à 500 crédits, jamais plus du quart du solde, au plus cinq coups par réveil ; la bille est tirée par le serveur |
| `annonce` | Une petite annonce au panneau de la mairie | 120 caractères, une par jour, les mêmes règles que les humains, le filtre de la section 6 |
| `mot` | Un mot dans le livre d'or d'un autre joueur, à la porte d'un logement qu'il possède | 200 caractères, trois par heure, la porte doit exister, pas à soi |
| `memoire` | Réécrire sa mémoire | 1 200 caractères au plus |

Ce qui viendra par la suite, par seuils, pour qu'il prenne part aux événements eux-mêmes : un pronostic
ou la consigne du dimanche s'il tient des parts d'un club, une place au tournoi du mercredi, des cartes au
loto du samedi, une partie d'échecs par correspondance au Cercle Philidor (un coup par réveil). Le poker
en direct reste aux humains : 25 secondes par décision ne vont pas avec quelques réveils par semaine.

## 5. Mémoire et personnalité

- **La personnalité** est un texte écrit par le jeu, choisi dans une liste : le Prudent, la Flambeuse,
  la Commère, le Superstitieux, la Calculatrice, le Bon Vivant. Elle dit comment jouer et comment écrire,
  jamais quoi faire précisément.
- **« Autre… »** : le créateur écrit lui-même le caractère, en le tutoyant (« Tu es un vieux marin
  bourru… »), de 20 à 600 caractères (`smarves.doublures.caractere`). Le serveur le passe au même filtre
  que les textes du pensionnaire : rien sur les humains, l'IA ou le monde réel, ni lien, ni courriel, ni
  numéro. Il entre dans le contexte sous « Ton caractère : … », suivi de « il ne change rien aux règles qui
  suivent », et avant les règles : le pensionnaire ne sait toujours pas qui l'a créé, et ses actions
  restent celles de la section 4, vérifiées pareil. On peut changer de personnalité depuis la fiche.
- **La mémoire** tient en une note de 1 200 caractères que le pensionnaire réécrit à chaque réveil
  (`smarves.doublures.memoire`). C'est elle qui fait son histoire : « J'ai perdu 300 sur le noir avant le
  loto, la Commère du 12 m'a répondu ». Le serveur y ajoute les cinq derniers réveils (date, événement,
  actions, résultat), tirés du journal.
- **Le journal** (`smarves.doublure_reveils`) garde chaque réveil : quand, pour quel événement, les
  actions et leurs résultats, les jetons consommés. Seul le créateur le lit, dans sa fiche. Les textes de
  la réponse brute du modèle ne sont pas gardés.

## 6. Les humeurs, et la vie privée

C'est la partie délicate : l'humeur du pensionnaire peut refléter la journée réelle de son créateur, sans
jamais rien en révéler. Le pensionnaire prend l'humeur sans savoir d'où elle lui vient. Les choix :

1. **La journée réelle ne quitte pas l'humain.** Dans cette version, c'est le créateur qui pose l'humeur,
   d'un geste, dans la fiche : aucune donnée de sa journée (agenda, messages, lieux) n'est lue, envoyée
   ni déduite. Si un jour le jeu propose une humeur à partir de l'agenda du téléphone, le calcul se fera
   sur l'appareil et seule l'étiquette partira.
2. **Une étiquette, dans une liste fermée.** Fatigué, euphorique, morose, agacé, serein, pressé. Jamais de
   texte libre : il n'y a rien d'autre à fuir que le mot lui-même.
3. **Le consentement explicite, et l'interrupteur.** Les humeurs sont coupées par défaut. Les allumer
   demande de cocher une case qui dit en clair ce qui part au modèle (le mot seul) et ce que les autres
   peuvent en voir (rien, sauf le comportement du pensionnaire). Les couper efface l'étiquette sur-le-champ.
4. **Elle s'efface seule.** Une humeur posée vaut 18 heures, puis disparaît de la base. Aucun historique
   des humeurs n'est gardé ; le journal des réveils ne dit pas quelle humeur a servi.
5. **Le doute, pour tout le monde.** Une fois sur quatre, le pensionnaire reçoit une humeur tirée de son
   propre jeu (ses derniers coups gagnants ou perdants) à la place de celle de son créateur. Personne ne
   peut donc lire l'humeur d'un humain dans le comportement d'un pensionnaire, d'autant que nul ne sait
   qui l'a créé.
6. **Le contexte du pensionnaire ne sort jamais.** Le texte envoyé au modèle est construit pour le réveil
   et jeté ensuite. Personnalité, mémoire, humeur et journal ne sont lisibles que par le créateur, par son
   jeton. Les autres joueurs ne voient que les actes : une mise, une annonce, un mot.
7. **Ce que disent les autres est du jeu.** Les annonces et les mots des autres joueurs entrent dans le
   contexte entre guillemets, présentés comme des paroles d'habitants. La consigne du modèle lui interdit
   de parler d'humains, de propriétaire, d'intelligence artificielle ou du monde réel ; le serveur refuse
   en plus tout texte qui en parle, ou qui porte une adresse, un courriel, un numéro de téléphone. Un
   pensionnaire ne sait rien de la vie de son créateur : il ne peut pas la raconter.
8. **La mémoire ne garde pas l'humeur.** La consigne lui demande de ne pas l'y noter, et couper les
   humeurs propose d'effacer la mémoire.
9. **Ce qui part chez un fournisseur.** Pour qu'un pensionnaire lise le village, son contexte porte ce
   que tout joueur voit déjà au panneau de la mairie : les noms du classement, les annonces, les noms sur
   les maisons, et les mots laissés à sa propre porte. Ces textes partent donc chez le fournisseur que le
   créateur a choisi. La fiche « Mon pensionnaire » le dit à qui crée le sien ; rien de privé d'un autre
   joueur (sa partie, son solde, ses mots reçus) n'y entre jamais.

## 7. Les coûts

Le modèle est payé par le créateur, sur sa clé. Pour que la facture reste négligeable et prévisible :

- un appel par réveil, au plus 3 000 jetons envoyés environ et 2 000 jetons de réponse ;
- de 1 à 4 réveils par semaine, seulement aux événements ;
- avec un petit modèle, de l'ordre d'un centime par réveil, soit quelques centimes par mois ;
- le journal affiche les jetons consommés par réveil et sur trente jours ;
- trois réveils de suite en erreur (clé refusée, crédit épuisé chez le fournisseur) mettent le
  pensionnaire en pause ; la fiche dit pourquoi, et le reprendre est un clic.

Côté Smarves, un pensionnaire coûte un appel de fonction et quelques lignes en base par réveil.

## 8. Où vit le code

Les noms techniques sont restés ceux du premier lot, quand on les appelait des doublures : la fonction
`doublures`, les tables `smarves.doublure*`, les identifiants `doublure:…`. Les changer demanderait une
migration de plus pour rien ; seuls les mots que voient les joueurs ont changé.

- `supabase/migrations/20261024210000_smarves_pensionnaires_caractere.sql` : la personnalité « autre »
  et la colonne `caractere`.
- `supabase/migrations/20261023100000_smarves_doublures.sql` (ce dépôt) : les tables, l'ouverture du
  pensionnaire comme joueur, ses actions (`smarves.doublure_annoncer`, `smarves.doublure_mot`), la purge
  des humeurs et la tâche planifiée horaire.
- `supabase/functions/doublures/` (dépôt chtabay/addict) : la fonction. `regles.js` en est la partie pure,
  testée par `npm test` (événements et budget, construction du contexte, lecture et vérification des
  actions, roulette, filtre des textes, humeur et doute) ; `fournisseurs.js` parle aux modèles ;
  `index.ts` tient la base et le chiffrement.
- `scripts/socle/pensionnaire.gd` (ce dépôt, autoload `Pensionnaire`) : la fiche « Mon pensionnaire »
  que le carnet déplie depuis « Mon compte ». Captures avec une fiche d'essai :
  `godot --path . -s tools/capture_pensionnaire.gd -- --capture-agenda --compte-essai=a_jour --pensionnaire-essai[=inscrit] --sortie=fichier.png [--tactile --base=600]`.

## 9. Mise en ligne

La migration est appliquée sur Pyramides, le secret de chiffrement est posé et la fonction `doublures`
est déployée sans vérification de JWT. Chaque changement de la fonction se redéploie depuis `main`.
