# Configuration file reference

Two JSON files drive 4D Embedding Studio. Both live under a `Settings/` folder and
may be edited by hand. `analyze.py` reports the exact resolved path of each.

Machine-readable JSON Schemas (draft 2020-12) live in
[schemas/](schemas/) — [`embeddings.schema.json`](schemas/embeddings.schema.json) and
[`aiproviders.schema.json`](schemas/aiproviders.schema.json). Validate with
`scripts/validate.py` (see the skill's Step 4), or reference one from a config file via a
`"$schema"` key so an editor validates as you type, e.g.:

```jsonc
{ "$schema": "./../skills/configure-embeddings/references/schemas/embeddings.schema.json", "definitions": [] }
```

(The path is relative to the config file; adjust or use the raw GitHub URL. 4D ignores the
`$schema` key — `_Settings.set` preserves unknown top-level keys.)

---

## 1. `Settings/embeddings.json` — vector definitions

Resolution order (see `_Settings._defaultFile`):
1. `EMBEDDINGS_SETTINGS_PATH` environment variable (full path), else
2. `<database folder>/Settings/embeddings.json`.

> The README calls this `vectors.json`; the code default is **`embeddings.json`**. Trust the path printed by `analyze.py`.

```jsonc
{
  "batchSize": 50,                        // optional, default 50, >0
  "phrase": {                             // optional; ALL default false
    "allowRelations": false,              // enable {relation.field} placeholders (N:1 / 1:1)
    "allowCalculated": false,             // enable computed attributes in phrases
    "allowAlias": false,                  // enable alias attributes in phrases
    "allowObject": false                  // allow Object fields as phrase inputs
  },
  "embedder": { "maxRetries": 3, "backoffMs": 500 },   // optional, advanced
  "definitions": [
    {
      "dataclassName": "_Students",       // EXACT ORDA/table name (may start with "_")
      "vectorName": "student_vector_1",   // must be a real 4D.Vector field on that dataclass
      "modelAlias": "embed",              // a model alias from AIProviders.json "models"
      "phrase": "Student {firstName} {lastName}",   // {attribute} template
      "autoInvalidate": true              // recompute when definition/model changes
    }
  ],
  "scheduler": { "mode": "daily", "dailyTime": "02:00" }   // see section 3
}
```

### Definition rules (enforced by `Definition.validate`)
- `dataclassName` must exist in the catalog (an ORDA dataclass). Use the **table name verbatim**, including any leading `_`.
- `vectorName` must be a field whose class is `4D.Vector`.
- `modelAlias` must match an alias in `AIProviders.json` → `models`.
- `phrase` must be non-empty and reference only **allowed** attributes:
  - simple scalar fields — always allowed;
  - related fields `{relation.field}` — only if `phrase.allowRelations`;
  - computed attributes — only if `phrase.allowCalculated`;
  - alias attributes — only if `phrase.allowAlias`;
  - object fields — only if `phrase.allowObject`.
  - Never usable: the vector field itself, blob, image, and the internal `<vectorName>_dirty` flags.

### Dirty-flag optimisation (optional)
If the dataclass has a Boolean field named `<vectorName>_dirty`, the pipeline uses it to
recompute only flagged rows. It is a control field — never put it in a phrase.

### Writing this file safely
When editing offline, **read-modify-write**: load the existing JSON, change only
`definitions` / `phrase` / `scheduler` as needed, and preserve every other top-level key.
The 4D UI stores keys here too (e.g. `scheduler`); clobbering the file loses them.

---

## 2. `Settings/AIProviders.json` — providers & model aliases (from 4D-AIKit)

Resolution order (see AIKit `_AIProvidersObject`):
1. `<data folder>/Settings/AIProviders.json`, else
2. `<database folder>/Settings/AIProviders.json`, else
3. `<project>/Sources/AIProviders.json`.

```jsonc
{
  "providers": {
    "openai": {
      "baseURL": "https://api.openai.com/v1",
      "apiKey": "sk-..."                  // OR leave empty and set OPENAI_API_KEY env var
    },
    "ollama": {
      "baseURL": "http://localhost:11434/v1/"   // local; no apiKey needed
    }
  },
  "models": {                             // <-- these are the "model aliases"
    "embed":  { "provider": "openai", "model": "text-embedding-3-small" },
    "chat":   { "provider": "openai", "model": "gpt-4o" }
  }
}
```

- A **model alias** is a key under `models` → `{ provider, model }`. `modelAlias` in
  `embeddings.json` refers to this key (here, `"embed"`).
- If `apiKey` is omitted, AIKit falls back to the env var `<PROVIDER>_API_KEY`
  (e.g. `OPENAI_API_KEY`). **Prefer the env var — do not write secret keys into the file.**

### Common embedding models
| Provider | baseURL | embedding model examples |
|---|---|---|
| openai | `https://api.openai.com/v1` | `text-embedding-3-small`, `text-embedding-3-large`, `text-embedding-ada-002` |
| ollama (local) | `http://localhost:11434/v1/` | `nomic-embed-text`, `mxbai-embed-large`, `all-minilm` |
| mistral | `https://api.mistral.ai/v1` | `mistral-embed` |

A usable embedding alias is one whose `model` (or alias name) contains `embed`
and points at an embeddings-capable model — **not** a chat model.

---

## 3. Scheduler config (the `scheduler` key of `embeddings.json`)

From `Scheduler` / `_normalize`:

```jsonc
"scheduler": {
  "mode": "disabled" | "interval" | "daily",   // default "disabled"
  "intervalHours": 3,                  // interval mode only, 1..24 (default 3)
  "startFrom": "reference" | "lastExecution",   // interval mode only
  "startReference": "2026-08-21T02:00:00",      // interval anchor (ISO, no zone)
  "dailyTime": "02:00"                 // daily mode only, "HH:MM" 00:00..23:59
}
```

For **daily** scheduling you only need `{ "mode": "daily", "dailyTime": "HH:MM" }`.

### Arming the scheduler at runtime
The config alone does not run anything. The background loop is armed by
`cs.EmbeddingStudio.Scheduler.me.start()`. Two ways to get it called:
- **autoStart**: enable *Settings → Security → "Execute On Host Database Event method
  of the components"* in the host database. The scheduler then arms/disarms with the host.
- **manual**: call `cs.EmbeddingStudio.Scheduler.me.start()` from the host
  `On Server Startup` (or `On Startup`) method.

Check state with `cs.EmbeddingStudio.Scheduler.me.status()` →
`{ enabled, mode, armed, running, nextRun, lastExecution, started, autoStart, ... }`.
