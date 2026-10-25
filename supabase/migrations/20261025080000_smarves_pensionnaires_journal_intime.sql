-- Smarves, le journal intime des pensionnaires (docs/PENSIONNAIRES.md, « Son journal intime ») : après
-- chaque tour, le pensionnaire écrit quelques lignes pour lui-même, à la première personne. Seul son
-- créateur les lit, dans la fiche « Mon pensionnaire » du carnet ; personne d'autre au village, et le
-- pensionnaire ne les relit pas (sa mémoire reste la seule chose qu'il garde d'un réveil à l'autre).

alter table smarves.doublure_reveils add column if not exists intime text
  check (intime is null or char_length(intime) <= 800);
