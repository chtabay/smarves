# Les activités transverses : le point et le modèle

Ce document fait deux choses. D'abord le point sur l'expérience des activités qui vivent au rythme de la semaine (le football et tout ce qui l'entoure, le loto, le poker) : ce qui marche, ce qui coince, ce qui diffère d'une activité à l'autre sans raison. Ensuite le **modèle** qu'une nouvelle activité reprend (basket, courses, pétanque…) : les briques communes, ce que le socle fournit, ce que l'activité apporte, et la fiche de la première à construire.

Il part de la demande de Guillaume du 18 octobre 2026 : « faire un point UX/UI surtout pour les activités transverses […] et en tirer des leçons pour créer d'autres activités comme le basket, les courses de chevaux ou la pétanque sur le modèle du foot ». Rien ici n'est construit : c'est la règle que suivront les prochains chantiers. La fiche de cadrage ([`CADRAGE.md`](CADRAGE.md)), la bible ([`BIBLE.md`](BIBLE.md)) et la suite ([`SUITE.md`](SUITE.md), section 6 pour le football) l'emportent en cas de doute.

## Ce qu'on appelle une activité transverse

Smarves a deux sortes de jeu, qui n'ont pas la même horloge.

| | Les jeux | Les activités transverses |
|---|---|---|
| Exemples | la Smarvoise, le blackjack du Moulin, le loto instantané de M. Gaudin, les tables du casino | le championnat de la Vienne, ses paris, son mercato ; demain le grand tirage du samedi, le tournoi du mercredi, un concours de pétanque |
| Horloge | **le joueur** : une mise, un tirage, tout de suite | **le calendrier réel** : un rendez-vous fixe, le même pour tout le monde |
| Hasard | tiré sur l'appareil, à chaque mise | tiré d'une **graine commune** et des décisions posées avant l'heure : tout le monde a le même résultat |
| Lieu | une salle du village | un lieu déclaré comme **structure** par une commune, relié aux autres par le registre |
| Argent | mise et gain immédiats | paris réglés à heure fixe, parts ou obligations et leurs dividendes, achats (recrues) |

Une activité transverse est donc **un rendez-vous partagé, dans un lieu, avec de l'argent autour**. Tout ce qui suit sert à ce que le joueur comprenne ces quatre choses sans qu'on les lui explique : quand c'est, où c'est, ce que ça a donné, et ce que ça lui a coûté ou rapporté.

## 1. Le point UX

Parcours joués sur la version de bureau (1600 × 900) et en largeur téléphone (1067 × 600, `--tactile --base=600`), captures dans `/mnt/project-files/ux-activites/` et dans les fils du football. État de `main` au 18 octobre 2026 au soir (après la PR #113).

### Le parcours du football aujourd'hui

1. **1 000 gagnés** : Josiane accroche l'ardoise au mur du café. E l'ouvre : classement, dernière journée, prochaine, coup d'envoi (`FootTableau`).
2. **2 000 gagnés** : le carnet du PMU sur le zinc. E l'ouvre : la journée à venir, 1 N 2, la mise, les tickets (`FootParis`, autoload `Paris`).
3. **3 000 gagnés** : le stade s'ouvre sur la route du Bois. Le match en direct le dimanche à 15 h, le tableau d'affichage et sa feuille, le président Chauvin et sa causerie (consignes), le mercato depuis la causerie (`stade.gd`, `FootCauserie`, `FootMercato`).
4. Au même seuil, **Maître Garnier** cède des parts de l'Étoile à l'étude (`Biens`, id `etoile`) ; le premier actionnaire parle au président.

### Ce qui marche

- **Les entrées sont dans le monde.** Une ardoise, un carnet sur le zinc, un président au bord du terrain, un notaire : on s'approche, E, la fenêtre s'ouvre. Pas de menu « Football » abstrait, et c'est ce qui rend le championnat crédible dans un village.
- **L'échelle des seuils est la bonne** : lire (1 000), parier (2 000), voir et décider (3 000), posséder (parts). Chaque marche est annoncée par une personne (« Josiane accroche une ardoise… ») au moment où elle s'ouvre.
- **Le résultat est le même pour tous, et les fenêtres le disent** : une consigne « locale » ou « au championnat », qui l'a posée, ce qui manque (le compte). C'est la meilleure part du travail : le joueur sait toujours si ce qu'il fait compte pour les autres.
- **Une famille de fenêtres** : l'ardoise (`FootTableau` et ses filles), sa craie, son or, son bouton de sortie qui est un geste (« Reposer le stylo (Échap) »). Sur un téléphone, elle tient dans l'écran et défile.
- **La morale sort des chiffres** : le bilan des tickets (« misés, repris : les chiffres le disent, Josiane ne dit rien »).

### Ce qui coince

| # | Constat | Où | Gravité |
|---|---|---|---|
| 1 | **Le rendez-vous ne se voit qu'au café et au stade.** L'heure du match n'est écrite que sur l'ardoise et dans la causerie. Le panneau de la mairie annonce les parties de poker, pas le match. Au stade, hors du dimanche, une note passagère en bas de l'écran (« L'Étoile s'entraîne sous les projecteurs. Journée 1 : coup d'envoi dimanche 25 octobre à 15 h ») s'efface au bout de quelques secondes. Le fil « Agenda » y répond par le carnet. | `foot_tableau.gd`, `voisinage.gd` (`RENDEZ_VOUS`), `stade.gd` | forte |
| 2 | **Deux horloges pour un même club.** La rente d'une part de l'Étoile tombe « par recette », c'est-à-dire toutes les 20 mises au casino, pas après les matchs : le club paie quand le joueur joue à la machine, pas quand il gagne le dimanche. Les obligations en cours de construction (dividende par journée) corrigent cela. | `biens.gd` (`_recette`), `football.gd` (`recette_facteur`) | forte |
| 3 | **Un pari gagné ne se sait qu'en entrant au café.** `Paris.regler()` n'est appelé qu'à l'entrée de la salle. Le joueur resté au stade à 17 h, ou parti au casino, n'apprend rien et ne touche rien. | `salle.gd` (`_regler_paris`) | forte |
| 4 | **Tu et vous mélangés.** Le jeu vouvoie le joueur partout (Josiane, le loto « Cochez vos numéros », l'annonce de la place, le notaire « Vos crédits »). Les fenêtres du football le tutoient (« Tu as 2 000 crédits », « connecte-toi », « Tes consignes »), et le mercato fait les deux dans la même fenêtre (« Vous tenez 2 parts » puis « Tu as … crédits »). | `foot_*.gd`, `football.gd` (`phrase_actionnaires`) | moyenne |
| 5 | **La rente des parts parle de « recette »**, un mot que le joueur n'a pas rencontré au stade : « Rente annoncée : 150 par recette, selon le classement ». | fiche du notaire, `biens.gd` | moyenne |
| 6 | **Sur un téléphone, les fenêtres passent sous le bouton « Sortir » et le compteur.** Le mercato, le tableau du dimanche et le carnet du PMU montent jusqu'en haut de l'écran : le bouton « Sortir » recouvre leur coin droit, le compteur de crédits leur coin gauche ; le bouton de fermeture du mercato n'apparaît qu'en bas du défilement. | `foot_tableau.gd` (`_ajuster`) | moyenne |
| 7 | **Les noms longs sont coupés là où un nom court existe.** Le carnet du PMU écrit « Avenir de Roches-Prémar… », alors que le registre a « RPA » et que le tableau du dimanche sait mettre le code devant le nom. | `foot_paris.gd` (`_rangee_match`) | faible |
| 8 | **Le direct se lit mal.** Au stade, le score n'est que sur le tableau d'affichage au fond, illisible à cette distance ; la minute n'est nulle part. On suit le match par la ligne du commentateur. | `stade.gd` | moyenne |
| 9 | **Le poker a trois adresses.** La table jouable est aux Ambassadeurs (casino, seuil 500, contre les habitués) ; le panneau annonce « la partie de poker du vendredi » à Passelourdin ; l'agenda va annoncer le tournoi fermé du mercredi au Fumoir. Sans règle, le joueur ne sait pas où aller pour jouer contre d'autres. | `voisinage.gd`, `casino_interior.gd` | moyenne |
| 10 | **Le « grand loto du samedi soir » se joue à toute heure**, tiré sur l'appareil. Le nom promet un rendez-vous, la mécanique est celle d'une machine. | `loto_panel.gd`, `salle.gd` | faible (la règle de la première salle le veut ; voir la brique 1) |
| 11 | **Rien ne rassemble ce qu'on a engagé.** Tickets ouverts au café, parts chez le notaire, consigne au stade, recrue au mercato : pour savoir où l'on en est, il faut faire le tour du village. | carnet | moyenne |
| 12 | **Deux familles de fenêtres.** Les jeux (loto, poker, blackjack, l'ancien panneau des paris de pétanque) ont leurs panneaux à titre doré ; les activités ont l'ardoise. C'est justifié (une table n'est pas un tableau d'affichage), mais une nouvelle activité doit savoir laquelle prendre. | `*_panel.gd`, `foot_tableau.gd` | faible |

Le panneau des paris « à cote du village » (`race_panel.gd` : la pétanque de Lucien et la course des trois zèbres) n'est plus ouvert nulle part depuis qu'on ne joue plus dehors. C'est un prototype tout prêt pour les paris d'une activité, pas une dette.

### Ce qui diffère sans raison

| | Football aujourd'hui | Ce qu'il faudrait partout |
|---|---|---|
| Voix | tu dans les fenêtres, vous dans les bouches | **vous** partout (la voix du jeu depuis Addict) |
| Règlement d'un pari | à l'entrée du café | **où que l'on soit**, avec la fiche du carnet, et Josiane le redit au café |
| Rente du club | par recette (20 mises) | **par rendez-vous** (la journée jouée) |
| Prochain rendez-vous | ardoise et causerie | **partout où l'activité se montre**, plus l'agenda |
| Nom d'un club | complet et coupé, ou code + nom selon la fenêtre | **code + nom** quand la place manque |

Les corrections précises, fenêtre par fenêtre, sont transmises aux fils qui tiennent ces fichiers (voir la fin du document).

## 2. Le modèle d'une activité transverse

Une activité est faite de **neuf briques**. Le socle en fournit l'essentiel ; l'activité n'apporte que ce qui lui est propre (son moteur, son lieu, ses mots). Pour chaque brique : la règle, ce qui existe, ce qu'une activité nouvelle fournit.

### Brique 1. Le rendez-vous, au vrai calendrier

**Règle.** Une activité a des rendez-vous **fixes dans la semaine, à l'heure de France**, les mêmes chez tout le monde : le match le dimanche à 15 h, le grand tirage le samedi à 20 h 30, le tournoi le mercredi à 20 h 30. Un rendez-vous a un début, une durée, une heure de règlement, et une **fenêtre de décision** qui se ferme au début (consignes, inscriptions, tickets). Hors ligne, le calendrier se calcule sans serveur.

**Ce qui existe.** `Football.prochain_coup_envoi`, `coup_envoi(s, j)`, `HEURE_COUP_ENVOI`, `REGLEMENT` (Paris) ; les rendez-vous du panneau (`Voisinage.RENDEZ_VOUS`) ; l'autoload **Agenda** que construit le fil « Agenda des évènements de la semaine », où chaque activité inscrit ses rendez-vous et que le carnet affiche.

**Ce que l'activité fournit.** Une fonction `rendez_vous(de, a)` qui rend `[{id, quoi, ou, lieu, quand, duree, reglement}]`, inscrite à l'Agenda. Rien d'autre ne lit l'heure de l'activité : ni le panneau, ni le carnet, ni le lieu n'ont leur propre table d'horaires.

**Le jeu et l'activité vivent côte à côte.** Quand un jeu du village porte déjà le nom d'un rendez-vous (le loto de M. Gaudin), le jeu reste tel quel, à toute heure : c'est la règle de la première salle. Le rendez-vous s'ajoute à côté, derrière son seuil (« le grand tirage du samedi », des cartons achetés dans la semaine, tirés à 20 h 30 pour tout le monde).

### Brique 2. Le résultat commun

**Règle.** Le résultat d'un rendez-vous se tire d'une **graine qui ne dépend que de l'activité, du rendez-vous et des concurrents**, plus des **décisions posées avant l'heure**. Le serveur ne calcule rien : il tient les décisions, refuse celles qui arrivent après l'heure, et chaque jeu rejoue le même résultat. Jamais de `randi()` dans une activité.

**Ce qui existe.** `Hasard` (mulberry32 du Vestiaire, `scripts/socle/hasard.gd`) ; `Football.rencontre`, `resultat`, `decider`, `appliquer_consignes` ; les tables `smarves.consignes`, `smarves.parts`, `smarves.transferts` et leurs fonctions, qui refusent hors délai.

**Ce que l'activité fournit.** Son moteur (`resultat(rdv)` déterministe), la liste de ses décisions et leur fenêtre, et une table de décisions au serveur sur le modèle de `smarves.consignes` (une migration, soumise à Guillaume). Le temps réel n'est nécessaire que pour une activité où les joueurs s'affrontent eux-mêmes (le poker) ; tout le reste se contente de décisions posées avant l'heure.

### Brique 3. Le lieu, déclaré comme structure

**Règle.** Une activité qui oppose des communes naît d'une **structure** : une commune déclare un terrain, un boulodrome, une salle des fêtes dans son manifeste, et le registre lui donne un club ou une place dans la compétition (`SUITE.md`, section 6). Dans Smarves, le lieu est **nouveau et derrière un seuil** : rien ne change sur la place ni dans la première salle.

Chaque lieu offre au moins trois points d'interaction, toujours dans cet ordre de lecture :

1. **L'affiche** lisible de loin (ardoise, tableau d'affichage) : le prochain rendez-vous et le dernier résultat, à la craie, sans ouvrir de fenêtre ;
2. **La personne qui parle pour l'activité** (le président, l'arbitre, le maître de cérémonie) : les décisions, la direction ;
3. **La place du direct** (la tribune, le bord du terrain) : là où l'on regarde le rendez-vous.

Les paris ne se prennent pas sur le lieu mais **au comptoir du café** (Josiane) : c'est le seul guichet de paris du village, quelle que soit l'activité.

**Ce qui existe.** `Structures` (`gare`, `arret_car`, `terrain_foot`), `Registre.relies`, `Football` qui lit les terrains du registre ; le stade (`stade.gd`) comme lieu type.

**Ce que l'activité fournit.** Un type de structure (un champ dans `Structures`, la version du socle qui monte), la scène de son lieu, son tenancier, ses noms.

### Brique 4. Les paris

**Règle.** Des paris à **cotes fixes, les mêmes pour tous**, calculées des probabilités du moteur moins **12 % de marge** pour la maison ; simples ou combinés ; **mise libre** (la seule limite est la bourse) ; la mise part tout de suite et compte dans le total misé, le gain compte dans le total gagné au jeu. Un ticket se règle à l'heure de règlement du rendez-vous, **où que soit le joueur** : la fiche du carnet glisse (`Carnet.show_slip`), et Josiane le redit à l'entrée du café. Le bilan depuis le début reste affiché sous les tickets.

**Ce qui existe.** L'autoload `Paris` et `FootParis`, pensés pour le football (`cle(dom, ext)`, issues 1 N 2).

**Ce que l'activité fournit.** Ses issues et leurs probabilités pour un rendez-vous : `issues(rdv) -> [{cle, libelle, probabilite}]` (un vainqueur parmi huit, un score de mène, une place). La généralisation de `Paris` (ticket = activité + rendez-vous + issues) se fait au moment où la deuxième activité arrive, pas avant.

### Brique 5. Les parts, les obligations et les dividendes

**Règle** (en cours de construction par le fil football, modèle Impérial 2030). Un club est à ses porteurs : des **obligations de tailles différentes**, chacune en un seul exemplaire par club, cédées par Maître Garnier ; **la plus grosse somme investie** donne la direction (consignes, recrues) ; chaque obligation verse un **dividende à chaque rendez-vous joué**, proportionnel à sa taille et aux résultats du club. Le club n'a pas de caisse : ce qu'il achète se paie de la poche de celui qui dirige, et les salaires se déduisent des dividendes.

**Ce qui existe.** `Biens.CATALOGUE` (vendeur `notaire`), `Football.peut_decider`, `phrase_actionnaires`, `smarves.parts` ; bientôt les obligations et `smarves.dirige(club, joueur)`.

**Ce que l'activité fournit.** `facteur_dividende(club, rdv)` (le football : la forme au classement ; un concours : le tour atteint) et ce que la direction décide. Le dividende tombe **sur l'horloge de l'activité**, jamais sur celle des recettes du village.

### Brique 6. La fiche de résultats

**Règle.** Chaque rendez-vous joué a sa **fiche**, la même chez tout le monde : le résultat en tête, les chiffres, le récit. On la lit à deux endroits au moins : sur l'affiche du lieu (E devant le tableau) et au café. Elle reste lisible tant que le rendez-vous suivant n'a pas eu lieu.

**Ce qui existe.** La feuille de match (`FootTableau`, bouton « la feuille », tableau d'affichage du stade).

**Ce que l'activité fournit.** `feuille(rdv)` : `{titre, resultat, chiffres: [[libelle, a, b]], recit: [lignes]}`, que la fenêtre commune met en page.

### Brique 7. Le direct

**Règle.** Un rendez-vous se regarde **en direct, à l'heure réelle**, sur son lieu, avec les figurants ; on arrive en cours de route et on reprend où il en est. Le direct ne se revoit pas (décision de Guillaume du 18 octobre pour le football) : après, il reste la fiche. Pendant le direct, un **bandeau** en haut de l'écran donne ce que la scène ne peut pas montrer de loin : qui contre qui, le score, la minute (ou la mène, la manche), le dernier fait marquant.

**Ce qui existe.** `Football.rencontre_en_direct`, les scènes du stade (`_scene`, `_jouer_scenes`), la ligne du commentateur. Pas de bandeau.

**Ce que l'activité fournit.** Son état à l'instant t (`en_direct(rdv, t)`), ses scènes, et les trois champs du bandeau.

### Brique 8. La fenêtre et la vue mobile

**Règle.** Les fenêtres d'activité sont des **ardoises** (la famille de `FootTableau`) : fond d'ardoise, craie, or pour ce qui compte, petit titre espacé en capitales au-dessus du grand. Les tables de jeu gardent leurs panneaux. Sur un téléphone, l'ardoise **tient dans l'écran sous la barre du haut** (le compteur à gauche, « Sortir » à droite), défile si elle est plus haute, et garde son bouton de sortie visible ; les rangées de boutons passent à la ligne ; un nom long cède la place au code du club.

**Ce qui existe.** `FootTableau._preparer`, `_ajuster`, `_etroit`, `_large`, `_mot`, `_bouton`, `_boite`, `_filet` : tout y est, mais dans un fichier du football.

**Ce que le socle devra faire** à l'arrivée de la deuxième activité : sortir ces pièces dans une classe du socle (`Ardoise`, `scripts/socle/ardoise.gd`) dont `FootTableau` héritera, sans rien changer à l'écran. C'est un déplacement, pas une réécriture ; il se fait dans le fil qui tient le football ou avec son accord.

### Brique 9. Les mots et l'argent

- **Vous** partout, à l'écran comme dans les bouches. Les personnages ont leur voix (Josiane, Chauvin, Garnier), l'interface n'en a pas d'autre que celle du jeu.
- **Chaque somme dit ce qu'elle est** : une mise, un gain, un dividende, un prix. Jamais « recette » pour une activité.
- **Chaque fenêtre dit si ce qu'on y fait compte pour les autres** (« au championnat », « sur cet appareil seulement ») : c'est la phrase qui a le mieux marché au football.
- **La morale sort des chiffres** : un bilan depuis le début, sans commentaire. Personne ne fait la leçon.
- **Le bouton de sortie est un geste** (« Reposer le stylo », « Laisser le président ») suivi de « (Échap) ».

### L'ordre des seuils d'une activité

Toute activité s'ouvre dans le même ordre, chaque marche annoncée par une personne :

1. **Lire** : l'affiche au café (le prochain rendez-vous, les derniers résultats) ;
2. **Parier** : les issues du prochain rendez-vous au comptoir de Josiane ;
3. **Voir** : le lieu s'ouvre, le direct, la fiche, la personne qui parle pour l'activité ;
4. **Posséder** : les obligations chez Maître Garnier, la direction, les dividendes.

Les montants dépendent de l'activité, mais une activité nouvelle ouvre ses marches **après** celles du football, pour ne pas tout déverser sur le joueur à 3 000 gagnés.

### Ce que rassemble le carnet

Une page **« Mes engagements »** du carnet (à côté de l'agenda du fil « Agenda ») liste, pour toutes les activités : les tickets ouverts et leur heure de règlement, les obligations tenues et le dernier dividende, les décisions posées pour le prochain rendez-vous (et si elles comptent pour tout le monde), les clubs que l'on dirige. On n'y agit pas : chaque ligne dit où aller.

### Le contrat d'une activité, en code

Ce que le socle attendra d'une activité, quand la deuxième arrivera (le football en est la première implémentation, sous d'autres noms) :

```gdscript
# Une activité transverse : un autoload du socle, une par activité.
var id: String                 # "football", "petanque"
var structure: String          # le type de structure qui donne une place : "terrain_foot", "boulodrome"

func rendez_vous(de: int, a: int) -> Array        # brique 1 : [{id, quoi, ou, lieu, quand, duree, reglement}]
func concurrents(rdv: String) -> Array            # brique 3 : lus au Registre
func decisions_ouvertes(rdv: String) -> bool      # brique 2 : avant l'heure seulement
func decider(rdv: String, club: String, d: Dictionary) -> void
func resultat(rdv: String) -> Dictionary          # brique 2 : déterministe (graine + décisions)
func issues(rdv: String) -> Array                 # brique 4 : [{cle, libelle, probabilite}]
func gagnante(rdv: String, cle: String) -> bool   # brique 4 : le règlement d'un ticket
func facteur_dividende(club: String, rdv: String) -> float   # brique 5
func feuille(rdv: String) -> Dictionary           # brique 6
func en_direct(rdv: String, t: int) -> Dictionary # brique 7 : l'état à l'instant t, et le bandeau
```

**Alternatives écartées.** Un moteur générique de compétitions qui ferait le football, le basket et la pétanque par paramètres : chaque sport a sa forme de jeu, et c'est elle qui rend le direct vivant ; on partage le calendrier, l'argent et les fenêtres, pas le moteur. Une page « Activités » hors du monde (un menu) : on perdrait ce qui marche le mieux, les entrées dans le village.

## 3. La première activité à construire : la pétanque

### Pourquoi la pétanque d'abord

| | Pétanque | Basket | Courses de chevaux |
|---|---|---|---|
| Ce qu'elle ajoute au modèle | **le concours à élimination**, un format que le tournoi de poker du mercredi et toutes les compétitions à venir réutiliseront | rien : un championnat de plus, copie du football | la course à plusieurs partants, des paris à places (tiercé) |
| Le lieu | un boulodrome : du sable, des bancs, des lampions ; peu coûteux, lisible au cran « rue » | une salle de sport, un intérieur de plus | un hippodrome, la plus grosse scène du jeu |
| Les figurants | six joueurs et un public, des habitants | dix joueurs grands et rapides, loin du style des villageois | des chevaux : le jeu n'a **pas d'animaux** (règle des personnages), il faudrait les créer et les animer |
| Le village | Lucien, le bouliste qui prend les paris, existe déjà ; la pétanque est **la** coutume du coin | aucun lien | le PMU du café, déjà pris par le football |
| Le moteur | court : une partie à 13 points, mène par mène, pointer ou tirer | proche du football | une course en ligne, simple, mais toute la valeur est dans la scène |

La pétanque coûte le moins, ajoute le plus au modèle (le concours) et appartient déjà au village. Le basket vient ensuite, presque gratuitement, une fois le modèle sorti du football. Les courses demandent d'abord une décision sur les animaux ; une voie qui s'en passe : la course ne se regarde **qu'à la télévision du café**, un écran qui n'en montre que les numéros et la voix du commentateur.

### La fiche : le concours du samedi

- **La structure.** Un type `boulodrome` dans `Structures` (champs : `club` obligatoire, `court`, `couleurs`). Smarves déclare le sien : **le boulodrome des Tilleuls**, derrière la salle François-Rabelais, club **« La Boule smarvoise »** (BSM, vert et blanc). Rien ne change sur la place : la partie de Lucien devant la mairie reste un décor.
- **Le rendez-vous.** **Le concours du samedi**, à 14 h 30, chaque semaine : seize triplettes au plus, une par commune qui a un boulodrome, complété par des **triplettes invitées** des communes réelles les plus proches, comme les clubs invités du football. Élimination directe : huitièmes à 14 h 30, quarts à 15 h 15, demies à 16 h, finale à 16 h 45 ; règlement des paris à 17 h 30. Le samedi soir reste au grand tirage du loto.
- **Le moteur.** Une partie à 13 points, mène par mène : chaque joueur a trois compétences (pointer, tirer, régularité), tirées une fois pour toutes de la graine de la saison ; à chaque boule, pointer ou tirer selon la consigne et la situation. Six licenciés par club, trois jouent.
- **La décision.** Celui qui dirige le club choisit, avant 14 h 30, **la triplette** (qui pointe, qui est milieu, qui tire) et **le tempérament** (prudent : on pointe ; offensif : on tire dès qu'une boule adverse est devant). Sans direction, la triplette la plus forte.
- **Les paris.** Au comptoir de Josiane : le vainqueur du concours (cotes au départ) et chaque partie du tableau (qui gagne). Mise libre, règlement à 17 h 30.
- **Les obligations.** « La Boule smarvoise » a ses obligations chez Maître Garnier, plus petites que celles de l'Étoile ; le dividende suit **le tour atteint** (huitième ×0,5, quart ×0,8, demie ×1,2, finale ×1,6, vainqueur ×2,4).
- **Le direct.** Au boulodrome, la partie de la Boule smarvoise se joue mène par mène à l'heure réelle : les boules en cloche (le ballon du stade sait déjà faire), le cochonnet, la mesure au mètre quand c'est serré ; le bandeau : « BSM 7 – 9 PLV · 11e mène ».
- **La fiche.** Le tableau du concours (le tableau à élimination, comme une feuille de tournoi) et, pour chaque partie, les mènes et les carreaux.
- **Les seuils**, après ceux du football : l'affiche du concours au café à 4 000 gagnés, les paris à 5 000, le boulodrome à 6 000, les obligations à 6 000.
- **Le serveur.** Une table de décisions sur le modèle de `smarves.consignes` (une migration, soumise à Guillaume avant d'être appliquée).
- **Ce que le football y gagne.** Le concours apporte au socle le tableau à élimination ; le tournoi de poker du mercredi s'en servira pour ses tables et ses rangs.

## 4. Les corrections transmises aux fils

Les fenêtres du football, du mercato et du poker sont tenues par leurs fils. Les corrections proposées par ce point, fenêtre par fenêtre, avec le fichier et la ligne, sont dans `/mnt/project-files/ux-activites/corrections.md`, que le coordinateur transmet. Elles reprennent les constats 1 à 9 et 11 ci-dessus.
