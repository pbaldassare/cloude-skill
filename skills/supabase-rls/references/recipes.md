# Recipes RLS

SQL pronto all'uso per i casi che ricorrono. Adattare i nomi di tabella/colonna.

---

## Ownership: default automatico su `user_id`

Evita che il client debba mandare `user_id` (e che possa sbagliarlo o falsificarlo):

```sql
alter table public.documents
  alter column user_id set default auth.uid();

alter table public.documents
  alter column user_id set not null;
```

Con questo la policy insert diventa una rete di sicurezza, non l'unica difesa.

---

## Permessi asimmetrici per ruolo (member legge, admin scrive)

```sql
create or replace function public.user_org_role(p_org_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role
  from public.memberships
  where user_id = (select auth.uid())
    and org_id = p_org_id
  limit 1;
$$;

revoke execute on function public.user_org_role(uuid) from public;
grant execute on function public.user_org_role(uuid) to authenticated;

-- tutti i membri leggono
create policy "invoices_select_member"
on public.invoices for select to authenticated
using ( org_id in (select public.user_org_ids()) );

-- solo admin e owner scrivono
create policy "invoices_insert_admin"
on public.invoices for insert to authenticated
with check ( public.user_org_role(org_id) in ('admin', 'owner') );

create policy "invoices_update_admin"
on public.invoices for update to authenticated
using ( public.user_org_role(org_id) in ('admin', 'owner') )
with check ( public.user_org_role(org_id) in ('admin', 'owner') );

create policy "invoices_delete_owner"
on public.invoices for delete to authenticated
using ( public.user_org_role(org_id) = 'owner' );
```

---

## Tabella pubblica in lettura, scrivibile solo dal proprietario

Tipico per contenuti pubblicati (menu di un ristorante, listino, pagina vetrina):

```sql
create policy "menus_select_public"
on public.menus for select
to anon, authenticated
using ( published = true );

create policy "menus_select_own"
on public.menus for select to authenticated
using ( org_id in (select public.user_org_ids()) );
```

Due policy `select` permissive si sommano in OR: il pubblico vede solo i pubblicati,
il proprietario vede anche le bozze.

---

## Restrictive policy: vincolo che si aggiunge a tutte le altre

Le policy normali sono permissive (OR). Una `as restrictive` va in AND con tutto il
resto — utile per un kill switch globale:

```sql
create policy "no_access_if_org_suspended"
on public.invoices as restrictive
for all to authenticated
using (
  exists (
    select 1 from public.organizations o
    where o.id = invoices.org_id and o.suspended = false
  )
);
```

---

## Soft delete

```sql
create policy "documents_select_not_deleted"
on public.documents for select to authenticated
using ( (select auth.uid()) = user_id and deleted_at is null );
```

Nota: nascondere le righe cancellate a livello di policy impedisce anche all'utente
di ripristinarle. Se serve un cestino, usare una policy separata o un filtro applicativo.

---

## Custom claim dal JWT (`app_metadata`)

Solo `app_metadata` è affidabile: si scrive con service_role, l'utente non la tocca.

```sql
create policy "admin_full_access"
on public.audit_log for select to authenticated
using ( (select auth.jwt() -> 'app_metadata' ->> 'role') = 'staff' );
```

Il claim viene fotografato al login: cambiarlo richiede un refresh del token per avere
effetto sulle sessioni già aperte.

---

## Storage (bucket privato, path per organizzazione)

Convenzione di path: `<org_id>/<resto>`.

```sql
create policy "org_files_read"
on storage.objects for select to authenticated
using (
  bucket_id = 'documents'
  and ((storage.foldername(name))[1])::uuid in (select public.user_org_ids())
);

create policy "org_files_write"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'documents'
  and ((storage.foldername(name))[1])::uuid in (select public.user_org_ids())
);
```

Il bucket va creato privato. Per servire i file: signed URL, non URL pubblico.

---

## View che rispettano RLS

Di default una view gira coi privilegi di chi l'ha creata e **aggira** le policy delle
tabelle sottostanti. Da Postgres 15:

```sql
create view public.invoice_summary
with (security_invoker = on) as
select org_id, date_trunc('month', created_at) as month, sum(total) as total
from public.invoices
group by 1, 2;
```

---

## Testare le policy

Nell'SQL editor si è `postgres`, che bypassa RLS: i test lì non dimostrano nulla.
Impersonare il ruolo dentro una transazione:

```sql
begin;

select set_config('request.jwt.claims',
  json_build_object('sub', '11111111-1111-1111-1111-111111111111', 'role', 'authenticated')::text,
  true);
set local role authenticated;

-- deve tornare solo i dati di quell'utente
select count(*) from public.invoices;

rollback;
```

Il test che conta davvero è quello cross-tenant: stesso blocco con il `sub` dell'utente
B, verificando che le righe di A non compaiano. Un `count(*)` uguale per due utenti
diversi di tenant diversi è il segnale che la policy non sta filtrando.

---

## Debug: capire perché una policy è lenta

```sql
begin;
select set_config('request.jwt.claims', '{"sub":"...","role":"authenticated"}', true);
set local role authenticated;

explain (analyze, buffers)
select * from public.invoices where org_id = '...';

rollback;
```

Cosa cercare nel piano:

- **`InitPlan`** con dentro `auth.uid()` → il wrapping in `(select ...)` sta funzionando.
  Se invece `auth.uid()` appare nel filtro per riga, manca il `select`.
- **`Seq Scan`** sulla colonna della policy → manca l'indice.
- **`SubPlan`** ripetuto → la policy contiene una sottoquery valutata per riga: spostarla
  in una funzione `stable security definer`.

---

## Checklist migration per una nuova tabella

```sql
create table public.things (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users(id),
  created_at timestamptz not null default now()
);

alter table public.things enable row level security;

create index on public.things (org_id);

create policy "things_select" on public.things for select to authenticated
  using ( org_id in (select public.user_org_ids()) );

create policy "things_insert" on public.things for insert to authenticated
  with check ( org_id in (select public.user_org_ids()) );

create policy "things_update" on public.things for update to authenticated
  using ( org_id in (select public.user_org_ids()) )
  with check ( org_id in (select public.user_org_ids()) );

create policy "things_delete" on public.things for delete to authenticated
  using ( public.user_org_role(org_id) in ('admin', 'owner') );
```
