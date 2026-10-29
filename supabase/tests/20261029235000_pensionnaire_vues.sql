-- Essai de 20261029235000_smarves_pensionnaire_vues.sql, sur une base jetable où les migrations sont
-- passées. Transaction annulée à la fin : rien ne reste.
--   psql -v ON_ERROR_STOP=1 -f supabase/tests/20261029235000_pensionnaire_vues.sql
begin;

insert into smarves.joueurs (pyramide_id, nom) values ('doublure:vuesvuesvues', 'Vues (pensionnaire)'),
  ('doublure:autreautrevue', 'Autre (pensionnaire)');
insert into smarves.doublures (id, humain) values ('doublure:vuesvuesvues', 'humain:v'), ('doublure:autreautrevue', 'humain:w');

do $$ declare img text := '/9j/' || repeat('A', 200); r record; n int; begin
  insert into smarves.doublure_vues (doublure, genre, quand, lieu, image) values
    ('doublure:vuesvuesvues', 'oeil', now() - interval '5 minutes', 'main', img),
    ('doublure:vuesvuesvues', 'dedans', now() - interval '1 minute', 'casino', img),
    ('doublure:autreautrevue', 'oeil', now(), 'main', img);
  -- Une seule ligne par sorte : la nouvelle remplace l'ancienne.
  insert into smarves.doublure_vues (doublure, genre, quand, lieu, image) values ('doublure:vuesvuesvues', 'oeil', now(), 'main', img || 'B')
    on conflict (doublure, genre) do update set quand = excluded.quand, lieu = excluded.lieu, image = excluded.image;
  select count(*) into n from smarves.pensionnaire_vues('doublure:vuesvuesvues');
  assert n = 2, 'deux sortes, pas celles de l''autre';
  select * into r from smarves.pensionnaire_vues('doublure:vuesvuesvues') limit 1;
  assert r.genre = 'oeil' and r.image like '%B' and r.lieu_nom = 'la place de Smarves', 'la plus récente d''abord, remplacée';
  begin insert into smarves.doublure_vues (doublure, genre, image) values ('doublure:vuesvuesvues', 'carte', img); assert false, 'genre inconnu';
  exception when check_violation then null; end;
  begin insert into smarves.doublure_vues (doublure, genre, image) values ('doublure:vuesvuesvues', 'dessus', 'pas une image'); assert false, 'pas un JPEG';
  exception when check_violation then null; end;
  begin insert into smarves.doublure_vues (doublure, genre, image) values ('doublure:vuesvuesvues', 'dessus', '/9j/' || repeat('A', 600000)); assert false, 'trop grande';
  exception when check_violation then null; end;
  -- Le rangement efface ce qui a plus de trente jours.
  update smarves.doublure_vues set quand = now() - interval '31 days' where doublure = 'doublure:vuesvuesvues' and genre = 'dedans';
  perform smarves.doublures_ranger();
  select count(*) into n from smarves.pensionnaire_vues('doublure:vuesvuesvues');
  assert n = 1, 'rangement à trente jours';
end $$;

do $$ begin
  assert not has_table_privilege('anon', 'smarves.doublure_vues', 'select'), 'anon table';
  assert not has_table_privilege('authenticated', 'smarves.doublure_vues', 'select'), 'authenticated table';
  assert not has_function_privilege('anon', 'smarves.pensionnaire_vues(text)', 'execute'), 'anon';
  assert not has_function_privilege('authenticated', 'smarves.pensionnaire_vues(text)', 'execute'), 'authenticated';
  assert not (select prosecdef from pg_proc where oid = 'smarves.pensionnaire_vues(text)'::regprocedure), 'invoker';
  if exists (select 1 from pg_roles where rolname = 'lasso_server') then
    assert not has_table_privilege('lasso_server', 'smarves.doublure_vues', 'select'), 'lasso_server table';
    assert not has_function_privilege('lasso_server', 'smarves.pensionnaire_vues(text)', 'execute'), 'lasso_server';
  end if;
end $$;

-- Un pensionnaire supprimé emporte ses vues.
delete from smarves.joueurs where pyramide_id = 'doublure:vuesvuesvues';
do $$ begin assert (select count(*) from smarves.doublure_vues where doublure = 'doublure:vuesvuesvues') = 0, 'cascade'; end $$;

rollback;
