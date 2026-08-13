# Origine

- **Origine**: https://github.com/unclecode/crawl4ai
- **Licenza**: Apache 2.0 (vedi `LICENSE`). L'upstream richiede l'attribuzione: "This product includes software developed by UncleCode (https://x.com/unclecode) as part of the Crawl4AI project (https://github.com/unclecode/crawl4ai)."
- **Versione/commit**: skill package v0.7.4 da `docs/md_v2/assets/crawl4ai-skill.zip` sul commit `7e801521428ee12509994d39151006f64055ebe3` (main, 2026-07-15, repo a v0.9.2)
- **Payload copiato**: contenuto dello zip ufficiale (`SKILL.md`, `references/complete-sdk-reference.md`, `scripts/`, `tests/`)
- **Modifiche locali**: aggiunti solo `SOURCE.md` e `LICENSE` del repo upstream. Nessun altro file della skill è stato modificato.

Non è stato vendored il monorepo Python (libreria, Docker, MCP server). Per Claude Code e Cursor Agent basta questo payload: `install.sh` lo collega in `~/.claude/skills/crawl4ai` e `~/.cursor/skills/crawl4ai`. Per eseguire i crawl serve `pip install crawl4ai` + `crawl4ai-setup` nell'ambiente del progetto.
