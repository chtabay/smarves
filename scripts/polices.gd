class_name Polices
## Les polices du jeu, embarquées dans le dépôt pour que le PC, le téléphone et les captures
## lisent la même chose : Fira Sans (licence OFL) pour tout le texte, et, en secours, un
## extrait de DejaVu Sans pour les symboles que Fira ne dessine pas (couleurs des cartes,
## faces de dés, étoiles, flèches). Licences dans assets/polices/.

const TEXTE: Font = preload("res://assets/polices/texte.tres")
const GRAS: Font = preload("res://assets/polices/gras.tres")
const TITRE: Font = preload("res://assets/polices/titre.tres")


## Le texte courant : HUD, fenêtres, carnet, bulles, enseignes.
static func texte() -> Font:
	return TEXTE


## Les titres de rubrique, les montants qui comptent, les étiquettes des tables.
static func gras() -> Font:
	return GRAS


## Le grand titre de l'écran d'accueil.
static func titre() -> Font:
	return TITRE
