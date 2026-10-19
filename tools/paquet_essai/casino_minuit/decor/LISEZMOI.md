# Le décor de l'original

Chaque `zone-<id>.glb` est la zone `zone-<id>` de la scène du moteur web de Casino Minuit, exportée telle
quelle (Three.js, GLTFExporter) : mêmes formes, mêmes matériaux, mêmes textures canvas, mêmes répétitions.
`tex/` tient chaque texture une seule fois, nommée par l'empreinte de son contenu ; les `.glb` y renvoient.

À l'export :
- ce que le portage anime ou éclaire lui-même est laissé de côté (halos, jets, foules du concert et de
  l'arène, faisceaux, écrans à LED, portes) ;
- les maillages instanciés sont cuits en maillages simples, la couleur d'instance passant aux sommets ;
- les matériaux dont la texture défile sont renommés `anim|genre|vx|vy|nom` (`anim|pas|vx|vy|cadence|nom` pour
  celles qui avancent par crans) : decor.gd les anime ;
- les instances que l'original anime une à une (pendeloques, roues de roulette, carpes, ampoules en chenillard,
  flammes) sont exportées en groupe d'enfants `i<k>[_rrggbb]` : decor.gd en refait un MultiMesh et les anime
  avec les formules de js/zones/*.js ; porte à tambour, roue des hautes limites, roue de la fortune, flammes
  du salon et gyrophare sont animés par leur nom.

`ecrans/` tient les pièces des écrans que l'original redessine en direct (jackpot, tournois du poker, paris),
recomposées par ecrans.gd et ecrans_paris.gd ; `polices/` les polices de l'original qu'elles emploient
(licence dans `polices/LISEZMOI.md`).

Pour refaire l'export : `tools/minuit_decor/` (le script Playwright et le tri des textures).
