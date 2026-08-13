# cloude-skill

Collezione centralizzata di skill riutilizzabili in **Claude Code** e **Cursor**,
su tutti i progetti.

Ogni skill vive in una cartella con un `SKILL.md` che contiene il frontmatter
(`name`, `description`) e le istruzioni operative.

Apri `cloude-skill.code-workspace` (o aggiungi questa cartella a un workspace
esistente) per vederla in Explorer come **cloude skill**. Le skill sono già
collegate in `.claude/skills` e `.cursor/skills` di questa repo: aprirla basta
per usarle qui. Per tutti gli altri progetti, una volta: `./install.sh`.

## Struttura

```
skills/                      # skill nostre
  <nome-skill>/
    SKILL.md                 # obbligatorio: frontmatter + istruzioni
    references/              # opzionale: approfondimenti, letti solo al bisogno
    scripts/                 # opzionale: script eseguibili
    assets/                  # opzionale: template, file di supporto
third-party/                 # skill di terzi, con SOURCE.md di provenienza
_template/SKILL.md           # punto di partenza per una skill nuova
install.sh                   # symlink globali + .claude/skills e .cursor/skills in repo
cloude-skill.code-workspace  # nome in sidebar: "cloude skill"
.claude/skills               # skill visibili a Claude Code in questa repo
.cursor/skills               # skill visibili a Cursor Agent in questa repo
```

## Sidebar

Per tenerla visibile mentre lavori su un altro progetto:

1. Clona questa repo in un posto fisso (es. `~/code/cloude-skill`).
2. In Cursor: **File → Add Folder to Workspace…** e scegli il clone.
3. Oppure apri `cloude-skill.code-workspace`: in Explorer la cartella si chiama **cloude skill**.

## Installazione

`./install.sh` collega le skill in quattro posti:

- `~/.claude/skills` e `~/.cursor/skills` — tutte le sessioni di questa macchina
- `.claude/skills` e `.cursor/skills` in questa repo — aprirla o aggiungerla
  in sidebar basta per usarle senza install globale

Modificare un file in `skills/` o `third-party/` aggiorna il comportamento ovunque
senza reinstallare niente.

```bash
./install.sh                 # tutte le skill (skills/ + third-party/)
./install.sh supabase-rls    # solo quelle indicate
./install.sh --list          # cosa è installato e dove punta
./install.sh --prune         # rimuove i symlink orfani di questa repo
```

Lo script non sovrascrive mai una cartella reale già presente nella destinazione:
in quel caso segnala il conflitto e passa oltre. Destinazioni modificabili con
`CLAUDE_SKILLS_DIR` e `CURSOR_SKILLS_DIR`.

Conseguenza da tenere presente: il progetto che usa la skill **non** la contiene. Su
un'altra macchina, o per un collaboratore, va rifatto il clone di questa repo +
`./install.sh`. Se una skill deve viaggiare insieme al progetto, copiarla dentro
`.claude/skills/` o `.cursor/skills/` del progetto invece di collegarla.

## Aggiungere una skill nuova

```bash
cp -r _template skills/<nome-skill>
```

Poi si compila `SKILL.md` e si aggiorna l'indice qui sotto.

- `name`: minuscolo, kebab-case, uguale al nome della cartella.
- `description`: è il **solo** testo che Claude/Cursor legge per decidere se attivare la skill.
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
| [`impeccable`](third-party/impeccable/SKILL.md) | Design frontend per agent: init/document, shape, critique, audit, polish, animate, layout, typeset e altri comandi; evita l'estetica AI generica | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) |
