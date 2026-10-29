-- Retour arrière de la migration 20261030000000_smarves_pensionnaires_inscription.sql (chtabay/lasso#13).
-- Retire le point d'entrée d'inscription et l'unicité des noms ; ne touche à aucun pensionnaire, ni à ceux
-- créés par l'inscription. À coller dans l'éditeur SQL, après avoir retiré la clé publique de la fonction.
begin;

drop function if exists smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text);
drop function if exists smarves.inscription_debit(text, integer);
drop table if exists smarves.inscriptions, smarves.inscription_jetons, smarves.inscription_debit;
drop index if exists smarves.joueurs_pensionnaire_nom;
drop function if exists smarves.nom_cle(text);

-- doublure_ouvrir telle que la laissait 20261024220000_smarves_pensionnaires_connecteur.sql.
create or replace function smarves.doublure_ouvrir(p_id text, p_humain text, p_nom text, p_personnalite text,
    p_fournisseur text, p_modele text, p_adresse text, p_cle_chiffree text, p_cle_fin text, p_reveils integer,
    p_pecule bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
begin
  if p_id !~ '^doublure:[a-z0-9]{12,40}$' then raise exception 'identifiant invalide'; end if;
  if p_humain like 'doublure:%' then raise exception 'une doublure n''a pas de doublure'; end if;
  if exists (select 1 from smarves.doublures where humain = p_humain) then return json_build_object('ok', false, 'raison', 'deja'); end if;
  insert into smarves.joueurs (pyramide_id, nom) values (p_id, p_nom);
  insert into smarves.argent_comptes (pyramide_id, solde) values (p_id, p_pecule);
  insert into smarves.argent_mouvements (pyramide_id, cle, source, motif, montant, solde_apres)
    values (p_id, 'ouverture:' || substr(p_id, 10), 'doublure', 'ouverture', p_pecule, p_pecule);
  insert into smarves.doublures (id, humain, personnalite, mode, fournisseur, modele, adresse, cle_chiffree, cle_fin, reveils_semaine)
    values (p_id, p_humain, p_personnalite, case when p_cle_chiffree is null then 'agent' else 'cle' end,
      p_fournisseur, p_modele, p_adresse, p_cle_chiffree, p_cle_fin, p_reveils);
  return json_build_object('ok', true);
end $$;
revoke all on function smarves.doublure_ouvrir(text, text, text, text, text, text, text, text, text, integer, bigint) from public;

commit;

