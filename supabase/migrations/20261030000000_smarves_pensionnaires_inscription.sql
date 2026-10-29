-- Smarves, l'inscription d'un pensionnaire depuis Lasso (chtabay/lasso#13) : un nom unique, et un point
-- d'entrée qui crée ou restitue le pensionnaire d'un humain sur la seule preuve d'une autorisation signée
-- par Pyramides2 (portée « smarves-inscription », Ed25519, deux minutes, usage unique). La fonction
-- `doublures` (chtabay/addict) vérifie la signature ; cette migration tient le reste, en une transaction :
-- l'anti-rejeu, l'idempotence, l'unicité sous concurrence, le joueur qui n'a jamais joué.
--
-- - Un nom par pensionnaire : index unique sur une clé de nom (casse, accents, espaces, apostrophes et
--   tirets ignorés, suffixe « (pensionnaire) » retiré), valable pour tous les chemins de création.
-- - smarves.doublure_ouvrir rend une raison (« deja », « nom ») au lieu d'une erreur quand l'unicité refuse.
-- - smarves.inscription_jetons : les `jti` déjà vus ; smarves.inscriptions : ce que chaque inscription a donné.
-- - smarves.doublure_inscrire : créer ou adopter ; jamais de lecture ni d'écriture de mémoire, de journal,
--   de réglages ou de clé, jamais d'effacement.
-- - smarves.inscription_debit : une limite d'appels par fenêtre d'une minute (la vérification sans jeton).
-- Rien de ce schéma ne sort par l'API publique ; aucune fonction n'est accordée à anon, authenticated, ni au
-- rôle lasso_server.

-- --- La garde : rien ne change si deux pensionnaires portent déjà la même clé de nom -----------------

-- Tout ou rien : la garde qui s'arrête annule aussi ce qui la précède.
begin;

create or replace function smarves.nom_cle(p text) returns text
  language sql immutable strict parallel safe set search_path = ''
as $$
  select btrim(regexp_replace(
    translate(lower(regexp_replace(p, '\s*\(pensionnaire\)\s*$', '')),
      'àâäáãåāçćčéèêëēęíìîïīñńóòôöõøōúùûüūýÿžźżšœæ’''-',
      'aaaaaaaccceeeeeeiiiiinnooooooouuuuuyyzzzsoa   '),
    '\s+', ' ', 'g'))
$$;

do $garde$
begin
  if exists (select 1 from pg_class where relname = 'joueurs_pensionnaire_nom' and relnamespace = 'smarves'::regnamespace)
    or to_regclass('smarves.inscriptions') is not null or to_regclass('smarves.inscription_jetons') is not null then
    raise exception 'smarves inscription : objets déjà présents ; migration abandonnée sans aucun changement';
  end if;
  if exists (select smarves.nom_cle(nom) from smarves.joueurs where pyramide_id like 'doublure:%'
             group by 1 having count(*) > 1) then
    raise exception 'smarves inscription : deux pensionnaires portent déjà le même nom ; migration abandonnée sans aucun changement';
  end if;
end
$garde$;

create unique index joueurs_pensionnaire_nom on smarves.joueurs (smarves.nom_cle(nom)) where pyramide_id like 'doublure:%';

-- --- L'ouverture rend une raison quand l'unicité refuse, même sous concurrence --------------------

create or replace function smarves.doublure_ouvrir(p_id text, p_humain text, p_nom text, p_personnalite text,
    p_fournisseur text, p_modele text, p_adresse text, p_cle_chiffree text, p_cle_fin text, p_reveils integer,
    p_pecule bigint) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  contrainte text;
begin
  if p_id !~ '^doublure:[a-z0-9]{12,40}$' then raise exception 'identifiant invalide'; end if;
  if p_humain like 'doublure:%' then raise exception 'une doublure n''a pas de doublure'; end if;
  if exists (select 1 from smarves.doublures where humain = p_humain) then return json_build_object('ok', false, 'raison', 'deja'); end if;
  begin
    insert into smarves.joueurs (pyramide_id, nom) values (p_id, p_nom);
    insert into smarves.argent_comptes (pyramide_id, solde) values (p_id, p_pecule);
    insert into smarves.argent_mouvements (pyramide_id, cle, source, motif, montant, solde_apres)
      values (p_id, 'ouverture:' || substr(p_id, 10), 'doublure', 'ouverture', p_pecule, p_pecule);
    insert into smarves.doublures (id, humain, personnalite, mode, fournisseur, modele, adresse, cle_chiffree, cle_fin, reveils_semaine)
      values (p_id, p_humain, p_personnalite, case when p_cle_chiffree is null then 'agent' else 'cle' end,
        p_fournisseur, p_modele, p_adresse, p_cle_chiffree, p_cle_fin, p_reveils);
  exception when unique_violation then
    get stacked diagnostics contrainte = constraint_name;
    if contrainte = 'doublures_humain_key' then return json_build_object('ok', false, 'raison', 'deja'); end if;
    if contrainte = 'joueurs_pensionnaire_nom' then return json_build_object('ok', false, 'raison', 'nom'); end if;
    raise;
  end;
  return json_build_object('ok', true);
end $$;

-- --- L'inscription --------------------------------------------------------------------------------

create table smarves.inscription_jetons (
  jti text primary key check (jti ~ '^[A-Za-z0-9_-]{16,64}$'),
  humain text not null,
  exp timestamptz not null,
  vu timestamptz not null default now()
);
create index inscription_jetons_humain on smarves.inscription_jetons (humain, vu);

create table smarves.inscriptions (
  -- L'identifiant d'inscription tiré par Lasso (`ins` du jeton) : rejouer la même inscription rend le même résultat.
  ins uuid primary key,
  humain text not null,
  op text not null check (op in ('creer', 'adopter')),
  dem text check (dem ~ '^[0-9a-f]{64}$'),
  doublure text not null,
  resultat text not null check (resultat in ('cree', 'adopte')),
  cree timestamptz not null default now()
);
create index inscriptions_humain on smarves.inscriptions (humain);

create table smarves.inscription_debit (
  cle text not null check (cle ~ '^[0-9a-f]{64}$'),
  fenetre timestamptz not null,
  n integer not null default 1,
  primary key (cle, fenetre)
);

alter table smarves.inscription_jetons enable row level security;
alter table smarves.inscriptions enable row level security;
alter table smarves.inscription_debit enable row level security;
revoke all on smarves.inscription_jetons, smarves.inscriptions, smarves.inscription_debit from public, anon, authenticated;

-- Créer (p_op = 'creer') ou adopter (p_op = 'adopter') le pensionnaire de p_humain, qui est le `sub` d'un
-- jeton déjà vérifié par la fonction, jamais un identifiant fourni par Lasso. Le nom, l'histoire, les envies,
-- les besoins et le mot de l'allure ont déjà passé les validations de la fonction (regles.js, allure.js).
-- Rend {ok, resultat ('cree', 'adopte', 'deja_fait'), id, nom} ou {ok: false, raison}.
create or replace function smarves.doublure_inscrire(p_jti text, p_exp timestamptz, p_humain text, p_nom_pyramides text,
    p_op text, p_ins uuid, p_id text, p_nom text, p_caractere text, p_envies text, p_besoins text, p_tenue text,
    p_reveils integer, p_pecule bigint, p_dem text) returns json
  language plpgsql security definer set search_path = ''
as $$
declare
  i smarves.inscriptions;
  d text;
  o json;
  n text;
begin
  if p_humain is null or p_humain !~ '^[A-Za-z0-9_-]{1,64}$' then raise exception 'humain invalide'; end if;
  if p_op is null or p_op not in ('creer', 'adopter') then raise exception 'operation invalide'; end if;
  if p_ins is null or p_exp is null then raise exception 'inscription invalide'; end if;
  if (p_op = 'creer' and (p_dem is null or p_dem !~ '^[0-9a-f]{64}$'))
     or (p_op = 'adopter' and p_dem is not null) then raise exception 'demande invalide'; end if;

  -- Le jeton ne sert qu'une fois : un second usage ne fait rien et ne dit rien.
  delete from smarves.inscription_jetons where exp < now() - interval '1 day';
  insert into smarves.inscription_jetons (jti, humain, exp) values (p_jti, p_humain, p_exp) on conflict (jti) do nothing;
  if not found then return json_build_object('ok', false, 'raison', 'rejeu'); end if;

  -- Une clé absente ne peut pas être verrouillée par SELECT FOR UPDATE. Ce verrou transactionnel
  -- sérialise tous les jti du même ins, y compris avant la première ligne et jusqu'au COMMIT.
  perform pg_advisory_xact_lock(hashtextextended('smarves:ins:' || p_ins::text, 0));

  -- La même inscription, reprise par un nouveau clic : le même résultat, sans nouvel effet.
  select * into i from smarves.inscriptions where ins = p_ins;
  if i.ins is not null then
    if i.humain <> p_humain or i.op <> p_op or i.dem is distinct from p_dem then
      return json_build_object('ok', false, 'raison', 'inscription');
    end if;
    select j.nom into n from smarves.doublures x join smarves.joueurs j on j.pyramide_id = x.id
      where x.id = i.doublure and x.humain = p_humain;
    if n is null then return json_build_object('ok', false, 'raison', 'aucun_pensionnaire'); end if;
    return json_build_object('ok', true, 'resultat', 'deja_fait', 'id', i.doublure, 'nom', n);
  end if;

  perform pg_advisory_xact_lock(hashtextextended('smarves:ins-humain:' || p_humain, 0));
  if (select count(*) from smarves.inscription_jetons where humain = p_humain and vu > now() - interval '1 hour') > 10 then
    return json_build_object('ok', false, 'raison', 'trop');
  end if;

  -- Un compte Pyramides2 qui n'a jamais joué : sa ligne de joueur, comme à sa première connexion au jeu.
  insert into smarves.joueurs (pyramide_id, nom) values (p_humain, left(coalesce(nullif(btrim(p_nom_pyramides), ''), 'Joueur'), 80))
    on conflict (pyramide_id) do nothing;

  if p_op = 'adopter' then
    select x.id, j.nom into d, n from smarves.doublures x join smarves.joueurs j on j.pyramide_id = x.id where x.humain = p_humain;
    if d is null then return json_build_object('ok', false, 'raison', 'aucun_pensionnaire'); end if;
    insert into smarves.inscriptions (ins, humain, op, doublure, resultat) values (p_ins, p_humain, p_op, d, 'adopte');
    return json_build_object('ok', true, 'resultat', 'adopte', 'id', d, 'nom', n);
  end if;

  if p_nom is null or p_caractere is null then raise exception 'creation incomplete'; end if;
  o := smarves.doublure_ouvrir(p_id, p_humain, p_nom, 'autre', null, null, null, null, null, p_reveils, p_pecule);
  if not (o->>'ok')::boolean then
    return json_build_object('ok', false, 'raison', case o->>'raison' when 'nom' then 'nom_pris' else 'deja_pensionnaire' end);
  end if;
  update smarves.doublures set caractere = p_caractere, envies = p_envies, besoins = p_besoins where id = p_id;
  if p_tenue is not null then
    insert into smarves.doublure_corps (doublure, membre, tenue) values (p_id, smarves.membre(p_id), p_tenue);
  end if;
  insert into smarves.inscriptions (ins, humain, op, dem, doublure, resultat) values (p_ins, p_humain, p_op, p_dem, p_id, 'cree');
  return json_build_object('ok', true, 'resultat', 'cree', 'id', p_id, 'nom', p_nom);
end $$;

-- Au plus p_max appels par minute pour une clé (l'empreinte d'une adresse) : true si celui-ci passe.
create or replace function smarves.inscription_debit(p_cle text, p_max integer) returns boolean
  language plpgsql security definer set search_path = ''
as $$
declare
  f timestamptz := date_trunc('minute', now());
  k integer;
begin
  delete from smarves.inscription_debit where fenetre < f - interval '10 minutes';
  insert into smarves.inscription_debit as d (cle, fenetre) values (p_cle, f)
    on conflict (cle, fenetre) do update set n = d.n + 1 returning n into k;
  return k <= p_max;
end $$;

revoke all on function smarves.nom_cle(text),
  smarves.doublure_ouvrir(text, text, text, text, text, text, text, text, text, integer, bigint),
  smarves.doublure_inscrire(text, timestamptz, text, text, text, uuid, text, text, text, text, text, text, integer, bigint, text),
  smarves.inscription_debit(text, integer) from public, anon, authenticated;

commit;

