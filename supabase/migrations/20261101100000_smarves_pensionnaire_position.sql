-- Smarves, où se tient un pensionnaire sur la place (docs/PENSIONNAIRES.md, « Ce que le village a vu de lui ») :
-- sa position dans le village, pour qu'une autre application (Lasso) redessine la scène vue de dessus au lieu
-- de montrer une capture d'écran.
--
-- smarves.pensionnaire_position(id) : x et z (les unités de la scène, au demi-pas du plan du village), et
-- seulement quand il est dehors (lieu « main ») : dans une salle, ses coordonnées sont celles de la salle
-- et ne disent rien de plus que son lieu. Rien d'autre : ni son regard, ni ce qu'il voit, ni les autres.
--
-- Comme les deux lectures de 20261029140000 : SECURITY INVOKER, aucun droit pour personne ; seule une
-- fonction propriétaire du schéma (lasso.smarves_position, SECURITY DEFINER) peut s'en servir, après avoir
-- vérifié à qui est le pensionnaire et son consentement. S'arrête sans rien changer si elle existe déjà.

begin;

do $garde$
begin
  if to_regprocedure('smarves.pensionnaire_position(text)') is not null then
    raise exception 'smarves.pensionnaire_position existe déjà : migration abandonnée sans aucun changement';
  end if;
  if to_regprocedure('smarves.pensionnaire_present(text)') is null then
    raise exception 'appliquer 20261029140000 d''abord : migration abandonnée sans aucun changement';
  end if;
end
$garde$;

create function smarves.pensionnaire_position(p_id text)
  returns table (x real, z real)
  language sql stable security invoker set search_path = ''
as $$
  select (round(p.x * 2) / 2)::real, (round(p.z * 2) / 2)::real
    from smarves.doublure_pilote p
   where p.doublure = p_id and p.vivant is not null and p.lieu = 'main'
     and p.x is not null and p.z is not null
     and p.x between -1000 and 1000 and p.z between -1000 and 1000
$$;

revoke all on function smarves.pensionnaire_position(text) from public, anon, authenticated;

commit;
