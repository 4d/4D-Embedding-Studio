---
name: configure-embeddings
description: >
  Configure 4D Embedding Studio's embeddings.json without the graphical UI. Use when
  the user wants to set up, populate, propose, or edit vector embedding definitions for
  4D dataclass fields — reading the catalog to find 4D.Vector fields, proposing phrase
  templates from field names, ensuring a working AIKit embedding model alias + provider
  exist, and optionally enabling daily scheduling. Triggers: "configure embeddings",
  "set up vectors", "add an embedding definition", "which fields should I embed".
---

# Configure 4D Embedding Studio (no GUI)

Populate and maintain `Settings/embeddings.json` by reading the project catalog and the
AIKit provider config, then proposing sensible vector definitions. This replaces the
built-in wizard (`Design > Embeddings Studio…`) with an LLM-driven flow.

**Golden rules**
- Never write API keys or other secrets into files. Point the user to the
  `<PROVIDER>_API_KEY` env var, or ask *them* to paste the key into `AIProviders.json`.
- Always **confirm proposed definitions with the user before writing** any file.
- When editing `embeddings.json`, **read-modify-write**: preserve every top-level key you
  did not intend to change (`scheduler`, `embedder`, `batchSize`, `phrase`, …).
- Only ever use `dataclassName` = an existing table name (verbatim, keep any leading `_`)
  and `vectorName` = a real `4D.Vector` field. Both come from the catalog, never invented.

Full field/format details are in [references/schema.md](references/schema.md).

---

## Step 0 — Analyze the project

Run the analyzer from the project package folder (the folder containing `Project/`):

```bash
python3 skills/configure-embeddings/scripts/analyze.py
```

Useful flags: `--root <dir>` (project package), `--providers <path>` /
`--embeddings <path>` (override auto-detected paths), `--json` (machine-readable).

Read its `## Gate` line — it tells you the next action. Then follow the matching step
below. The report also lists, per table: vector fields (targets), phrase-usable scalar
fields, N:1 relations, computed/alias attributes, `_dirty` flags, and which vectors are
already configured.

---

## Step 1 — Providers gate (Gate: BLOCKED)

If **no providers** are configured, stop and configure `AIProviders.json` first — nothing
else can work without a provider.

Ask the user which they want, and scaffold it (see schema.md for exact shapes):
- **Ollama (local, free, no key)** — `baseURL: "http://localhost:11434/v1/"`. Best when
  they can run models locally (`ollama pull nomic-embed-text`).
- **OpenAI (hosted, needs a key)** — `baseURL: "https://api.openai.com/v1"`. Do **not**
  write the key; tell them to either paste it into the provider's `apiKey` themselves or
  set the `OPENAI_API_KEY` environment variable.

Create/merge the `providers` object, then re-run Step 0.

## Step 2 — Embedding alias (Gate: ACTION create alias)

Providers exist but **no alias looks like an embedding model** (name/model containing
`embed`). Propose adding one under `models`, choosing an embeddings-capable model for an
existing provider (see the table in schema.md), e.g.:

```jsonc
"embed": { "provider": "openai", "model": "text-embedding-3-small" }
// or, for a local ollama provider:
"embed": { "provider": "ollama", "model": "nomic-embed-text" }
```

Confirm, then merge into `AIProviders.json` → `models`. Re-run Step 0. Warn against
pointing an embedding alias at a **chat** model — the pipeline needs an embeddings model.

## Step 3 — Propose & write definitions (Gate: ACTION propose definitions)

For each **UNCONFIGURED** vector field in the report, craft a definition:

- `dataclassName` = the table name from the report.
- `vectorName` = the vector field name.
- `modelAlias` = the embedding alias from Step 2 (the one whose model contains `embed`).
- `phrase` = a natural-language template built from the table's **phrase fields**, using
  `{fieldName}` placeholders. Improve on the report's naive `suggestedPhrase`:
  - pick the fields that carry meaning (names, titles, descriptions, categories) and skip
    noise (numeric IDs, status flags);
  - write it as readable text, e.g. `"Student {firstName} {lastName}, {program}"`, not a
    bare field dump;
  - to use a **relation** (`{school.name}`), **computed**, **alias**, or **object** field,
    the matching option under the top-level `phrase` key must be enabled
    (`allowRelations` / `allowCalculated` / `allowAlias` / `allowObject`). Propose enabling
    it only when it clearly improves the phrase, and set it in the same write.
- `autoInvalidate` = `true` (recompute when the definition or its model changes).

Present the full proposed set to the user. On approval, **read-modify-write**
`embeddings.json`: load existing JSON (or `{}`), replace/append the relevant entries in
`definitions`, keep all other keys, and write it back (create the `Settings/` folder if
missing). A field with no meaningful phrase source (e.g. a table with only an ID) should
be flagged to the user rather than given an empty phrase.

## Step 4 — Validate

Always validate after writing. There are three complementary layers:

**a) JSON Schema (shape).** Run the bundled validator — it checks both config files
against the JSON Schemas in [references/schemas/](references/schemas/) and cross-checks
that every `modelAlias` resolves to a declared provider:

```bash
python3 skills/configure-embeddings/scripts/validate.py
```

It is dependency-free (built-in validator); `pip install jsonschema` upgrades it to full
compliance automatically. Flags mirror the analyzer: `--root`, `--embeddings`,
`--providers`, or a generic `--schema S.json --instance I.json`. Fix every reported error
before continuing. Consider adding a `"$schema"` key to each config file pointing at the
matching schema so the user's editor validates live.

**b) Catalog semantics.** Re-run `analyze.py` (Step 0): each definition should now show as
configured, and every `{placeholder}` must map to an allowed attribute for the enabled
phrase options (relations/computed/alias/object need the corresponding `phrase` flag).

**c) Live check (optional).** For a runtime check you can call `Definition.validate` /
`Settings` via the **4d-run** skill; the two static layers above catch the common
mistakes offline.

## Step 5 — Offer daily scheduling (Gate: READY)

Once all target vectors are configured and valid, offer to enable automatic daily
recalculation. On approval, merge into `embeddings.json`:

```jsonc
"scheduler": { "mode": "daily", "dailyTime": "02:00" }
```

Ask the user for the preferred time (`HH:MM`, 24h). Then tell them how it actually runs —
config alone does nothing until the scheduler is armed:
- **autoStart**: enable *host Settings → Security → "Execute On Host Database Event method
  of the components"*; the scheduler then arms itself with the host, or
- **manual**: call `cs.EmbeddingStudio.Scheduler.me.start()` from the host startup method.

They can verify with `cs.EmbeddingStudio.Scheduler.me.status()` (shows `enabled`, `armed`,
`nextRun`, `started`, `autoStart`). See schema.md § 3 for interval mode and details.
