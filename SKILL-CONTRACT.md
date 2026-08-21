# Contratto delle skill

Ogni skill in questa repo — nostra o di terzi — rispetta queste caratteristiche.
`./validate.sh` le verifica automaticamente e gira in CI su ogni push.

## Obbligatorio (blocca il commit)

1. **Una cartella, un `SKILL.md`.** In `skills/` se è nostra, in `third-party/` se
   arriva da fuori.
2. **Frontmatter YAML** all'inizio del file, tra due righe `---`, con almeno `name` e
   `description`.
3. **`name` kebab-case minuscolo, identico al nome della cartella.** Se divergono,
   `install.sh` collega una cartella e l'agent ne cerca un'altra.
4. **`description` di almeno 40 caratteri che dica cosa fa *e quando usarla*.**
   È l'unico testo che l'agent legge per decidere se attivare la skill: tutto il resto
   del file viene caricato solo *dopo* che la decisione è stata presa. Una description
   vaga significa una skill che non si attiva mai.
5. **Nessun link interno rotto** verso `references/`, `scripts/`, `assets/`, `tests/`.
6. **Nessuna chiave o segreto committato** (JWT, `sb_secret_…`, service role key).
7. **Skill di terzi: `SOURCE.md` obbligatorio** con origine, licenza, versione/commit e
   modifiche locali. Vedi `third-party/README.md`.
8. **Nomi univoci** tra `skills/` e `third-party/`: in caso di collisione ne verrebbe
   collegata una sola, in modo non deterministico.

## Consigliato (warning, non blocca)

- **`SKILL.md` sotto le 500 righe.** Quello che serve raramente va in `references/` e
  viene letto solo al bisogno. Il corpo della skill occupa contesto ogni volta che si
  attiva; le reference no.
- **Description sotto i 1024 caratteri**, per non rischiare il troncamento.
- **Un `LICENSE`** copiato dall'upstream per ogni skill di terzi.
- **Una riga nell'indice del README.**

## Come scrivere la description

È la parte che conta davvero. Regole pratiche:

- Elenca i **termini che useresti tu**, non quelli canonici: "RLS", "policy", "l'utente
  vede dati che non dovrebbe", "la query torna vuota".
- Includi i **messaggi d'errore** tipici. Sono l'innesco più affidabile in assoluto,
  perché quando incolli un errore l'innesco è letterale.
- Dichiara anche **quando NON usarla**, se il confine è ambiguo con un'altra skill.
- Scrivila in terza persona, descrittiva: "Usa questa skill quando…".

Confronto:

```yaml
# ✗ non si attiverà quasi mai
description: Aiuta con Supabase.

# ✓
description: Progettare, scrivere, correggere e verificare le Row Level Security policy
  di Supabase/Postgres. Usa questa skill quando si parla di RLS, policy, multi-tenant,
  auth.uid(), service_role, "la query torna vuota", "new row violates row-level security
  policy", "infinite recursion detected in policy", o quando si crea una nuova tabella.
```

## Come scrivere il corpo

- **Istruzioni imperative**, non descrizioni. "Wrappa `auth.uid()` in `(select …)`", non
  "è possibile wrappare".
- **Procedure numerate** dove l'ordine conta.
- **Tabelle sintomo → causa → fix** per il debug: è il formato che si consulta più in
  fretta.
- **Checklist di verifica** finale, così la skill sa quando ha finito.
- Niente preamboli sul "cos'è" la tecnologia: l'agent lo sa già. Serve ciò che sbaglia.

## Flusso per una skill nuova

```bash
cp -r _template skills/<nome-skill>
$EDITOR skills/<nome-skill>/SKILL.md
./validate.sh <nome-skill>
./install.sh <nome-skill>
# aggiungi la riga nell'indice del README, poi commit
```
