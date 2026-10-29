-- Retour arrière de 20261029140000_smarves_pensionnaires_faits_publics.sql : les deux lectures, le nom des
-- lieux, le journal des gestes, et le rangement d'avant. Rien d'autre n'est touché. La fonction doublures
-- continue de tourner : elle note seulement que le journal ne s'écrit plus.
begin;
drop function if exists smarves.pensionnaire_faits(text, integer, timestamptz);
drop function if exists smarves.pensionnaire_present(text);
drop function if exists smarves.lieu_nom(text);
create or replace function smarves.doublures_ranger() returns void
  language sql security definer set search_path = ''
as $$
  update smarves.doublure_humeurs set humeur = null, expire = null where humeur is not null and expire < now();
  update smarves.doublure_reveils set statut = 'erreur', erreur = '0 interrompu'
    where statut = 'en_cours' and quand < now() - interval '10 minutes';
  delete from smarves.doublure_reveils where quand < now() - interval '90 days';
$$;
revoke all on function smarves.doublures_ranger() from public;
drop table if exists smarves.doublure_gestes;
commit;
