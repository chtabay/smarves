-- Retour arrière de 20261101000000_smarves_passerelle_lasso.sql : la passerelle Lasso se ferme ici, dans la
-- base (la fonction `doublures` répond alors « refusé » à tout appel, sans erreur serveur), et
-- smarves.doublure_deconnecter / doublure_effacer reviennent à leur version précédente.
-- Aucun pensionnaire, aucune donnée de jeu n'est touché. Les traces d'appels disparaissent.
-- À jouer après le retour arrière de Lasso 012 (lasso.smarves_couper / smarves_reprendre s'appuient sur
-- smarves.doublure_reprendre) : le garde ci-dessous le vérifie.
begin;
set local lock_timeout = '5s';

do $garde$
begin
  if to_regclass('smarves.passerelle_jetons') is null then
    raise exception 'retour arrière smarves passerelle lasso : migration absente';
  end if;
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'lasso' and p.proname in ('smarves_reprendre', 'passerelle_agent')) then
    raise exception 'retour arrière smarves passerelle lasso : retirer d''abord Lasso 012 (sql/012_rollback.sql)';
  end if;
end
$garde$;

drop function smarves.passerelle_entrer(text, text, text, timestamptz);
drop function smarves.passerelle_tracer(text, text, text, boolean);
drop function smarves.doublure_reprendre(text);
drop table smarves.passerelle_appels;
drop table smarves.passerelle_jetons;

create or replace function smarves.doublure_deconnecter(p_humain text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  d text;
  lien boolean;
begin
  if p_humain is null or p_humain like 'doublure:%' then raise exception 'humain invalide'; end if;
  delete from smarves.doublure_acces where humain = p_humain;
  lien := found;
  select id into d from smarves.doublures where humain = p_humain;
  if d is not null then
    update smarves.doublure_pilote set demande = null, geste = null, maj = now() where doublure = d;
    update smarves.doublure_corps set present_jusqu = now(), maj = now() where doublure = d and present_jusqu > now();
  end if;
  return json_build_object('ok', true, 'lien', lien);
end $$;

create or replace function smarves.doublure_effacer(p_humain text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  d text;
begin
  select id into d from smarves.doublures where humain = p_humain;
  delete from smarves.doublure_humeurs where humain = p_humain;
  delete from smarves.doublure_acces where humain = p_humain;
  if d is null then return json_build_object('ok', true, 'efface', false); end if;
  delete from smarves.joueurs where pyramide_id = d;
  return json_build_object('ok', true, 'efface', true);
end $$;

alter table smarves.doublures drop column assistant_coupe;

revoke all on function smarves.doublure_deconnecter(text), smarves.doublure_effacer(text) from public, anon, authenticated;

commit;
