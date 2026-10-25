extends RefCounted
## Les teintes des écrans de gestion (le carnet, le bureau des clubs, le registre, le (i)), alignées sur le
## reste de Smarves (demande de Guillaume du 25 octobre 2026 : « les couleurs et textures du carnet me
## semblent un peu trancher avec le reste de Smarves »). Le jeu s'habille d'une nuit chaude et de laiton :
## le compteur de crédits, les réglages, la carte et l'accueil ont un fond presque noir, un filet laiton et
## un texte or. Le carnet gardait un bleu ardoise et un bleu vif d'application de bureau. Il garde sa mise
## en page de Football Manager (des panneaux plats, des tableaux, des tuiles), mais dans ces teintes-là :
## le bleu cède la place à l'or, l'ardoise à la nuit, les liserés deviennent laiton.
##
## Chargé par son chemin : const TEINTES := preload("res://scripts/socle/teintes.gd").

## Les fonds, du plus sombre au plus clair : la fenêtre, la barre des rubriques, un panneau, une carte, un
## bouton.
const NUIT := Color(0.055, 0.05, 0.06)
const BARRE := Color(0.08, 0.07, 0.075)
const PANNEAU := Color(0.11, 0.098, 0.1)
const CARTE := Color(0.155, 0.138, 0.135)
const BOUTON := Color(0.22, 0.16, 0.09)
## Le laiton des filets et des cadres, comme le compteur de crédits ; en filet discret entre deux blocs.
const LAITON := Color(0.85, 0.62, 0.3)
const FILET := Color(0.85, 0.62, 0.3, 0.16)
## L'encre : le texte, le texte second, le crayon (les libellés, les en-têtes de colonne).
const TEXTE := Color(0.95, 0.93, 0.88)
const DOUX := Color(0.78, 0.74, 0.68)
const CRAYON := Color(0.6, 0.56, 0.5)
## L'or du jeu (titres, accents, boutons), l'eau (ce qui est à soi, ce qui monte), le vert, le rouge, l'ocre.
const OR := Color(0.96, 0.8, 0.45)
const EAU := Color(0.35, 0.8, 0.75)
const VERT := Color(0.45, 0.82, 0.5)
const ROUGE := Color(0.95, 0.46, 0.41)
const OCRE := Color(0.95, 0.68, 0.3)
