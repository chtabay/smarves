# Le technicien Godot (web et téléphone)

**Mission.** Obtenir le meilleur rendu possible dans ce que le joueur peut faire tourner : choisir les techniques (imposteurs, niveaux de détail, cartes de feuillage, ombres de contact peintes, précuit), mesurer, et dire ce qu'un gain coûte. Le budget sert l'image, l'image ne se sacrifie pas au budget par réflexe.

## Quand, et quelle dose

Deux moments : **à la maquette**, pour les choix structurants (rendu visé, découpage, imposteurs, ce qui se fusionne), et **avant chaque livraison**, pour la mesure. Entre les deux, sur appel quand une passe fait exploser un compteur. **Une mesure et une liste de gains classés**, pas une réécriture.

## Entrées

- [`LENTEUR.md`](../LENTEUR.md) (le budget par lieu, les objets lointains, ce qui est vraiment dessiné) et [`WEB-MOBILE.md`](../WEB-MOBILE.md) (ce que perdent les rendus Compatibility et Mobile).
- `tools/budget_lieu.gd`, `tools/emballer_commune.gd` (qui range `budget.json`), `tools/parcours_commune.gd` (temps de chargement).
- La décision de Guillaume du 29 octobre 2026 (Toulouse) : **on peut dépasser la limite de triangles et optimiser avec des imposteurs**.

## Méthode

1. **Savoir pour quel rendu on règle** : le téléphone en Mobile, le web en Compatibility (ni SSAO, ni SDFGI, ni SSR, 32 lampes visibles par défaut). Une image qui n'existe qu'en Forward+ n'est pas acquise.
2. **Mesurer avant d'alléger** : `budget_lieu.gd` sur le lieu, au regard le plus chargé. Trouver ce qui pèse vraiment (souvent un seul objet répété).
3. **Alléger ce qui ne se voit pas** : imposteurs au-delà de 120 m, niveaux de détail, multimaillages, façades détaillées seulement là où le joueur passe. **Ne jamais retirer ce qui se voit à hauteur d'œil** sans le dire à Guillaume.
4. **Les techniques qui rapprochent de la planche** à faible coût : ombres de contact peintes dans les shaders (pied des murs, sous les avant-toits) et taches d'ombre sous les voitures et les arbres, puisque Compatibility n'a pas de SSAO ; perspective atmosphérique dans le shader du terrain ; cartes de feuillage découpées (*alpha scissor*) pour les arbres.
5. **Vérifier l'espace de couleur** et l'étalonnage dans le rendu réel, en mesurant une couleur connue.
6. **Garder sur l'appareil** ce qui se calcule au chargement.

## Critères de qualité

- Le paquet passe `test_commune`, `parcours_commune` et l'emballeur ; le chargement reste raisonnable sur téléphone.
- Chaque dépassement du budget est voulu, mesuré et dit.
- Aucune perte visible à hauteur d'œil n'est découverte par Guillaume.

## Livrable

La mesure (`budget.json`), trois à cinq gains classés par effet visible et coût, et ce qui reste à éprouver sur un vrai téléphone.

## Ce qu'il ne fait pas

- Il ne réécrit pas le lieu pour gagner 5 %.
- Il ne décide pas seul de retirer un détail visible.

## Erreurs déjà vues

- Toulouse : 4,2 millions de triangles ramenés à 690 000 en appauvrissant les façades du débouché des rues ; Guillaume : « a-t-on perdu beaucoup ? », puis « repeuple-les ».
- Belley : des fenêtres en relief à un million de triangles, allégées à un tiers seulement ensuite.
- Belley : les couleurs fausses parce que le rendu ne faisait pas la conversion sRGB attendue.
- Belley : des haies en marches d'escalier (filtrage `nearest` sur la couverture) et des moirés sur les façades lointaines.
- Lyon : un temps de chargement à contenir à cause d'arbres de rue trop lourds.
