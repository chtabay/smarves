-- Pensionnaires (docs/PENSIONNAIRES.md) : la personnalité « autre », dont le créateur écrit le caractère
-- lui-même. La fonction `doublures` le vérifie (20 à 600 caractères, le filtre des textes de pensionnaire)
-- avant de le ranger, juste après l'ouverture (smarves.doublure_ouvrir ne change pas) ; la base n'en garde
-- que la borne de longueur.
alter table smarves.doublures drop constraint doublures_personnalite_check;
alter table smarves.doublures add constraint doublures_personnalite_check
  check (personnalite in ('prudent', 'flambeuse', 'commere', 'superstitieux', 'calculatrice', 'bon_vivant', 'autre'));
alter table smarves.doublures add column caractere text check (caractere is null or char_length(caractere) <= 600);
