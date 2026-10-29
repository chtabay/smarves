-- Retour arrière de 20261029140000_smarves_pensionnaires_faits_publics.sql : les deux lectures, le nom des
-- lieux et le rangement d'avant. Le journal des gestes n'est pas détruit : il est mis de côté sous
-- smarves.doublure_gestes_sauve (sans droit pour personne), à supprimer à la main quand on est sûr. La
-- fonction doublures continue de tourner : elle note seulement que le journal ne s'écrit plus.
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
do $$ begin
  if to_regclass('smarves.doublure_gestes_sauve') is not null then
    raise exception 'smarves.doublure_gestes_sauve existe déjà : la vider ou la renommer avant';
  end if;
end $$;
alter table if exists smarves.doublure_gestes rename to doublure_gestes_sauve;
alter index if exists smarves.doublure_gestes_quand rename to doublure_gestes_sauve_quand;
commit;
