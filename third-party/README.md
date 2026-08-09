# Skill di terzi

Skill non scritte da noi, tenute qui separate da `skills/` per non confondere ciò che
possiamo modificare liberamente con ciò che arriva da fuori e va riallineato all'upstream.

Struttura di ogni skill importata:

```
third-party/<nome-skill>/
  SKILL.md
  SOURCE.md      # obbligatorio
  ...            # il resto dei file, come da upstream
```

`SOURCE.md` deve contenere:

- **Origine**: URL del repo/pagina da cui arriva
- **Licenza**: quella dell'upstream (se assente, annotarlo esplicitamente)
- **Versione/commit**: commit hash o data di import, per sapere da dove ripartire
- **Modifiche locali**: elenco puntuale di cosa è stato cambiato rispetto all'originale,
  oppure "nessuna"

Se una skill di terzi va modificata in modo sostanziale, conviene forkarla in `skills/`
con un nome nostro e annotare la provenienza — così l'upstream resta aggiornabile.

`install.sh` raccoglie le skill sia da `skills/` sia da qui.
