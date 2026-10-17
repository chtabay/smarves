class_name Lines
## Ce que disent les habitants de Smarves. Tout est dit au premier degré : le jeu est un placement,
## le prêt une prudence, la perte un apprentissage. Jamais de morale ; le joueur lit entre les lignes.

const SPEAKERS := {
	"josiane": {"name": "Josiane", "lines": [
		"Une machine à sous, c'est un livret A avec des lumières.",
		"Je ne vends pas du rêve, je vends de la perspective.",
		"Mon mari jouait la Smarvoise tous les soirs. Il dit qu'il était à deux doigts.",
		"Ce n'est pas perdu, c'est en circulation.",
		"Les gens qui ne jouent pas, je les plains. Ils n'ont rien à espérer.",
	]},
	"dede": {"name": "Dédé", "lines": [
		"Le 421, c'est une science. J'ai juste pas encore la dernière formule.",
		"J'ai perdu ma voiture au 421. Mais j'ai appris un truc sur les dés.",
		"Un jour je gagne, et ce jour-là tout le monde comprendra.",
		"Tu vois le Moulin, là-bas ? Le meunier distribue des cartes après minuit. Je dis ça, je dis rien.",
		"Ma femme dit que je joue trop. Je lui ai expliqué que c'était de l'épargne active.",
	]},
	"lucien": {"name": "Lucien", "lines": [
		"Je ne parie pas, j'analyse. Le parieur, c'est celui qui perd.",
		"Les Rabelais à 3 contre 1, c'est cadeau. Statistiquement.",
		"La pétanque, c'est comme la Bourse, avec du gravier.",
		"Au bois de Saint-Pierre, les zèbres courent. Si si. Demandez au gardien.",
	]},
	"brunet": {"name": "M. Brunet", "lines": [
		"Un projet de vie, ça se finance. Le jeu est un projet de vie.",
		"Je n'ai jamais refusé un prêt. C'est pour ça que mes clients me sont fidèles.",
		"La dette, c'est la preuve qu'on vous fait confiance.",
		"Un banquier qui refuse un prêt pour jouer ? Un loser. Je l'ai bien connu, il est parti à Poitiers.",
		"Vos intérêts, ce sont aussi les nôtres. C'est écrit en petit, mais c'est écrit.",
	]},
	"ferrand": {"name": "Mme Ferrand", "lines": [
		"Une baguette, un ticket. On ne sait jamais.",
		"Ma roulette du comptoir, c'est pour rendre la monnaie plus intéressante.",
		"Le pain, ça nourrit le corps. Le loto, ça nourrit l'espoir.",
	]},
	"gardien": {"name": "le gardien du bois", "lines": [
		"Les zèbres sont en béton depuis 1983. Ça ne les empêche pas de courir, moralement.",
		"Zébulon a des bonnes jambes. Pour un zèbre de béton.",
		"Au château, il paraît qu'on jouait déjà au temps des seigneurs. On ne fait que continuer.",
	]},
	"meunier": {"name": "le meunier", "lines": [
		"Le moulin tourne avec l'eau, et l'arrière-salle avec les cartes.",
		"Un as et une figure, c'est comme la farine : ça se transforme en or.",
		"Paraît qu'aux rochers de Passelourdin, il y a une partie où on ne demande pas les noms.",
	]},
	"inconnu": {"name": "l'Inconnu", "lines": [
		"Ici, on ne joue pas pour l'argent. On joue pour beaucoup d'argent.",
		"Asseyez-vous. Votre banquier vous a donné son accord, j'imagine.",
		"Personne ne perd, à Passelourdin. Certains gagnent moins longtemps.",
	]},
	"armand": {"name": "Monsieur Armand", "lines": [
		"Le salon accueille ceux qui ont prouvé leur foi en l'avenir.",
		"Ici, nos clients ne perdent pas. Ils investissent sur le long terme.",
		"Un client qui revient, c'est un client qui a compris.",
	]},
	"hotesse": {"name": "l'hôtesse", "lines": [
		"Bienvenue au Casino de Smarves. Le jeu est un investissement, et vous êtes un investisseur.",
		"Le Nocturne est à droite, la chance est partout.",
		"Les salons de l'étage s'ouvrent aux joueurs méritants. Ceux qui ont fait leurs preuves au jeu.",
	]},
	"croupier": {"name": "le croupier", "lines": [
		"Faites vos jeux. Le hasard ne récompense que ceux qui jouent.",
		"La banque ne gagne pas toujours. Juste assez souvent.",
		"Une série noire, c'est une série rouge qui se fait attendre.",
	]},
	"barman": {"name": "le barman", "lines": [
		"Le cocktail du jour s'appelle « Encore un ». Il a beaucoup de succès.",
		"On dit qu'à la Loggia, à l'étage, les dés sont plus généreux. On le dit.",
		"Ici, on trinque aux gains. Les pertes, on les noie.",
	]},
	"caissier": {"name": "le caissier", "lines": [
		"La caisse avance. La caisse croit en vous.",
		"Un jeton, c'est de l'argent qui a pris confiance en lui.",
	]},
	"habitant": {"name": "un habitant", "lines": [
		"J'ai tout placé sur la roue de la kermesse. Mes enfants comprendront plus tard.",
		"À Smarves, on ne dit pas « perdre », on dit « avoir de l'expérience ».",
		"Le loto de samedi ? J'y vais pour l'ambiance. Et pour le gros lot.",
		"Mon voisin a gagné une fois. Depuis, il ne parle que de ça. Et il joue tous les jours.",
		"M. Brunet m'a dit que j'avais un profil d'investisseur. Ça m'a touché.",
		"La boulangère fait tourner sa roulette avec la monnaie. C'est pratique, il n'y a plus de monnaie.",
		"Paraît que le casino a un salon où on joue au Banco sans commission. Pour les initiés.",
		"Quand on perd, c'est que la chance accumule. C'est de la physique.",
		"J'ai revendu ma tondeuse pour jouer aux zèbres. L'herbe repoussera.",
	]},
}

## Rumeurs : une phrase qui donne envie d'aller voir un lieu.
const RUMORS := {
	"petanque": "Lucien prend les paris sur la pétanque. Il paraît que les cotes sont honnêtes.",
	"boulangerie": "Mme Ferrand a installé une roulette sur son comptoir. On y gagne parfois son pain.",
	"rabelais": "Samedi, grand loto à la salle Rabelais. M. Gaudin, le président du comité des fêtes, promet un carton historique.",
	"eglise": "La roue de la kermesse tourne sur le parvis. Saint Félix veille, paraît-il.",
	"zebres": "Au bois de Saint-Pierre, on parie sur les trois zèbres. Zébulon est en forme.",
	"moulin": "Le meunier tient un blackjack dans l'arrière-salle du Moulin des Dames.",
	"passelourdin": "Aux rochers de Passelourdin, une partie de poker sans nom ni limite. Pour les grands investisseurs.",
	"casino": "Le casino a ouvert de nouveaux salons à l'étage. Il faut avoir fait ses preuves.",
}


static func line(speaker: String) -> String:
	var s: Dictionary = SPEAKERS.get(speaker, SPEAKERS.habitant)
	return (s.lines as Array).pick_random()


static func display_name(speaker: String) -> String:
	return SPEAKERS.get(speaker, SPEAKERS.habitant).name
