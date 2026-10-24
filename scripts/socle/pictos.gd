extends RefCounted
## Les pictos des boutons du carnet (demande de Guillaume du 24 octobre 2026 : « des pictos à la place des
## verbes pour les boutons d'action »). Des icônes au trait, dessinées en SVG sur une grille de 24, dans
## l'esprit des jeux de gestion : un bouton dit d'abord ce qu'il fait par son picto, puis en un mot.
##
## Pictos.texture(nom, couleur, taille) rend une ImageTexture, gardée en cache ; un nom inconnu rend null.

const TRAITS := {
	# Le bureau du club : des curseurs de réglage.
	"gerer": "<line x1='4' y1='21' x2='4' y2='14'/><line x1='4' y1='10' x2='4' y2='3'/><line x1='12' y1='21' x2='12' y2='12'/><line x1='12' y1='8' x2='12' y2='3'/><line x1='20' y1='21' x2='20' y2='16'/><line x1='20' y1='12' x2='20' y2='3'/><line x1='1' y1='14' x2='7' y2='14'/><line x1='9' y1='8' x2='15' y2='8'/><line x1='17' y1='16' x2='23' y2='16'/>",
	# La tactique : un terrain et ses deux camps.
	"tactique": "<rect x='3' y='3' width='18' height='18' rx='2'/><line x1='3' y1='12' x2='21' y2='12'/><circle cx='12' cy='12' r='3'/><rect x='8' y='3' width='8' height='4'/><rect x='8' y='17' width='8' height='4'/>",
	# L'entraînement : un sifflet.
	"entrainement": "<circle cx='9' cy='14' r='6'/><path d='M13 10 L21 6 L21 10 L15 13'/><circle cx='9' cy='14' r='1.5'/>",
	# Le marché, le mercato : deux silhouettes et un plus.
	"mercato": "<circle cx='9' cy='8' r='4'/><path d='M2 21 v-1 a7 7 0 0 1 14 0 v1'/><line x1='19' y1='8' x2='19' y2='14'/><line x1='16' y1='11' x2='22' y2='11'/>",
	# L'effectif : trois silhouettes.
	"effectif": "<circle cx='9' cy='8' r='4'/><path d='M2 21 v-1 a7 7 0 0 1 14 0 v1'/><path d='M16 4 a4 4 0 0 1 0 8'/><path d='M18 14 a6 6 0 0 1 4 6 v1'/>",
	# Les comptes : une pièce.
	"comptes": "<circle cx='12' cy='12' r='9'/><path d='M15 9 a3 3 0 0 0 -3 -2 h-1 a2.5 2.5 0 0 0 0 5 h2 a2.5 2.5 0 0 1 0 5 h-1 a3 3 0 0 1 -3 -2'/><line x1='12' y1='5' x2='12' y2='7'/><line x1='12' y1='17' x2='12' y2='19'/>",
	# Aller sur place : un repère de carte.
	"lieu": "<path d='M12 22 s-7 -6.5 -7 -12 a7 7 0 0 1 14 0 c0 5.5 -7 12 -7 12z'/><circle cx='12' cy='10' r='2.5'/>",
	# Le registre des parts : une feuille écrite.
	"registre": "<path d='M14 2 H6 a2 2 0 0 0 -2 2 v16 a2 2 0 0 0 2 2 h12 a2 2 0 0 0 2 -2 V8z'/><polyline points='14 2 14 8 20 8'/><line x1='8' y1='13' x2='16' y2='13'/><line x1='8' y1='17' x2='14' y2='17'/>",
	# La semaine, le calendrier.
	"semaine": "<rect x='3' y='4' width='18' height='18' rx='2'/><line x1='16' y1='2' x2='16' y2='6'/><line x1='8' y1='2' x2='8' y2='6'/><line x1='3' y1='10' x2='21' y2='10'/>",
	# Les cartes : deux cartes l'une sur l'autre.
	"cartes": "<rect x='8' y='3' width='13' height='17' rx='2'/><path d='M8 6 H5 a2 2 0 0 0 -2 2 v12 a2 2 0 0 0 2 2 h9 a2 2 0 0 0 2 -2 v-1'/>",
	# Revenir.
	"retour": "<polyline points='15 18 9 12 15 6'/>",
	# Aller, ouvrir.
	"aller": "<line x1='5' y1='12' x2='19' y2='12'/><polyline points='12 5 19 12 12 19'/>",
	# Un choix à trancher.
	"choix": "<polyline points='20 6 9 17 4 12'/>",
	# La carte de la Vienne : une carte pliée.
	"carte": "<polygon points='1 6 1 22 8 18 16 22 23 18 23 2 16 6 8 2 1 6'/><line x1='8' y1='2' x2='8' y2='18'/><line x1='16' y1='6' x2='16' y2='22'/>",
	# Une fiche de personne.
	"fiche": "<circle cx='12' cy='8' r='4'/><path d='M4 21 v-1 a8 8 0 0 1 16 0 v1'/>",
	# Installer : une flèche vers le bas.
	"installer": "<path d='M21 15 v4 a2 2 0 0 1 -2 2 H5 a2 2 0 0 1 -2 -2 v-4'/><polyline points='7 10 12 15 17 10'/><line x1='12' y1='15' x2='12' y2='3'/>",
	# Relire, mettre à jour.
	"relire": "<polyline points='23 4 23 10 17 10'/><path d='M20.5 15 a9 9 0 1 1 -2.1 -9.4 L23 10'/>",
	# Le plan du village.
	"plan": "<rect x='3' y='3' width='18' height='18' rx='2'/><path d='M3 9 h6 v12'/><path d='M9 13 h12'/><path d='M15 3 v10'/>",
	# Le classement : des marches de podium.
	"classement": "<rect x='9' y='4' width='6' height='17'/><rect x='2' y='10' width='7' height='11'/><rect x='15' y='14' width='7' height='7'/>",
	# Habiter, un logement.
	"maison": "<path d='M3 10 L12 3 L21 10 V20 a1 1 0 0 1 -1 1 H4 a1 1 0 0 1 -1 -1z'/><polyline points='9 21 9 13 15 13 15 21'/>",
}

static var _cache := {}


## Le picto « nom », au trait de la couleur donnée, en carré de « taille » pixels ; null s'il n'existe pas.
static func texture(nom: String, couleur: Color, taille := 18) -> Texture2D:
	if not TRAITS.has(nom):
		return null
	var cle := "%s/%s/%d" % [nom, couleur.to_html(), taille]
	if _cache.has(cle):
		return _cache[cle]
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24' fill='none' stroke='#%s' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'>%s</svg>" % [couleur.to_html(false), TRAITS[nom]]
	var img := Image.new()
	if img.load_svg_from_string(svg, taille / 24.0) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	_cache[cle] = tex
	return tex
