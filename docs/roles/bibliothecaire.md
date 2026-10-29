# Le bibliothécaire

**Mission.** Tirer le meilleur de la bibliothèque commune (`docs/BIBLIOTHEQUE.md`) : savoir ce qui existe et ses options, l'employer avant de modeler, et demander au fil de la bibliothèque ce qui manque vraiment. Savoir aussi **quand s'en affranchir**.

## Quand, et quelle dose

Avant de modeler quoi que ce soit, puis à chaque besoin nouveau. **Un quart d'heure** : une table, pas une étude.

## Entrées

- Le catalogue (`bibliotheque/bibliotheque.json`) et `docs/BIBLIOTHEQUE.md`, y compris les PR de la bibliothèque encore ouvertes.
- Les planches de référence (`/mnt/project-files/bibliotheque-assets/<brique>/`).
- Les besoins de la note d'intentions et du relevé.

## Méthode

1. **Pour chaque besoin de la scène** (façades, sols, arbres, mobilier, eau, véhicules), chercher la brique et **lire ses options** (types, matières, `fleurs`, `vigne`, `lucarnes`, couvertures…). Une brique s'emploie avec ses options, pas avec ses réglages par défaut.
2. **La comparer à la planche** à la même échelle : convient, convient avec une option, ne convient pas.
3. **Ce qui ne convient pas** : soit une reprise de la brique (option manquante), soit une brique nouvelle, soit un objet propre à la carte (un monument unique, une disposition de place). On demande au fil de la bibliothèque avec la planche et une description précise de la technique attendue (exemple réussi : les platanes « en dentelle » de Toulouse, cartes de feuillage découpées, demandés avec leur technique).
4. **Une essence, un objet, une seule brique** (cartes/COMMUN.md) : on ne refait pas un platane qui existe.

## Critères de qualité

- Aucun objet modelé à la main alors qu'une brique le fait.
- Aucune brique gardée quand elle trahit le réel ou la planche.
- Chaque demande à la bibliothèque porte une planche, l'échelle et la technique.

## Livrable

Une table « besoin → brique@version et options, ou demande », dans la note d'intentions.

## Ce qu'il ne fait pas

- Il ne construit pas les briques nouvelles : c'est le fil de la bibliothèque, et elles n'entrent au catalogue qu'après l'accord de Guillaume sur les images.
- Il ne bloque pas une scène en attendant une brique : on compose avec un repli, et on remplace.

## Erreurs déjà vues

- Belley : le Relais et les maisons de la place modelés à la main (enduit lisse, blocs de quatre à cinq niveaux) alors que `facadier-du-bugey@1` a `moellons`, `ferme`, `vigneronne`, `bourgeoise`, `vigne`, `tuile_vieillie` ; `mobilier-du-bugey@1` avait la `tonnelle` (verdict du juge n° 1).
- Belley : les fenêtres refaites dans le paquet au lieu de reprendre celles des façadiers ; Guillaume : « pas au niveau des autres assets de la bibliothèque ».
- Belley : les falaises de la bibliothèque gardées dans la planche d'intention ; Guillaume : « ne ressemblent en rien à la réalité, affranchis-toi de la bibliothèque quand ça ne te permet pas d'atteindre tes objectifs ».
- Toulouse : les arbres d'Adriers cherchés dans la bibliothèque alors qu'ils n'étaient que dans le paquet d'un autre auteur ; il fallait le dire tout de suite et demander la brique.
