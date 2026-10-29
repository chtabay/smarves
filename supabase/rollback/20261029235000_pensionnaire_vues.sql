-- Retour arrière de 20261029235000_smarves_pensionnaire_vues.sql (appliquer d'abord celui de Lasso 010,
-- sql/010_rollback.sql). Les vues gardées sont effacées : ce ne sont que les dernières images, que le
-- jeu refait au geste suivant. La fonction doublures continue de tourner (l'écriture est seulement notée).
begin;
drop function if exists smarves.pensionnaire_vues(text);
create or replace function smarves.doublures_ranger() returns void
  language sql security definer set search_path = ''
as $$
  update smarves.doublure_humeurs set humeur = null, expire = null where humeur is not null and expire < now();
  update smarves.doublure_reveils set statut = 'erreur', erreur = '0 interrompu'
    where statut = 'en_cours' and quand < now() - interval '10 minutes';
  delete from smarves.doublure_reveils where quand < now() - interval '90 days';
  delete from smarves.doublure_gestes where quand < now() - interval '90 days';
  delete from smarves.doublure_gestes g using (
    select id from (select id, row_number() over (partition by doublure order by quand desc, id desc) as rang
      from smarves.doublure_gestes) x where x.rang > 500) v
   where g.id = v.id;
$$;
revoke all on function smarves.doublures_ranger() from public;
drop table if exists smarves.doublure_vues;
commit;
