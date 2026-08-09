---
name: supabase-rls
description: Progettare, scrivere, correggere e verificare le Row Level Security policy di Supabase/Postgres. Usa questa skill ogni volta che si parla di RLS, policy, permessi sui dati, multi-tenant, isolamento per organizzazione/utente, auth.uid(), service_role, chiavi anon/publishable, "l'utente vede dati che non dovrebbe", "la query torna vuota / 0 righe", "new row violates row-level security policy", "infinite recursion detected in policy", query lente dopo aver attivato RLS, security definer, o quando si crea una nuova tabella in un progetto Supabase.
---

# Supabase + RLS

RLS è **il** confine di sicurezza di un progetto Supabase. La chiave anon/publishable è
pubblica per design: finisce nel bundle JS, chiunque la può leggere. L'unica cosa che
separa i dati di un tenant da quelli di un altro sono le policy. Se RLS è spento su una
tabella in `public`, quella tabella è leggibile e scrivibile da Internet.

## Regole non negoziabili

1. **RLS attiva su ogni tabella dello schema `public`.** Nessuna eccezione, nemmeno le
   tabelle "di lookup". Senza policy + RLS attiva la tabella è aperta.
2. **`service_role` bypassa RLS.** Vive solo in edge function / backend / CI. Mai nel
   frontend, mai in una variabile `VITE_*` / `NEXT_PUBLIC_*` / in Lovable lato client.
3. **Mai fidarsi di `user_metadata`.** È scrivibile dall'utente stesso via
   `supabase.auth.updateUser()`. Per ruoli e tenant si usa `app_metadata` (scrivibile
   solo con service_role) o una tabella di appartenenza.
4. **Attivare RLS non basta.** `enable row level security` senza policy = nessuno legge
   niente. Il sintomo classico è "la query torna array vuoto senza errore".
5. **Le modifiche di schema passano da una migration** (`apply_migration` via MCP o
   `supabase migration new`), non da SQL eseguito a mano nell'editor.

## Flusso di lavoro

Quando si crea o si mette in sicurezza una tabella:

1. `list_tables` per capire lo schema esistente e come è già modellato il tenant.
2. Stabilire **chi è il proprietario della riga**: l'utente (`user_id`) o
   l'organizzazione (`org_id` / `tenant_id`). Questa colonna va sulla tabella, anche a
   costo di denormalizzare — è ciò che rende le policy veloci e semplici.
3. Scrivere le policy **una per operazione** (`select`, `insert`, `update`, `delete`),
   non una `for all`. Semantica più chiara e permessi asimmetrici gestibili.
4. Creare l'indice sulla colonna usata dalla policy.
5. Testare con un JWT finto (vedi `references/recipes.md`, sezione Test).
6. `get_advisors` con `type: "security"` per verificare che non sia rimasto niente scoperto.

## Anatomia di una policy

```sql
alter table public.documents enable row level security;

create policy "documents_select_own"
on public.documents
for select
to authenticated
using ( (select auth.uid()) = user_id );

create policy "documents_insert_own"
on public.documents
for insert
to authenticated
with check ( (select auth.uid()) = user_id );

create policy "documents_update_own"
on public.documents
for update
to authenticated
using ( (select auth.uid()) = user_id )
with check ( (select auth.uid()) = user_id );

create policy "documents_delete_own"
on public.documents
for delete
to authenticated
using ( (select auth.uid()) = user_id );

create index on public.documents (user_id);
```

Quattro dettagli che contano:

- **`using` vs `with check`**: `using` filtra le righe *esistenti* (select, update, delete);
  `with check` valida i valori della riga *nuova* (insert, update). Su `update` servono
  entrambe, altrimenti l'utente può leggere la propria riga e riassegnarla a un altro
  `user_id`.
- **`to authenticated`**: senza il `to`, la policy vale anche per `anon`. Specificare
  sempre il ruolo.
- **`(select auth.uid())` e non `auth.uid()`**: la sottoquery viene valutata una volta
  sola come InitPlan invece che per ogni riga. Su tabelle grandi è una differenza di
  ordini di grandezza — è l'ottimizzazione singola più importante di RLS.
- **L'indice**: la policy diventa un `WHERE`. Senza indice sulla colonna, seq scan.

## Multi-tenant (il caso SaaS tipico)

Modello: `organizations` → `memberships (user_id, org_id, role)` → tabelle di dominio
con `org_id`.

Il problema che si incontra sempre: la policy su `memberships` che interroga
`memberships` genera `infinite recursion detected in policy for relation "memberships"`.
Si risolve con una funzione `security definer`, che esegue con i privilegi del creatore
e quindi **non riapplica RLS** alla tabella interrogata:

```sql
create or replace function public.user_org_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
  select org_id from public.memberships where user_id = (select auth.uid());
$$;

revoke execute on function public.user_org_ids() from public;
grant execute on function public.user_org_ids() to authenticated;
```

`set search_path = ''` è obbligatorio: senza, la funzione è vulnerabile a search_path
hijacking (per questo tutti i riferimenti interni sono qualificati con `public.`).

Policy risultante:

```sql
create policy "invoices_select_org"
on public.invoices for select to authenticated
using ( org_id in (select public.user_org_ids()) );

create index on public.invoices (org_id);
```

Ruoli differenziati (solo gli admin cancellano) e il resto dei pattern ricorrenti stanno
in `references/recipes.md`.

## Trappole ricorrenti

| Sintomo | Causa | Fix |
|---|---|---|
| Query torna `[]` senza errore | RLS attiva, nessuna policy `select` che matcha | Aggiungere la policy; verificare il ruolo (`anon` vs `authenticated`) |
| `new row violates row-level security policy` | Manca `with check` sull'insert, o il client non sta impostando `user_id` | Aggiungere la policy insert; meglio: `default auth.uid()` sulla colonna |
| `infinite recursion detected in policy` | La policy interroga la stessa tabella che protegge | Funzione `security definer` con `search_path = ''` |
| Tutto lento dopo aver attivato RLS | `auth.uid()` non wrappato + indice mancante | `(select auth.uid())` + indice sulla colonna della policy |
| Una view espone dati oltre le policy | Le view girano coi privilegi del creatore | `create view ... with (security_invoker = on)` |
| Funziona in SQL editor, non dall'app | L'SQL editor gira come `postgres`, che bypassa RLS | Testare impersonando il ruolo (vedi recipes) |
| Il realtime non manda eventi | RLS filtra anche le subscription | Verificare che la policy `select` copra l'utente sottoscritto |
| Storage: file accessibili a chiunque | Bucket pubblico o policy mancanti su `storage.objects` | Bucket privato + policy sul path |

## Verifica finale

Prima di considerare chiusa la messa in sicurezza:

- [ ] `get_advisors` con `type: "security"` non riporta tabelle senza RLS né funzioni
      con search_path mutabile
- [ ] Ogni tabella in `public` ha RLS attiva e almeno una policy per ogni operazione usata
- [ ] Nessuna policy usa `auth.uid()` non wrappato
- [ ] Ogni colonna usata nelle policy ha un indice
- [ ] Le `update` policy hanno sia `using` che `with check`
- [ ] Nessuna chiave `service_role` in codice client o in variabili d'ambiente pubbliche
- [ ] Testata almeno una cross-tenant read: utente A non vede i dati di B

## Riferimenti

- `references/recipes.md` — SQL copia-incolla: ruoli e permessi asimmetrici, tabelle
  pubbliche in lettura, soft delete, storage, come testare le policy con un JWT finto,
  come debuggare con `explain`.
