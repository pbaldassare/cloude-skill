# cloude-skill

Collezione centralizzata di **Claude Skills** riutilizzabili negli altri progetti.

Ogni skill vive in una cartella con un `SKILL.md` che contiene il frontmatter
(`name`, `description`) e le istruzioni operative.

## Struttura

```
skills/                 # skill nostre
  <nome-skill>/
    SKILL.md            # obbligatorio: frontmatter + istruzioni
    references/         # opzionale: approfondimenti, letti solo al bisogno
    scripts/            # opzionale: script eseguibili
    assets/             # opzionale: template, file di supporto
third-party/            # skill di terzi, con SOURCE.md di provenienza
_template/SKILL.md      # punto di partenza per una skill nuova
install.sh              # symlink delle skill in ~/.claude/skills
```

## Installazione

Le skill vengono collegate in `~/.claude/skills` con dei symlink: sono così disponibili
in **tutte** le sessioni Claude Code della macchina (CLI, VS Code, Cursor), e modificare
un file qui aggiorna il comportamento ovunque senza reinstallare niente.

```bash
./install.sh                 # tutte le skill (skills/ + third-party/)
./install.sh supabase-rls    # solo quelle indicate
./install.sh --list          # cosa è installato e dove punta
./install.sh --prune         # rimuove i symlink orfani di questa repo
```

Lo script non sovrascrive mai una cartella reale già presente in `~/.claude/skills`:
in quel caso segnala il conflitto e passa oltre. Destinazione modificabile con
`CLAUDE_SKILLS_DIR`.

Conseguenza da tenere presente: il progetto che usa la skill **non** la contiene. Su
un'altra macchina, o per un collaboratore, va rifatto il clone di questa repo +
`./install.sh`. Se una skill deve viaggiare insieme al progetto, copiarla dentro
`.claude/skills/` del progetto invece di collegarla.

## Aggiungere una skill nuova

```bash
cp -r _template skills/<nome-skill>
```

Poi si compila `SKILL.md` e si aggiorna l'indice qui sotto.

- `name`: minuscolo, kebab-case, uguale al nome della cartella.
- `description`: è il **solo** testo che Claude legge per decidere se attivare la skill.
  Deve dire *cosa fa* e *quando usarla*, con i termini che l'utente userebbe davvero —
  inclusi i messaggi d'errore tipici, che sono l'innesco più affidabile.
- Corpo sotto le ~500 righe: quello che serve raramente va in `references/` e viene
  letto solo al bisogno.
- Istruzioni imperative e concrete, non descrizioni generiche.

## Aggiungere una skill di terzi

Va in `third-party/<nome>/` con un `SOURCE.md` che dichiara origine, licenza, commit di
riferimento e modifiche locali. Dettagli in `third-party/README.md`.

## Indice skill

| Skill | Descrizione | Origine |
|---|---|---|
| [`supabase-rls`](skills/supabase-rls/SKILL.md) | Progettazione, scrittura, debug e verifica delle policy RLS su Supabase/Postgres: multi-tenant, security definer, performance, trappole ricorrenti | nostra |
