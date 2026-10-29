-- Essai de 20261029140000_smarves_pensionnaires_faits_publics.sql, sur une base jetable où les migrations
-- sont passées. Tout se fait dans une transaction annulée à la fin : rien ne reste.
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/20261029140000_faits_publics.sql
begin;

insert into smarves.joueurs (pyramide_id, nom) values ('humain:essai', 'Essai'), ('doublure:essaiessaiessai', 'Billy (pensionnaire)'),
  ('doublure:autreautreautre', 'Autre (pensionnaire)');
insert into smarves.doublures (id, humain) values ('doublure:essaiessaiessai', 'humain:essai'), ('doublure:autreautreautre', 'humain:autre');

-- Jamais joué par le pilote : aucune ligne.
do $$ begin
  assert (select count(*) from smarves.pensionnaire_present('doublure:essaiessaiessai')) = 0, 'present sans pilote';
end $$;

insert into smarves.doublure_pilote (doublure, vivant, lieu) values ('doublure:essaiessaiessai', now() - interval '1 minute', 'colaby'),
  ('doublure:autreautreautre', now(), 'Pas Un Code !');
do $$ declare r record; begin
  select * into r from smarves.pensionnaire_present('doublure:essaiessaiessai');
  assert r.lieu = 'colaby' and r.lieu_nom = 'le Colaby' and r.vivant < now(), 'present colaby';
  select * into r from smarves.pensionnaire_present('doublure:autreautreautre');
  assert r.lieu is null and r.lieu_nom is null and r.vivant is not null, 'un lieu mal formé ne sort pas';
end $$;

-- Les faits : les trois genres, et leurs contraintes.
insert into smarves.doublure_gestes (doublure, quand, genre, lieu, texte, montant) values
  ('doublure:essaiessaiessai', now() - interval '3 minutes', 'lieu', 'casino', null, null),
  ('doublure:essaiessaiessai', now() - interval '2 minutes', 'jeu', 'casino', null, -50),
  ('doublure:essaiessaiessai', now() - interval '1 minute', 'dire', 'casino', 'Rouge, encore !', null),
  ('doublure:autreautreautre', now(), 'dire', 'main', 'Pas à moi', null);
do $$ declare n int; begin
  begin insert into smarves.doublure_gestes (doublure, genre) values ('doublure:essaiessaiessai', 'lieu'); assert false, 'lieu sans lieu';
  exception when check_violation then null; end;
  begin insert into smarves.doublure_gestes (doublure, genre, texte, montant) values ('doublure:essaiessaiessai', 'dire', 'x', 5); assert false, 'dire avec montant';
  exception when check_violation then null; end;
  begin insert into smarves.doublure_gestes (doublure, genre, montant) values ('doublure:essaiessaiessai', 'jeu', 0); assert false, 'jeu nul';
  exception when check_violation then null; end;
  begin insert into smarves.doublure_gestes (doublure, genre, lieu) values ('doublure:essaiessaiessai', 'memoire', 'main'); assert false, 'genre inconnu';
  exception when check_violation then null; end;
  begin insert into smarves.doublure_gestes (doublure, genre, lieu) values ('doublure:essaiessaiessai', 'lieu', 'La Place'); assert false, 'lieu mal formé';
  exception when check_violation then null; end;
end $$;

do $$ declare r record; n int; begin
  select count(*) into n from smarves.pensionnaire_faits('doublure:essaiessaiessai');
  assert n = 3, 'trois faits, pas ceux de l''autre';
  select * into r from smarves.pensionnaire_faits('doublure:essaiessaiessai', 1);
  assert r.genre = 'dire' and r.texte = 'Rouge, encore !' and r.lieu_nom = 'le Casino', 'le plus récent d''abord';
  select count(*) into n from smarves.pensionnaire_faits('doublure:essaiessaiessai', 10, now() - interval '90 seconds');
  assert n = 2, 'la page d''avant';
  select count(*) into n from smarves.pensionnaire_faits('doublure:essaiessaiessai', 0);
  assert n = 1, 'au moins un';
  select count(*) into n from smarves.pensionnaire_faits('doublure:essaiessaiessai', 100000);
  assert n = 3, 'borné sans erreur';
end $$;

-- Aucun droit pour l'API publique.
do $$ begin
  assert not has_table_privilege('anon', 'smarves.doublure_gestes', 'select'), 'anon table';
  assert not has_table_privilege('authenticated', 'smarves.doublure_gestes', 'select'), 'authenticated table';
  assert not has_function_privilege('anon', 'smarves.pensionnaire_faits(text, integer, timestamptz)', 'execute'), 'anon faits';
  assert not has_function_privilege('authenticated', 'smarves.pensionnaire_present(text)', 'execute'), 'authenticated present';
end $$;

-- Le rangement : trois mois, et 500 faits par pensionnaire.
insert into smarves.doublure_gestes (doublure, quand, genre, lieu)
  select 'doublure:essaiessaiessai', now() - interval '91 days', 'lieu', 'main';
insert into smarves.doublure_gestes (doublure, quand, genre, lieu)
  select 'doublure:autreautreautre', now() - (i || ' seconds')::interval, 'lieu', 'main' from generate_series(1, 520) i;
do $$ begin perform smarves.doublures_ranger(); end $$;
do $$ begin
  assert (select count(*) from smarves.doublure_gestes where doublure = 'doublure:essaiessaiessai') = 3, 'trois mois';
  assert (select count(*) from smarves.doublure_gestes where doublure = 'doublure:autreautreautre') = 500, '500 au plus';
  assert exists (select 1 from smarves.doublure_gestes where doublure = 'doublure:autreautreautre' and texte = 'Pas à moi'), 'le plus récent reste';
end $$;

-- L'effacement d'un pensionnaire emporte ses faits.
delete from smarves.doublures where id = 'doublure:autreautreautre';
do $$ begin
  assert (select count(*) from smarves.doublure_gestes where doublure = 'doublure:autreautreautre') = 0, 'cascade';
end $$;

\echo 'faits publics : tout passe'
rollback;
