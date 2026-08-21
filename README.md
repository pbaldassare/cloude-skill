# cloude-skill

Collezione centralizzata di skill riutilizzabili in **Claude Code** e **Cursor**,
su tutti i progetti. Vive su GitHub: qualsiasi macchina o sessione, anche remota,
può tirarle giù da sola.

Ogni skill è una cartella con un `SKILL.md` (frontmatter + istruzioni) che rispetta il
[contratto](SKILL-CONTRACT.md), verificato da `./validate.sh` e dalla CI a ogni push.

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

bootstrap.sh                 # da GitHub a macchina pronta, in un comando
install.sh                   # symlink delle skill nelle destinazioni note
setup-project.sh             # configura un progetto perché se le tiri giù da solo
validate.sh                  # verifica il contratto delle skill
hooks/session-start.sh       # hook da copiare nei progetti
```

## Accesso alle skill: i tre scenari

### 1. La tua macchina (Claude Code CLI, desktop, Cursor)

Un comando, anche senza aver clonato niente:

```bash
curl -fsSL https://raw.githubusercontent.com/pbaldassare/cloude-skill/HEAD/bootstrap.sh | bash
```

Clona la repo in `~/.local/share/cloude-skill` e collega ogni skill in
`~/.claude/skills` e `~/.cursor/skills`. Da quel momento sono attive in **tutte** le
sessioni della macchina. Per aggiornarle: `~/.local/share/cloude-skill/bootstrap.sh`.

Se hai già il clone, `./bootstrap.sh` usa quello invece di farne un secondo.

### 2. Sessioni remote (Claude Code sul web, container CI)

Lì `~/.claude/skills` non esiste: il container clona solo il repo del progetto. La
soluzione è un SessionStart hook nel progetto, che all'avvio tira giù le skill da
GitHub e le collega:

```bash
./setup-project.sh ~/code/mio-progetto
```

Copia `hooks/session-start.sh` in `<progetto>/.claude/hooks/cloude-skill.sh`, lo
registra in `.claude/settings.json` e ignora `.claude/skills/` nel git del progetto.
Committa quei due file nel progetto: da lì in poi ogni sessione, locale o remota, ha le
skill senza fare niente.

L'hook è deliberatamente conservativo: rifetcha al massimo ogni 6 ore, e se GitHub non
risponde usa la cache ed esce 0 — **non blocca mai** l'avvio della sessione.

### 3. Progetto autonomo (collaboratori, CI senza rete verso GitHub)

```bash
./setup-project.sh ~/code/mio-progetto --copy
```

Copia le skill dentro il progetto invece di collegarle. Contropartita: non si aggiornano
più quando modifichi questa repo. Da usare solo quando il progetto deve funzionare senza
dipendere da qui.

## install.sh

`bootstrap.sh` e l'hook lo chiamano da soli; serve direttamente solo per collegare
qualcosa a mano.

```bash
./install.sh                 # tutte le skill (skills/ + third-party/)
./install.sh supabase-rls    # solo quelle indicate
./install.sh --list          # cosa è installato e dove punta
./install.sh --prune         # rimuove i symlink orfani di questa repo
```

Collega in `~/.claude/skills`, `~/.cursor/skills` e nelle cartelle `.claude/skills` /
`.cursor/skills` di questa repo. Non sovrascrive mai una cartella reale già presente:
segnala il conflitto e passa oltre. Destinazioni modificabili con `CLAUDE_SKILLS_DIR` e
`CURSOR_SKILLS_DIR`.

Essendo symlink, modificare un file in `skills/` o `third-party/` aggiorna il
comportamento ovunque senza reinstallare niente.

## Aggiungere una skill

```bash
cp -r _template skills/<nome-skill>
$EDITOR skills/<nome-skill>/SKILL.md
./validate.sh <nome-skill>
./install.sh <nome-skill>
```

Poi una riga nell'indice qui sotto e commit. Le regole che ogni skill deve rispettare —
e soprattutto **come si scrive una description che faccia attivare la skill** — stanno
in [SKILL-CONTRACT.md](SKILL-CONTRACT.md).

Per una skill di terzi: va in `third-party/<nome>/` con un `SOURCE.md` che dichiara
origine, licenza, commit e modifiche locali. Dettagli in
[third-party/README.md](third-party/README.md).

## validate.sh

```bash
./validate.sh                # tutte
./validate.sh supabase-rls   # una sola
```

Controlla frontmatter, coerenza `name` ↔ cartella, description utilizzabile come
innesco, link interni, dimensione, `SOURCE.md` e licenza per le skill di terzi,
collisioni di nome, chiavi committate per sbaglio. Gira in CI su ogni push: una skill
che non rispetta il contratto fa fallire il check.

## Sidebar in Cursor

Per tenerla visibile mentre lavori su un altro progetto: apri
`cloude-skill.code-workspace`, oppure **File → Add Folder to Workspace…** sul clone.
Le skill sono già collegate in `.claude/skills` e `.cursor/skills` di questa repo,
quindi aprirla basta per usarle qui.

## Indice skill

| Skill | Descrizione | Origine |
|---|---|---|
| [`supabase-rls`](skills/supabase-rls/SKILL.md) | Progettazione, scrittura, debug e verifica delle policy RLS su Supabase/Postgres: multi-tenant, security definer, performance, trappole ricorrenti | nostra |
| [`impeccable`](third-party/impeccable/SKILL.md) | Design frontend per agent: init/document, shape, critique, audit, polish, animate, layout, typeset e altri comandi; evita l'estetica AI generica | [pbakaus/impeccable](https://github.com/pbakaus/impeccable) |
| [`crawl4ai`](third-party/crawl4ai/SKILL.md) | Crawl e estrazione dati da pagine web (anche JS): markdown LLM-ready, schema CSS/JSON, batch crawl, pipeline; SDK + script pronti | [unclecode/crawl4ai](https://github.com/unclecode/crawl4ai) |
