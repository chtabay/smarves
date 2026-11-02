# Passage facultatif vers Le Rêve hindou

Après la chute existante de trente secondes et la cinématique du Dessous, une installation locale du Rêve peut s'ouvrir. Aucun nouveau menu ne révèle cet easter egg. Sans installation, le comportement existant demeure.

Configurer `user://reve_hindoue.cfg`, section `[installation]`, clé `executable` contenant le chemin absolu vers l'export autonome installé et de confiance. Aucun téléchargement automatique. Le processus reçoit un descripteur JSON temporaire de moins de 16 Kio : version, origine, date, nonce, identité attendue et apparence. Aucun jeton ni inventaire n'est transmis. Le receveur exige une nouvelle preuve Pyramides pour l'audience `reve_hindoue`; l'identité du fichier n'est qu'une indication.

Smarves reste utilisable au Dessous en arrière-plan, y compris si le receveur se ferme ou ne termine pas son chargement. Le simple lancement du processus n'est pas un accusé de réception. La migration et le scope Rêve ne sont pas activés par ce changement. L'adaptation des agents `doublures` reste une intégration serveur distincte.

Vérification autonome du pont : `godot --headless --path . -s tools/test_reve_passage.gd`. Le test vérifie l'absence d'installation, le descripteur, les nonces et l'absence de jeton ; il ne lance pas de programme externe. Rejouer le test Dessous existant dans le dépôt complet avant fusion.
