# Équilibrage

Résultat de la simulation `godot --headless --path . res://tools/sim_progression.tscn` : 300 joueurs moyens pendant une heure, un coup toutes les 5 secondes environ, une mise d'à peu près un dixième de leurs crédits, l'avance de Josiane (2 × 200) puis M. Brunet quand les crédits ont fondu.

Intention : trois lieux dans les dix premières minutes, la boulangerie vers le quart d'heure, puis un ralentissement qui mène chez M. Brunet vers la demi-heure. Ensuite, la dette monte plus vite que les gains.

```
=== 300 joueurs, 60 minutes ===
Casino : La Salle des Ambassadeurs            seuil      500   atteint par 100 %   médiane 2.1 min
Lieu : La pétanque de la place                seuil     1000   atteint par 100 %   médiane 4.0 min
Casino : La Loggia                            seuil     2000   atteint par 100 %   médiane 8.2 min
Lieu : La boulangerie                         seuil     3000   atteint par 100 %   médiane 13.7 min
Casino : Le Salon privé                       seuil     5000   atteint par 100 %   médiane 26.7 min
Lieu : La salle François-Rabelais             seuil     8000   atteint par  98 %   médiane 37.2 min
Casino : Le Salon de musique                  seuil    10000   atteint par  93 %   médiane 41.9 min
Lieu : Le parvis Saint-Félix                  seuil    20000   atteint par  57 %   médiane 49.4 min
Lieu : L'allée des trois zèbres               seuil    50000   atteint par  18 %   médiane 52.1 min
Casino : Les Salons particuliers              seuil    50000   atteint par  18 %   médiane 52.1 min
Lieu : Le Moulin des Dames                    seuil   120000   atteint par   5 %   médiane 54.2 min
Lieu : Les rochers de Passelourdin            seuil   300000   atteint par   0 %   médiane 59.7 min
Premier prêt de M. Brunet : 88 % des joueurs, médiane 30.2 min
Dette médiane après une heure : 4297
```
