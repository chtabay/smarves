-- Smarves, les dernières vues du jeu d'un pensionnaire (docs/PENSIONNAIRES.md, « Ce que le village a vu de lui ») :
-- l'image que le jeu du pilote produit déjà à chaque geste pour l'assistant qui le joue, gardée pour son
-- créateur. Aucune image de plus n'est fabriquée : on garde seulement la dernière de chaque sorte.
--
-- Décision de Guillaume (29/10) : les vues telles quelles, avec ce qu'on y voit (les autres joueurs, leurs
-- bulles), montrées à son créateur seulement, après un accord qui le dit (Lasso, migration 010).
--
-- 1. smarves.doublure_vues : une ligne par pensionnaire et par sorte de vue, écrasée à chaque nouvelle
--    image de cette sorte (fonction doublures, dépôt chtabay/addict) :
--    - « oeil » : dehors, à pied ; « dessus » : dehors, la caméra de dessus qui le suit ;
--    - « dedans » : dans un lieu (casino, notaire…), quelle que soit la caméra.
--    L'image est un JPEG en base64 (600 000 caractères au plus), avec son lieu et son heure.
-- 2. smarves.pensionnaire_vues(id) : ses dernières vues, la plus récente d'abord. SECURITY INVOKER, aucun
--    droit pour personne : seule une fonction propriétaire du schéma (lasso.smarves_vues) s'en sert.
-- 3. Le rangement de l'heure efface les vues de plus de trente jours.
--
-- Une seule transaction ; s'arrête sans rien changer si la table existe déjà ou si 20261029140000 manque.

begin;

do $garde$
begin
  if to_regclass('smarves.doublure_vues') is not null then
    raise exception 'smarves.doublure_vues existe déjà : migration abandonnée sans aucun changement';
  end if;
  if to_regprocedure('smarves.lieu_nom(text)') is null then
    raise exception 'appliquer 20261029140000 d''abord : migration abandonnée sans aucun changement';
  end if;
end
$garde$;

create table smarves.doublure_vues (
  doublure text not null references smarves.doublures (id) on delete cascade,
  genre text not null check (genre in ('oeil', 'dessus', 'dedans')),
  quand timestamptz not null default now(),
  lieu text check (lieu is null or lieu ~ '^[a-z0-9_]{1,40}$'),
  image text not null check (char_length(image) between 100 and 600000 and image ~ '^/9j/[A-Za-z0-9+/]+=*$'),
  primary key (doublure, genre)
);
alter table smarves.doublure_vues enable row level security;
revoke all on smarves.doublure_vues from public, anon, authenticated;

create function smarves.pensionnaire_vues(p_id text)
  returns table (genre text, quand timestamptz, lieu text, lieu_nom text, image text)
  language sql stable security invoker set search_path = ''
as $$
  select v.genre, v.quand, v.lieu, smarves.lieu_nom(v.lieu), v.image
    from smarves.doublure_vues v
   where v.doublure = p_id
   order by v.quand desc
$$;
revoke all on function smarves.pensionnaire_vues(text) from public, anon, authenticated;

-- Le rangement de l'heure : celui de 20261029140000, plus les vues de plus de trente jours.
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
  delete from smarves.doublure_vues where quand < now() - interval '30 days';
$$;
revoke all on function smarves.doublures_ranger() from public;

commit;
