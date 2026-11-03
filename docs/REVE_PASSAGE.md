# Passage facultatif vers Le Rêve hindou

La chute existante et sa cinématique restent inchangées. Sans exécutable installé dans `user://reve_hindoue.cfg`, rien ne s'annonce ni ne se lance. La section `[installation]` reçoit `executable`, chemin absolu de l'export Rêve, et, pour rejoindre un monde commun, `server_url` en `wss://` ainsi qu'un éventuel `tls_ca`.

Le descripteur temporaire ne transporte qu'une identité indicative et une apparence : aucun jeton ni inventaire. Le Rêve doit vérifier le compte indépendamment auprès de Pyramides.

Pour un humain, si `server_url` est configuré en WSS, le pont transmet `--join` et éventuellement `--tls-ca`. Le Rêve ouvre la connexion OAuth Pyramides pour le compte attendu par le descripteur, puis rejoint ce serveur après vérification. Sans serveur configuré, il démarre localement. Aucun jeton Smarves humain n’est transmis.

Pour un pensionnaire, le pont enregistre une demande de passage. La boucle du pilote la prend entre deux gestes, lance `--headless -- --pensionnaire`, puis attend trente secondes un accusé écrit par le Rêve après authentification. Sans cet accusé, seul l'enfant nouvellement lancé est arrêté et Smarves reprend. Après succès, le processus parent reste vivant jusqu'à la fin de l'enfant pour préserver la tâche hôte.

Les variables existantes `SMARVES_PILOTE_URL`, `SMARVES_PILOTE_JETON`, `SMARVES_PENSIONNAIRE` sont héritées ; `REVE_SERVER_URL` et `REVE_TLS_CA` sont ajoutées à l'enfant puis restaurées dans le parent. Aucun jeton dans les arguments ou les fichiers de passage. Le Rêve utilise les routes réelles `pilote_etat`, `pilote_attendre`, `pilote_vue`, avec les gestes et les vues d'un joueur normal ; il ne rapporte aucun mouvement d'argent.

Le service Rêve doit être activé séparément : vérification de la preuve Smarves, délégation courte dédiée `reve_hindoue`, WSS et migration approuvée. Ce changement ne crée aucun secret et ne déploie aucune fonction ou migration.

Test : `godot --headless --path . -s tools/test_reve_passage.gd`. Il vérifie absence d'installation, descripteur sans secret, absence de demande de transfert et retour au pilote si le processus enfant n'accuse pas réception. La recette réelle avec compte et doublures demande l'activation du service Rêve.
