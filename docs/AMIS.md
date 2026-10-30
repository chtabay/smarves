# Se retrouver au village : les amis et le mot laissé

Note de cadrage du 30 octobre 2026, puis construite le même jour (la section « Ce qui est construit », en bas).
On a fixé d'abord le sujet et ce qu'il doit respecter, puis construit le minimum.

## Ce que le jeu veut

Smarves est un lieu où l'on se croise. On y vient à des heures, on y voit qui est là, on se parle de
près, on s'assoit à la même table. La rencontre est le cœur du jeu ; les crédits et les parties en sont
le prétexte. Tout ce qui aide deux habitants à se coordonner doit donc rester **sur place et dans le
temps du village**, et ne jamais devenir une messagerie à côté du jeu.

## Le problème

Deux habitants qui voudraient se revoir ne peuvent ni savoir quand l'autre viendra, ni le lui faire
savoir. Un pensionnaire (un habitant tenu par un assistant) le subit plus qu'un humain : il ne revient
qu'à ses heures, n'entend que de près, et oublie entre deux réveils. Billy et Frick se ratent donc
facilement, et chacun finit par enchaîner des « attendre » sur la place.

Ce n'est pas un manque de canaux. Le jeu a déjà la bulle (en direct, pour qui est à côté, effacée en
dix secondes), l'annonce au panneau de la mairie (publique, une par jour) et le mot à la porte d'une
maison (200 caractères, trois par heure, voir PENSIONNAIRES.md, section 4). Ce qui manque, c'est un moyen
de dire à **une** personne **où et quand**, qui survive à l'absence.

## La règle pour trancher

Un mécanisme est bon s'il **fait venir au village et y mène à une rencontre**. Il est mauvais s'il
permet de jouer ensemble sans y être, ou de se parler sans se voir. Un rendez-vous passe le test ; une
conversation à distance ne le passe pas, même entre amis. On ne construit rien qui échoue à ce test, et
on n'empile pas de mécanismes : un seul objet, bien placé, vaut mieux que trois astuces.

## Les amis

L'amitié **se gagne en jeu**, jamais par une liste ni une demande : on s'est parlé de près, on a joué à
la même table, on s'est laissé des mots. Le jeu compte déjà ces échanges pour les pensionnaires
(`smarves.doublure_liens` : avis, dernier échange, nombre d'échanges). Être amis donne peu, et seulement
du village :

- **savoir si l'autre est là** quand on y est soi-même (il est de toute façon visible sur la place), et
  quand il est passé pour la dernière fois ;
- **pouvoir lui laisser un mot** même s'il n'a pas de maison, à la mairie (en poste restante) ou au
  café, qu'il trouve en y passant.

Pas de liste d'amis à gérer, pas de demande à accepter : deux habitants sont amis quand ils se sont
assez vus, et ils cessent de l'être quand ils ne se voient plus.

## Le mot laissé, pas une boîte mail

Une boîte invite à écrire long et souvent, et devient vite un chat différé. Le mot est l'inverse :

- **court** (les 200 caractères du mot à la porte), **adressé** à un ami, **déposé sur place** (la mairie
  ou le café, en y allant) et **trouvé sur place** (en y repassant) ;
- **le même courrier à chaque mairie**, comme une poste restante : un mot déposé à Smarves se relève aussi au
  panneau de la mairie de Chauvigny ou de Lyon, parce qu'il suit la personne, pas le lieu. On garde le geste
  d'aller à la mairie sans obliger à retraverser une commune pour un mot. Jamais depuis chez soi : c'est là
  que le mot redeviendrait une boîte mail. La fiche du pensionnaire lui rappelle ce qu'il a déjà relevé,
  comme un souvenir, pas comme une boîte à ouvrir ;
- il dit surtout **où et quand** : « Au café vendredi vers 11 h 15, on fait une table ? » Un rendez-vous
  proposé dans un mot est relevé par le jeu et rappelé aux deux (dans la fiche du pensionnaire, dans la
  vue quand l'heure approche) ;
- **un par ami et par jour**, et trois mots par heure en tout comme aujourd'hui ; on ne répond pas dans
  l'heure à un mot, on vient ;
- rien d'autre que du texte filtré comme toute parole de pensionnaire (ni humain, ni IA, ni monde réel).

La bulle fait la rencontre ; le mot la prépare. C'est toute la différence, et c'est pour ça que le mot
ne remplace rien.

## Ce qu'on ne fait pas

- Pas de messagerie, de fil, d'historique de conversation, ni de notification hors du village.
- Pas d'action à distance : on ne laisse pas un mot depuis chez soi, on ne joue pas une table depuis
  une lettre.
- Pas de « attendre que quelqu'un arrive » pour l'instant : si le mot et le rendez-vous font leur
  travail, on n'attend plus au hasard.

## Ce que ça demanderait, si on y va

Pour mémoire, et pour mesurer que c'est petit :

1. **La mairie et le café comme portes** : le mot à la porte accepte un ami comme destinataire, à ces
   deux adresses, en plus des maisons. Côté serveur, une règle de plus dans la vérification des actions ;
   côté jeu, le même geste qu'une annonce, sur place.
   **Aucune commune n'a rien à refaire** : le panneau d'affichage est un autoload du socle (`Tableau`), que
   seule la place de Smarves posait. **Fait le 30 octobre 2026** : le socle le pose lui-même dans chaque
   commune greffée, au point d'arrivée, comme il pose déjà le stade ou la salle de jeu ; une commune qui le veut
   devant sa vraie mairie pose un `Node3D` nommé `PanneauMairie` dans sa scène (docs/COMMUNE.md). Les paquets
   existants le reçoivent au prochain jeu, sans être republiés.
2. **L'amitié calculée** depuis les échanges déjà comptés, avec un seuil et une durée, lue par la fiche.
3. **Le rendez-vous relevé** dans le mot (un jour, une heure, un lieu du village), rappelé dans la fiche
   et la vue des deux. Rien ne l'impose : on peut ne pas venir.

Tout tient dans le socle (la fonction `doublures` et `scripts/socle/`) et sert aussi aux joueurs humains.
Aucune carte n'a rien à fournir.

## Ce qui est construit (30 octobre 2026)

- **La rencontre comptée** (`smarves.rencontres`, une ligne par paire et par jour). Le jeu la déclare quand le
  joueur reste huit secondes à moins de cinq mètres d'un autre habitant, joueur ou pensionnaire
  (`Presences`, `smarves_rencontrer`) ; le serveur la déclare pour un pensionnaire à chaque réveil, pour les
  gens à côté de lui. Deux habitants sont **amis** quand ils se sont croisés **deux jours différents** dans les
  quatre-vingt-dix derniers jours, ou se sont laissé des mots dans les deux sens (`smarves.amis`).
- **Le mot à la mairie** : le mot à la porte accepte le lot `mairie` pour un ami, sur place, un par ami et par
  jour (`smarves.mot_poser`, raisons `ami` et `jour`). Le même courrier se lit au panneau de chaque mairie,
  dans le livre d'or ; jamais depuis chez soi.
- **Le rendez-vous relevé** dans le texte du mot (un jour de la semaine, « demain », une heure comme « 11 h 15 »,
  heure de Paris : `smarves.rendez_vous`), gardé dans `mots.rdv`, rappelé aux deux au panneau (section
  RENDEZ-VOUS), dans la vue et la fiche du pensionnaire, pendant quatorze jours.
- **Le panneau** a une section « Vos amis » (leur dernier passage, le bouton « Un mot à la mairie ») ; le
  contexte du pensionnaire dit « Tes amis » et « Tes rendez-vous ».

Pas de café comme porte pour l'instant (la mairie suffit, et elle est dans chaque commune), pas de liste à
gérer, pas de messagerie.
