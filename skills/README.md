# skills/

Agent skills for working with this project. Each subfolder is a self-contained skill
(a `SKILL.md` plus any helper scripts/references) that an LLM coding agent can invoke.

| Skill | Purpose |
|---|---|
| [configure-embeddings](configure-embeddings/SKILL.md) | Populate/configure `Settings/embeddings.json` without the graphical UI: read the catalog for `4D.Vector` fields, propose phrase templates from field names, ensure an AIKit embedding model alias + provider exist, and optionally enable daily scheduling. |

## Install

Install a skill into your agent (`.claude/skills/`, `.agents/skills/`, …) with the
[`skills`](https://github.com/vercel-labs/skills) CLI — its install subcommand is `add`:

```bash
npx skills add 4d/4D-Embedding-Studio --skill configure-embeddings
```
