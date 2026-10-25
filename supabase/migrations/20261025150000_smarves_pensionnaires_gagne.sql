-- Smarves, le « gagné au jeu » d'un pensionnaire compte comme celui d'un joueur : la somme de ses gains,
-- qui ne baisse jamais quand il perd. net_total reste le net depuis le début (sa fiche le montre).
-- La vitrine (le classement du village) et le jeu du pilote prennent gagne_total.

alter table smarves.doublures add column if not exists gagne_total bigint not null default 0;

-- Ses gains passés, repris de ses mouvements (l'ouverture, le pécule, n'est pas un gain).
update smarves.doublures d set gagne_total = coalesce((select sum(m.montant) from smarves.argent_mouvements m
  where m.pyramide_id = d.id and m.source = 'doublure' and m.montant > 0 and m.motif not like 'ouverture%'), 0);

update smarves.vitrines v set gagne = d.gagne_total, maj = now() from smarves.doublures d where v.pyramide_id = d.id;

-- Un coup de roulette joué par la fonction : le mouvement sur son solde, sous la source « doublure ».
-- Le solde ne devient jamais négatif ; une clé rejouée ne compte qu'une fois.
create or replace function smarves.doublure_mouvement(p_id text, p_cle text, p_motif text, p_montant bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  c smarves.argent_comptes;
begin
  if p_cle is null or p_cle !~ '^[A-Za-z0-9_.:-]{8,80}$' then raise exception 'cle invalide'; end if;
  if p_montant is null or p_montant = 0 or abs(p_montant) > 100000 then raise exception 'montant invalide'; end if;
  select * into c from smarves.argent_comptes where pyramide_id = p_id for update;
  if c.pyramide_id is null then return json_build_object('ok', false, 'raison', 'compte'); end if;
  if exists (select 1 from smarves.argent_mouvements where pyramide_id = p_id and cle = p_cle) then
    return json_build_object('ok', true, 'deja', true, 'solde', c.solde);
  end if;
  if c.solde + p_montant < 0 then return json_build_object('ok', false, 'raison', 'solde', 'solde', c.solde); end if;
  update smarves.argent_comptes set solde = solde + p_montant, maj = now() where pyramide_id = p_id returning * into c;
  insert into smarves.argent_mouvements (pyramide_id, cle, source, motif, montant, solde_apres)
    values (p_id, p_cle, 'doublure', left(p_motif, 60), p_montant, c.solde);
  update smarves.doublures set net_total = net_total + p_montant, gagne_total = gagne_total + greatest(p_montant, 0),
    maj = now() where id = p_id;
  -- La vitrine : le classement du village la montre comme les autres.
  insert into smarves.vitrines as v (pyramide_id, gagne, dette, logements)
    select p_id, d.gagne_total, 0, '[]'::jsonb from smarves.doublures d where d.id = p_id
    on conflict (pyramide_id) do update set gagne = excluded.gagne, maj = now();
  return json_build_object('ok', true, 'solde', c.solde);
end $$;
