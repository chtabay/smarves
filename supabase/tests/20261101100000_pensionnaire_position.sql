-- Essai de 20261101100000_smarves_pensionnaire_position.sql, sur une base jetable où les migrations sont
-- passées. Transaction annulée à la fin : rien ne reste.
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/20261101100000_pensionnaire_position.sql
begin;

insert into smarves.joueurs (pyramide_id, nom) values ('doublure:dehorsdehors', 'Dehors (pensionnaire)'),
  ('doublure:dedansdedans', 'Dedans (pensionnaire)'), ('doublure:jamaisjamais', 'Jamais (pensionnaire)'),
  ('humain:a', 'Humain A'), ('humain:b', 'Humain B'), ('humain:c', 'Humain C');
insert into smarves.doublures (id, humain, personnalite, mode) values ('doublure:dehorsdehors', 'humain:a', 'autre', 'agent'), ('doublure:dedansdedans', 'humain:b', 'autre', 'agent'),
  ('doublure:jamaisjamais', 'humain:c', 'autre', 'agent');
insert into smarves.doublure_pilote (doublure, vivant, lieu, x, y, z) values
  ('doublure:dehorsdehors', now(), 'main', -1.37, 0.4, -65.21),
  ('doublure:dedansdedans', now(), 'notaire', -0.15, 0, 1.59);

do $$ declare r record; n int; begin
  select * into r from smarves.pensionnaire_position('doublure:dehorsdehors');
  assert r.x = -1.5 and r.z = -65, 'dehors : au demi-pas';
  select count(*) into n from smarves.pensionnaire_position('doublure:dedansdedans');
  assert n = 0, 'dans une salle : rien';
  select count(*) into n from smarves.pensionnaire_position('doublure:jamaisjamais');
  assert n = 0, 'jamais joué : rien';
  update smarves.doublure_pilote set x = 5000 where doublure = 'doublure:dehorsdehors';
  select count(*) into n from smarves.pensionnaire_position('doublure:dehorsdehors');
  assert n = 0, 'hors du village : rien';
end $$;

do $$ begin
  assert not has_function_privilege('anon', 'smarves.pensionnaire_position(text)', 'execute'), 'anon';
  assert not has_function_privilege('authenticated', 'smarves.pensionnaire_position(text)', 'execute'), 'authenticated';
  assert not (select prosecdef from pg_proc where oid = 'smarves.pensionnaire_position(text)'::regprocedure), 'invoker';
  if exists (select 1 from pg_roles where rolname = 'lasso_server') then
    assert not has_function_privilege('lasso_server', 'smarves.pensionnaire_position(text)', 'execute'), 'lasso_server';
  end if;
end $$;

rollback;
