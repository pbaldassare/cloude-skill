# cloude-skill

Collezione centralizzata di **Claude Skills** riutilizzabili negli altri progetti.

Ogni skill vive in `skills/<nome-skill>/` con un `SKILL.md` che contiene il frontmatter
(`name`, `description`) e le istruzioni operative.

## Struttura

```
skills/
  <nome-skill>/
    SKILL.md            # obbligatorio: frontmatter + istruzioni
    references/         # opzionale: doc di approfondimento, caricate on-demand
    scripts/            # opzionale: script eseguibili
    assets/             # opzionale: template, file di supporto
_template/
  SKILL.md              # da copiare come punto di partenza
```

## Come si usa in un altro progetto

**Opzione A — symlink (consigliata durante lo sviluppo della skill)**

```bash
ln -s /percorso/cloude-skill/skills/<nome-skill> .claude/skills/<nome-skill>
```

**Opzione B — copia (progetto autonomo / da committare)**

```bash
cp -r /percorso/cloude-skill/skills/<nome-skill> .claude/skills/
```

**Opzione C — globale per l'utente (disponibile in tutte le sessioni)**

```bash
ln -s /percorso/cloude-skill/skills/<nome-skill> ~/.claude/skills/<nome-skill>
```

## Regole per scrivere una skill

- `name`: minuscolo, kebab-case, coerente con il nome della cartella.
- `description`: è il **solo** testo che Claude legge per decidere se attivare la skill.
  Deve dire *cosa fa* e *quando usarla*, con i termini che l'utente userebbe davvero.
- Il corpo di `SKILL.md` va tenuto sotto le ~500 righe: quello che serve raramente
  finisce in `references/` e viene letto solo al bisogno.
- Istruzioni imperative e concrete, non descrizioni generiche.

## Indice skill

| Skill | Descrizione | Stato |
|---|---|---|
| _(nessuna ancora)_ | | |
