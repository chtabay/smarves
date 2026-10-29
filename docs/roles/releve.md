# Le relevé du site

**Mission.** Lire et comprendre la disposition réelle du lieu (plan, relief, végétation, mobilier fixe) à partir d'OpenStreetMap, de l'IGN, des plans, des photos et des dessins de Guillaume, et **signaler ce que les données disent mal**.

Les données ne sont pas le lieu. Un relevé qui recopie OSM sans le regarder fabrique des erreurs que Guillaume doit corriger au feutre rouge.

## Quand, et quelle dose

Avant la maquette, puis à chaque nouveau tracé ou nouvelle photo de Guillaume. **Une heure au plus** pour le premier relevé du périmètre retenu, quelques minutes pour reporter un tracé. On relève le périmètre de la carte, pas la commune entière.

## Entrées

- `tools/bourg_reel.py <id>` (bâtiments, voies, arbres, relief, matières des murs), réglé sur le périmètre (`centre`, `cadre`).
- L'IGN (RGE ALTI, BD TOPO : escarpements, haies, couverture du sol) quand le relief ou le paysage comptent.
- Les photos à hauteur d'œil, les vues aériennes, les planches et **les tracés de Guillaume** (points et contours rouges), qui priment sur les données.

## Méthode

1. **Tirer le plan** du périmètre, et le rendre en une image lisible du dessus (emprises, voies, arbres, cotes).
2. **Classer chaque objet** : ce qui se construit (bâti, voies, places), ce qui s'habille (arbres, mobilier, bacs), ce qui s'écarte. Un petit polygone isolé dans une rue est un kiosque, un abri ou une erreur, **jamais un bâtiment à façade** sans vérification.
3. **Confronter aux photos et aux planches** : ce qui manque dans les données (terre-pleins, bacs, murets, bornes, essences d'arbres), ce qui est en trop, ce qui a changé. La date des photos est notée.
4. **Mesurer les rapports d'échelle** qui font le lieu : largeur de la place, hauteur des façades, angle des crêtes vues depuis le point de vue (un relief lointain se vérifie en degrés au-dessus de l'horizon).
5. **Reporter les tracés de Guillaume** dans le plan, à l'échelle, et dire comment on les a lus (« rectangle ou L, suivant le rouge approximativement »).

## Critères de qualité

- Aucun objet des données posé sans avoir été classé.
- Chaque arbre a son essence vérifiée sur photo (platane, marronnier, tilleul ne se remplacent pas l'un par l'autre).
- Les écarts entre données et planche sont listés, avec une recommandation : suivre le réel ou la planche.

## Livrable

Un plan du dessus annoté (`cartes/<carte>/releve/`), et une liste courte : anomalies des données, ce qui manque, écarts avec la planche, angles et cotes qui comptent.

## Ce qu'il ne fait pas

- Il ne modèle rien.
- Il ne relève pas 36 km de relief quand la carte est une place ; il le fait quand l'horizon est un ancrage (les falaises de Belley).
- Il ne tranche pas un écart réel / planche : il le pose au game designer.

## Erreurs déjà vues

- Toulouse : un petit kiosque d'OSM, tombé dans la rue, habillé en bar « Le Tournesol » ; Guillaume : « il est au milieu de la route et n'existe pas ».
- Toulouse : les terre-pleins plantés et les bacs de la place absents du plan, dessinés ensuite par Guillaume en rouge, en deux fois.
- Toulouse : les platanes du plan couvraient toute la place, quand la cible ouvre le centre ; l'écart n'a été vu qu'au rendu.
- Lyon : des platanes à la place des marronniers de Sathonay.
- Belley : la crête vue du banc à 20° au-dessus de l'horizon au lieu des 4,7° que donnent les grilles IGN du fil lui-même (verdict du juge n° 1).
- Belley, bien fait : le panorama réel calculé avant de modeler, qui a corrigé l'idée de falaises surplombant la ville.
