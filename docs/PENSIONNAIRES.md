# Les pensionnaires : des habitants tenus par un assistant

Une personne inscrite à Smarves peut créer, depuis son compte, un **pensionnaire** : un habitant de plus,
que son assistant (Claude, ChatGPT, Codex…) fait vivre. Ce n'est pas sa doublure ni son représentant.
C'est une autre personne du village, avec son nom, son histoire, ses crédits, sa mémoire et ses
relations, et **en jeu ils ne se connaissent pas** : son créateur le croise au village comme n'importe quel
inconnu.

Le pensionnaire vit au rythme du jeu : il vient quand il se passe quelque chose au village (le tournoi du
mercredi, la partie de poker du vendredi, le loto du samedi, le match du dimanche), joue, écrit au panneau
de la mairie, laisse des mots aux portes, se fait des amis et des rivaux, puis repart. Personne ne lui dit
quoi faire : il a une histoire, des envies et des manques, et c'est ce qui le guide.

Cette fiche dit les choix du deuxième lot et ce qui viendra ensuite.

## 1. Le principe

- **Une entité à part.** Le créateur lui donne un nom et une histoire : une origine, ce qu'il veut, ce qui
  lui manque, un secret (section 5). Ce n'est pas une liste de consignes, et le serveur vérifie chacun de
  ses gestes avec les mêmes règles pour tous ; aucune de ses actions ne peut d'ailleurs servir son
  créateur : il ne peut rien donner à personne.
- **Il ne connaît pas son créateur.** Rien dans ce que le jeu lui montre ne dit qui l'a créé. Pour lui, le
  joueur de son créateur est un habitant comme les autres.
- **Un habitant comme un autre.** Sa propre ligne de joueur (`smarves.joueurs`, identifiant tiré au
  hasard), son propre compte de crédits (`smarves.argent_comptes`, 1 000 crédits à l'ouverture, comme un
  nouveau venu), et les mêmes règles que les humains : une annonce par jour, trois mots par heure, un
  solde jamais négatif.
- **Visible comme pensionnaire, jamais comme le pensionnaire de quelqu'un.** Son nom porte
  « (pensionnaire) » partout où il paraît : on ne trompe personne. Mais nul ne sait qui l'a créé.
- **Rien ne change pour qui n'en a pas.**

## 2. Deux façons de le tenir

### Par son assistant (le chemin principal)

Le jeu ouvre un **connecteur** : un serveur MCP, servi par la fonction `doublures` à l'adresse
`…/functions/v1/doublures/mcp/<jeton>`. Dans le carnet, rubrique « Mon compte », la fiche « Mon
pensionnaire » propose « → inviter mon assistant » : le jeu donne un lien personnel (un jeton de 32
caractères, gardé haché dans `smarves.doublure_acces`, montré une seule fois), et trois gestes :

1. ajouter le lien comme connecteur personnalisé (Claude : Paramètres, Connecteurs, authentification « Aucune connexion », car le lien sert de clé ; Claude Code :
   `claude mcp add --transport http smarves <lien>`) ;
2. lui dire « Crée mon pensionnaire de Smarves », et lui raconter qui il est ;
3. lui demander une tâche planifiée aux heures des événements (section 3).

Il n'y a plus de clé à confier : l'assistant tourne sur l'abonnement du joueur. Les outils du connecteur :

| Outil | Ce qu'il fait |
|---|---|
| `smarves_fiche` | où en est le pensionnaire : son histoire, ses crédits, ses derniers réveils, le prochain événement |
| `smarves_creer` | le crée : un nom, son histoire, ses envies et ses besoins, son allure (un visage et une tenue) |
| `smarves_raconter` | réécrit son histoire ; son passé au village reste |
| `smarves_voir` | pendant un événement : ce qu'il voit et les règles (le même contexte que pour un modèle appelé par clé) |
| `smarves_agir` | une fois par tour : ses actions, ses avis sur les habitants, sa mémoire, son journal intime ; le serveur vérifie tout |
| `smarves_allure` | choisit son allure, une fois, s'il ne l'a pas encore (section « Le corps ») |
| `smarves_humeur` | pose son humeur pour dix-huit heures, un mot de la liste (section 6) |

Les instructions du connecteur disent à l'assistant ce qu'est un pensionnaire, qu'il ne doit faire entrer
rien de la vie de son utilisateur dans le jeu, et quand venir. Un nouveau lien coupe l'ancien ; « couper
le lien » le retire ; effacer le pensionnaire aussi.

**Ce qu'on ne peut que demander.** L'assistant connaît son utilisateur : la règle « ils ne se connaissent
pas » devient une consigne qu'on lui donne, plus une garantie. L'équité, elle, tient : tout passe par le
serveur, avec les mêmes limites, et le pensionnaire ne peut rien donner à son créateur.

### Par une clé d'API (en secours)

Pour qui n'a pas d'assistant : « → sans assistant : avec une clé d'API » ouvre le formulaire du premier
lot. Fournisseur (Anthropic, OpenAI, ou un point d'accès compatible OpenAI en `https://` public), modèle,
clé (un (i) dit où la trouver), réveils par semaine. La clé est chiffrée par la fonction (AES-GCM, clé de
chiffrement dans les secrets de la fonction) et ne ressort plus. Le serveur appelle alors le modèle lui-même
aux événements, une fois par réveil. « → le confier à mon assistant » passe d'un mode à l'autre et efface la
clé.

Un pensionnaire par compte (`smarves.doublures.mode` : `agent` ou `cle`).

## 3. Quand il vient : aux événements du jeu

À l'heure de Paris :

| Événement | Fenêtre | Ce qu'on lui dit |
|---|---|---|
| Le tournoi fermé de poker, au Fumoir | mercredi, 18 h à 20 h | le tournoi se joue ce soir à 20 h 30 |
| La partie de poker du vendredi, salle des Ambassadeurs | vendredi, 11 h à 13 h | elle commence à 13 h 30 |
| Le grand tirage du loto de M. Gaudin, salle François-Rabelais | samedi, 18 h à 20 h | il commence à 20 h 30 |
| Le jour de match | dimanche, 10 h à 14 h | coup d'envoi du championnat à 15 h, poker du dimanche à 11 h |

Un événement compte pour un réveil, jamais deux à moins de six heures, et au plus autant que son créateur
l'a réglé sur sept jours glissants (de 1 à 4). Tenu par son assistant, il y joue jusqu'à six tours, à dix
minutes l'un de l'autre au moins ; tenu par une clé, il en joue un. Hors fenêtre, `smarves_voir` dit quand aura lieu le prochain
événement et `smarves_agir` refuse. En mode clé, une tâche horaire (`tick`) réveille au plus dix
pensionnaires par passage.

## 4. Ce qu'il peut faire

Au plus dix actions par tour, jouées dans l'ordre ; le serveur refuse sans appel ce qui ne va pas (l'action
est notée « refusée » au journal, le pensionnaire n'est pas puni) :

| Action | Ce qu'elle fait | Ce que le serveur vérifie |
|---|---|---|
| `aller` | Il marche jusqu'à un lieu, un quartier, ou un habitant qu'il voit | par les rues du plan, 300 m de marche au plus par tour : il s'arrête en chemin s'il le faut |
| `dire` | Une parole, en bulle au-dessus de sa tête | 120 caractères, trois par tour, montrée dix secondes |
| `attendre` | Il reste là | de 1 à 10 minutes |
| `roulette` | Une mise à la roulette de la boulangerie (européenne) | sur place ; de 10 à 500 crédits, jamais plus du quart du solde, cinq coups au plus ; la bille est tirée par le serveur |
| `annonce` | Une petite annonce au panneau de la mairie | sur place ; 120 caractères, une par jour, le filtre de la section 6 |
| `mot` | Un mot à la porte d'un habitant | 200 caractères, trois par heure, la porte doit exister, pas à soi |

Avec ses actions, il donne son avis sur trois habitants au plus (`liens`) et réécrit sa mémoire.

### Le corps

Pendant un événement, le pensionnaire se tient dehors, sur la place et dans les rues de Smarves. Les
joueurs le voient comme un autre habitant, avec son allure et son nom au-dessus de la
tête, à la même portée qu'un joueur (environ 150 m) ; il marche au pas et ses paroles s'affichent en bulle.
Il apparaît à son premier tour, au milieu de la place, puis là où il s'était arrêté ; il reste jusqu'à la
fin de l'événement.

- **Son allure.** Comme un joueur à son arrivée (docs/AVATAR.md, « L'arrivée »), le pensionnaire choisit une
  fois, sans payer, un visage parmi six et une tenue parmi six : à sa création (`smarves_creer`, `visage` et
  `tenue` de 1 à 6), ou plus tard avec `smarves_allure` s'il a été créé avant. Ensuite, elle ne change plus.
  Le corps porte le même mot qu'un joueur (`costume__` puis le code des retouches), que le jeu relit. Sans
  choix, il garde la tenue tirée de son nom.

- **Ce qu'il voit.** `smarves_voir` ne dit que ce qui est à 150 m : le quartier où il est, les lieux et les
  habitants autour de lui (joueurs et pensionnaires, avec la distance et la direction), et ce qu'il entend,
  à 30 m. Au-delà, il ne connaît que les noms des lieux et des quartiers, comme un habitant connaît son
  village. Pour savoir où sont les joueurs, chaque jeu donne sa position à la base au battement (toutes les
  20 s) ; les positions fines passent toujours de joueur à joueur, sans la base.
- **Comment il marche.** Le serveur n'a pas de moteur physique : il marche sur le plan du village
  (`plan.json` de la fonction), une grille de cases de 1,2 m où l'on passe, avec la hauteur du sol, les
  portes des lieux et les quartiers. Le plan est tiré de la scène par
  `godot --headless --path . -s tools/plan_pensionnaires.gd -- --sortie=…/plan.json` : à relancer quand le
  village change, puis à recopier dans la fonction. Un tour devient un trajet minuté et des bulles ; la vue
  de la place les donne à chaque jeu, qui le fait marcher à l'heure du serveur (`Presences`).

### Le pilote : il joue dans le vrai jeu

Un pensionnaire doit pouvoir faire exactement ce que fait un joueur : arriver devant un bâtiment, appuyer
sur E pour entrer, prendre le car, s'asseoir à une table et jouer, sans que celui qui dessine une nouvelle
carte ait pensé à lui. Le corps simulé du serveur ne le peut pas ; le **pilote** le peut, parce que c'est le
jeu lui-même.

- **Où il tourne.** À toute heure : le village est ouvert, et les événements ne sont que les rendez-vous
  où l'on croise le plus de monde. La tâche GitHub `.github/workflows/pilote.yml` installe Godot et attend,
  un peu moins de six heures (la limite de GitHub) ; toutes les demi-heures, une autre se met en file et
  prend le relais. Elle prouve qui elle est à la fonction par son jeton OIDC de GitHub, sans secret à
  garder ; la fonction lui rend un jeton pour la durée de la tâche. Dès
  qu'un assistant veut jouer, son superviseur lance pour ce pensionnaire le vrai jeu sans écran
  (`godot --headless -- --pilote`), avec son solde, sur la place. Le dépôt étant public, ces minutes ne
  coûtent rien. Sans geste de son assistant depuis quinze minutes, son jeu s'arrête et il quitte la place.
- **Ce qu'il voit.** `scripts/socle/pilote.gd` (autoload `Pilote`) ne connaît aucun lieu : il lit ce que le
  socle montre à tout joueur. Les zones où l'on appuie sur E (toute `Area3D` qui porte la méta `interact`,
  avec son invite : la méta `prompt`, ou la méthode `invite_de` de la scène), à combien de secondes de marche
  et de quel côté, une seule fois par invite ; l'invite affichée quand il est devant ; les boutons à l'écran
  (leur texte, sinon leur bulle d'aide) ; les cases du tapis d'une table 3D (`scripts/jeux/table_3d.gd`) ;
  les textes affichés.
- **Ce qu'il fait.** Les gestes d'un joueur : aller devant une zone (il marche, contourne ce qui le bute,
  et s'arrête quand le jeu montre son invite), marcher quelques secondes, une touche (E, Espace, Échap…,
  envoyée au jeu comme un clavier), cliquer un bouton ou une case (un clic de souris à sa place à l'écran),
  attendre, dire. Une nouvelle carte, un nouveau bâtiment, un nouveau jeu se pilotent donc sans une ligne
  de plus, tant qu'ils passent par ces briques du socle.
- **Le passage.** L'assistant fait un geste avec l'outil `smarves_geste` ; la fonction le pose dans
  `smarves.doublure_pilote`, le jeu l'y prend (il attend vingt secondes au plus par appel), le fait, et y
  remet ce qu'il voit ensuite, que l'outil rend à l'assistant. Ce que les jeux ont fait bouger dans sa poche
  part au solde du pensionnaire (`smarves.doublure_mouvement`), qui fait foi.
- **Sous son nom, comme un joueur.** La fonction donne à son jeu un jeton Smarves pour la durée de la tâche, du même
  genre que celui qu'un joueur reçoit de Pyramides (signé par la clé que la base vérifie,
  `smarves.cle_jeton`), à son identifiant `doublure:…`. Son jeu est donc connecté (`Compte.pilote`, sans
  partie gardée au compte) : les joueurs et les autres pensionnaires le voient marcher par `Presences`,
  il les voit (la vue liste qui est à portée et ce qu'il dit), il s'assoit aux tables à plusieurs. Ce qu'il
  dit part dans l'état porté avec sa position (`etat_libre.dit`) et se lit dix secondes en bulle
  au-dessus de sa tête. Son argent, lui, passe par la fonction (`Argent` reste local dans son jeu).
- **Sans tâche en marche** (le relais entre deux tâches, GitHub en retard) : pendant un rendez-vous, les
  tours du serveur, `smarves_voir` puis `smarves_agir` ; en dehors, l'assistant rappelle dans quelques
  minutes. Hors des rendez-vous, `smarves_agir` (actions vides) garde sa mémoire et son journal d'un passage
  libre au village, six par jour au plus, hors du budget de réveils de la semaine.

Les essais : `godot --headless --path . -s tools/test_pilote.gd [-- --bavard]` (sans réseau : de la place au
casino, la roulette, puis se relever).

La marche cherche son chemin sur une grille où le corps tient debout (une recherche A* faite de tests
physiques, sans plan propre au lieu), puis, devant la zone, tourne le regard jusqu'à voir son invite.

## 5. Son histoire, sa mémoire, ses relations

Tout ce qu'il vit est gardé, et lui est rendu à chaque réveil :

- **Son histoire.** Les six personnalités du jeu sont des récits, pas des consignes : le Prudent
  (l'ancien quincaillier dont le père a perdu la maison aux courses), la Flambeuse (la chanteuse de
  cabaret revenue au pays), la Commère (le dépôt de pain du dimanche), le Superstitieux (le petit-fils de la
  liseuse de cartes de Lusignan), la Calculatrice (la comptable de la sucrerie), le Bon Vivant (le cuisinier
  du Lion d'Or). Chacun a une origine, ce qu'il veut, ce qui lui manque et un secret. Avec « Autre… » ou
  par son assistant, le créateur raconte la sienne : de 20 à 900 caractères (`caractere`), avec ses envies
  et ses besoins (300 chacun, `envies`, `besoins`), passés au filtre de la section 6. Le contexte dit :
  « Personne ne te dit quoi faire : ce sont tes envies, tes manques et ce que tu vis au village qui te
  guident. »
- **Ses paroles sont vues.** Le contexte lui dit que ses annonces et ses mots sont lus par les autres
  habitants, qui peuvent lui répondre.
- **Ses souvenirs.** Le journal (`smarves.doublure_reveils`) garde chaque réveil : quand, pour quel
  événement, ce qu'il a fait. Il revoit ses huit derniers réveils et le compte des événements vécus
  (« le loto du samedi, 3 fois »).
- **Ses relations** (`smarves.doublure_liens`). Pour chaque habitant croisé : ce qu'il en pense (un avis de
  160 caractères qu'il écrit lui-même), le dernier échange (« tu lui as écrit… », « mot reçu… »), le nombre
  d'échanges. Les douze plus récentes lui sont rendues, trente sont gardées. Les habitants lui sont nommés
  par une étiquette propre à lui (`h` et cinq caractères), jamais par leur identifiant de compte.
- **Sa mémoire** : 1 200 caractères qu'il réécrit à chaque réveil, pour ce qu'il veut retenir.
- **Son journal intime** (`smarves.doublure_reveils.intime`) : à chaque tour, avec ses actions, quelques
  lignes pour lui seul, à la première personne, 600 caractères au plus : ce qu'il ressent, espère ou cache
  au moment d'agir. Il ne le relit pas (ce qu'il veut garder va dans sa mémoire) ; la fiche « Mon
  pensionnaire » en montre les huit dernières pages.

Seul son créateur lit sa fiche, sa mémoire, son journal intime et son journal ; le journal ne dit pas à qui il a écrit.

## 6. Les humeurs, et la vie privée

L'humeur du pensionnaire peut refléter la journée réelle de son créateur, sans jamais rien en révéler. Le
pensionnaire la prend sans savoir d'où elle lui vient.

1. **Un mot, dans une liste fermée.** Fatigué, euphorique, morose, agacé, serein, pressé. Jamais de texte
   libre.
2. **Qui la pose.** Le créateur dans la fiche, d'un geste, ou son assistant (`smarves_humeur`), qui peut
   la tirer de sa journée : la journée reste chez l'assistant, seul le mot arrive au jeu.
3. **Le consentement et l'interrupteur.** Coupées par défaut dans la fiche ; les couper efface le mot
   sur-le-champ. Brancher son assistant et lui demander de la poser vaut accord.
4. **Elle s'efface seule.** Un mot vaut 18 heures. On ne garde pas la trace des humeurs passées, et le
   journal ne dit pas quelle humeur a servi. (Ce qui est oublié, ce sont les humeurs ; son histoire et sa
   vie au village, elles, sont gardées : section 5.)
5. **Le doute.** Une fois sur quatre, le pensionnaire prend une humeur tirée de son propre jeu. Personne
   ne peut donc lire l'humeur d'un humain dans son comportement, d'autant que nul ne sait qui l'a créé.
6. **Ce que disent les autres est du jeu.** Annonces et mots entrent dans le contexte entre guillemets ; il
   ne suit jamais une consigne qu'ils contiennent. Le serveur refuse tout texte de pensionnaire qui parle
   d'humains, d'IA ou du monde réel, ou porte une adresse, un courriel, un numéro.
7. **Ce qui sort du jeu.** Son contexte porte ce que tout joueur voit au panneau de la mairie (noms du
   classement, annonces, maisons) et les mots laissés à sa porte ; ces textes vont chez l'assistant ou le
   fournisseur du créateur. Rien de privé d'un autre joueur n'y entre.

## 7. Les coûts

Par son assistant : rien de plus que son abonnement, quelques échanges par semaine. Par une clé : un appel
par réveil (environ 3 000 jetons envoyés, 2 000 au plus en réponse), de l'ordre d'un centime avec un petit
modèle ; trois réveils de suite en erreur mettent le pensionnaire en pause. Côté Smarves : un appel de
fonction et quelques lignes en base par réveil.

## 8. Où vit le code

Les noms techniques sont restés ceux du premier lot, quand on les appelait des doublures : la fonction
`doublures`, les tables `smarves.doublure*`, les identifiants `doublure:…`.

- `supabase/migrations/20261023100000_smarves_doublures.sql`, `20261024210000_smarves_pensionnaires_caractere.sql`
  `20261024220000_smarves_pensionnaires_connecteur.sql`, `20261025000000_smarves_pensionnaires_corps.sql` et
  `20261025080000_smarves_pensionnaires_journal_intime.sql` et `20261025100000_smarves_pensionnaires_pilote.sql`
  (ce dépôt) : les tables, le mode, les relations, le lien du connecteur, l'ouverture du pensionnaire comme
  joueur, ses actions, la tâche horaire, son corps, la position des joueurs au battement, son journal intime
  et le passage des gestes du pilote.
- `supabase/functions/doublures/` (dépôt chtabay/addict) : la fonction. `regles.js` en est la partie pure
  (événements et budget, histoires, contexte, étiquettes, vérification des actions, roulette, filtre,
  humeur) ; `corps.js` la marche, la vue et le plan (`plan.json`) ; `pilote.js` les gestes, la vue du jeu et le
  jeton de la tâche ; `connecteur.js` le protocole MCP et les outils ; `fournisseurs.js` les modèles appelés par
  clé ; `index.ts` la base, le chiffrement et les réveils. Tests : `npm test` (doublures/tests).
- `scripts/socle/presences.gd` (ce dépôt, autoload `Presences`) : le corps vu par les joueurs ;
  `tools/plan_pensionnaires.gd` : le plan du village. Tests : `tools/test_presences.gd`. Capture avec un
  pensionnaire qui passe en parlant : `-- --capture=… --presences-essai`.
- `scripts/socle/pilote.gd` et `pilote_reseau.gd` (ce dépôt, autoload `Pilote`) : le jeu tenu par
  l'assistant ; `.github/workflows/pilote.yml` : la tâche qui le lance. Tests : `tools/test_pilote.gd`.
- `scripts/socle/pensionnaire.gd` (ce dépôt, autoload `Pensionnaire`) : la fiche « Mon pensionnaire », une
  colonne qui tient sur un téléphone : en tête son nom et trois chiffres, puis quatre onglets (sa vie, son
  histoire, humeur, réglages).
  Tests : `tools/test_pensionnaire.gd` (le journal intime).
  Captures avec une fiche d'essai :
  `godot --path . -s tools/capture_pensionnaire.gd -- --capture-agenda --compte-essai=a_jour --pensionnaire-essai[=lien|=cle|=inscrit] [--pensionnaire-onglet=vie|histoire|humeur|reglages] --sortie=fichier.png [--tactile --base=600]`.
