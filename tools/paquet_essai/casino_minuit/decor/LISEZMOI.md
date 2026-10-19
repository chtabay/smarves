# Le décor de l'original

Chaque `zone-<id>.glb` est la zone `zone-<id>` de la scène du moteur web de Casino Minuit, exportée telle
quelle (Three.js, GLTFExporter) : mêmes formes, mêmes matériaux, mêmes textures canvas, mêmes répétitions.
`tex/` tient chaque texture une seule fois, nommée par l'empreinte de son contenu ; les `.glb` y renvoient.

À l'export :
- ce que le portage anime ou éclaire lui-même est laissé de côté (halos, jets, foules du concert et de
  l'arène, faisceaux, écrans à LED, portes) ;
- les maillages instanciés sont cuits en maillages simples, la couleur d'instance passant aux sommets ;
- les matériaux dont la texture défile sont renommés `anim|genre|vx|vy|nom` : minuit.gd les anime.

Pour refaire l'export : `tools/minuit_decor/` (le script Playwright et le tri des textures).
