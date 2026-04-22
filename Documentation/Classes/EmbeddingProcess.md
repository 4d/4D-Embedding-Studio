# EmbeddingProcess

The `EmbeddingProcess` class orchestrates the full embedding pipeline: it browses 4D entities, renders text from their fields using an [EmbeddingDefinition](EmbeddingDefinition.md), calls the embeddings API through an [EmbeddingProcessor](EmbeddingProcessor.md), and stores the resulting `4D.Vector` on each entity.

It also exposes non-persisting helpers for previewing rendered phrases and computing one-off vectors (for similarity search queries, debugging, or experimentation).

## Properties

| Property Name | Type                                                    | Description                                              |
|---------------|---------------------------------------------------------|----------------------------------------------------------|
| `settings`    | [EmbeddingSettings](EmbeddingSettings.md)               | The settings (vectors, batch size, phrase validation options). |
| `processor`   | [EmbeddingProcessor](EmbeddingProcessor.md)             | The API-calling engine. Stateless and swappable.         |
| `options`     | Object                                                  | Runtime options: `onProgress`, `dryRun`, `force`, `processor`. |

### Options object

| Key          | Type      | Description                                                                 |
|--------------|-----------|-----------------------------------------------------------------------------|
| `onProgress` | 4D.Function | Called after each chunk with `{definition, report}`.                       |
| `dryRun`     | Boolean   | If `True`, runs the whole pipeline without calling the API or saving.       |
| `force`      | Boolean   | If `True`, recomputes every entity ignoring null-vector / dirty-flag filter. |
| `processor`  | [EmbeddingProcessor](EmbeddingProcessor.md) | Inject a custom processor (otherwise a default one is created). |

## Class constructor

Create an instance of the orchestrator.

| Argument Name | Type                                      | Description                                                         |
|---------------|-------------------------------------------|---------------------------------------------------------------------|
| *settings*    | [EmbeddingSettings](EmbeddingSettings.md) | Optional. If omitted, settings are loaded from the default `Settings/vectors.json`. |
| *options*     | Object                                    | Optional runtime options (see table above).                         |

```4d
// Simplest — uses defaults
var $p:=cs.EmbeddingProcess.new()

// With explicit settings
var $p:=cs.EmbeddingProcess.new($settings)

// With options
var $p:=cs.EmbeddingProcess.new($settings; {\
	force: True; \
	onProgress: Formula(ALERT("chunk done: "+String($1.report.entitiesUpdated)))})
```

## Batch processing functions

### process()

**process**(*definition* : Variant) : [EmbeddingProcessResult](EmbeddingProcessResult.md)

Process one, many, or all [EmbeddingDefinition](EmbeddingDefinition.md) entries against the full content of their target dataclass.

| Argument        | Type                                                                        | Description                                                                 |
|-----------------|-----------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| *definition*    | `Null`, [EmbeddingDefinition](EmbeddingDefinition.md), or Collection        | `Null` → process every definition in settings. Otherwise process the given one(s). |
| Function result | [EmbeddingProcessResult](EmbeddingProcessResult.md)                         | Statistics and per-error breakdown.                                         |

```4d
// Every definition in settings
var $r:=$p.process()

// One specific definition
var $r:=$p.process($def)

// Multiple definitions
var $r:=$p.process([$def1; $def2])
```

### processEntity()

**processEntity**(*entity* : 4D.Entity ; *definition* : Variant) : [EmbeddingProcessResult](EmbeddingProcessResult.md)

Process a single entity. Cheap path — no chunking, no server-side filter.

| Argument        | Type                                                                                      | Description                                                                 |
|-----------------|-------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| *entity*        | 4D.Entity                                                                                 | The entity to (re)compute vectors for.                                      |
| *definition*    | `Null`, [EmbeddingDefinition](EmbeddingDefinition.md), Collection, or `{vectorName: ...}` | See [resolution rules](#definition-resolution). `Null` infers from entity's dataclass. |
| Function result | [EmbeddingProcessResult](EmbeddingProcessResult.md)                                       | Statistics and per-error breakdown.                                         |

```4d
// Auto-resolve every definition matching this entity's dataclass
var $r:=$p.processEntity($entity)

// Specific definition
var $r:=$p.processEntity($entity; $def)

// By vector name only (looked up in settings against the entity's dataclass)
var $r:=$p.processEntity($entity; {vectorName: "student_vector_1"})
```

### processEntitySelection()

**processEntitySelection**(*selection* : 4D.EntitySelection ; *definition* : Variant) : [EmbeddingProcessResult](EmbeddingProcessResult.md)

Workhorse path for large jobs. Chunks the selection by `settings.batchSize`, sends one API call per chunk, saves each entity individually.

| Argument        | Type                                                                                      | Description                                                                 |
|-----------------|-------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| *selection*     | 4D.EntitySelection                                                                        | Entities to process. Pre-filtering by the caller is allowed; the pipeline still applies its null/dirty filter. |
| *definition*    | `Null`, [EmbeddingDefinition](EmbeddingDefinition.md), Collection, or `{vectorName: ...}` | See [resolution rules](#definition-resolution).                             |
| Function result | [EmbeddingProcessResult](EmbeddingProcessResult.md)                                       | Statistics and per-error breakdown.                                         |

```4d
var $todo:=ds.Students.query("country = :1"; "FR")
var $r:=$p.processEntitySelection($todo; $def)
```

### Definition resolution

The polymorphic *definition* argument accepted by `processEntity` and `processEntitySelection`:

| Input                                                      | Behavior                                                                 |
|------------------------------------------------------------|--------------------------------------------------------------------------|
| `Null`                                                     | All definitions in settings whose `dataclassName` matches the entity/selection. |
| [EmbeddingDefinition](EmbeddingDefinition.md)              | Used as-is; the `dataclassName` must match the entity/selection.         |
| `{vectorName: "..."}`                                      | Looked up in settings by `vectorName` against the entity/selection dataclass. |
| Collection                                                 | Each item resolved using the rules above; mismatches are silently dropped. |

`process()` ignores the entity-context rules (it has no entity) — a `Null` argument means *all definitions in settings*.

### Recompute rules

An entity is (re)computed when **any** of these are true:

- The target vector field is `Null`.
- A sibling field named `{vectorName}_dirty` exists and is `True`.
- The `force` option is `True`.

The dirty field is optional per dataclass. If it doesn't exist, only the null-vector case triggers recomputation. Upon successful save, the pipeline clears the dirty flag (when present).

For `processEntitySelection`, the filter is executed as a server-side ORDA query before any API call, so only the rows that actually need work are loaded into memory. For `processEntity`, the check is done in memory on the already-fetched entity.

## Playground functions (non-persisting)

These helpers are for ad-hoc usage: previews, similarity search inputs, REPL experimentation. They never save anything on the entity.

### render()

**render**(*entity* : 4D.Entity ; *definitionOrPhrase* : Variant) : Text

Render a phrase for an entity and return the resulting text. No API call, no persistence.

| Argument              | Type                                                                        | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| *entity*              | 4D.Entity                                                                   | The entity to render against.                                               |
| *definitionOrPhrase*  | `Null`, [Phrase](Phrase.md), [EmbeddingDefinition](EmbeddingDefinition.md), or Text | `Null` → auto-resolve via settings (requires a unique match). Text → compiled as a throwaway `cs.Phrase`. |
| Function result       | Text                                                                        | The rendered text.                                                          |

```4d
var $text: Text
$text:=$p.render($student; $def)                        // use def's phrase
$text:=$p.render($student; cs.Phrase.new("Hi {firstName}"))
$text:=$p.render($student; "Student: {lastName}")       // raw template
$text:=$p.render($student)                              // auto-resolve
```

### embed()

**embed**(*input* : Variant ; *context* : Variant ; *model* : Text) : 4D.Vector

Compute a vector for an arbitrary input, without persisting anywhere.

| Argument        | Type                                                                                     | Description                                                                 |
|-----------------|------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| *input*         | Text or 4D.Entity                                                                        | Text → embedded directly. Entity → phrase rendered then embedded.          |
| *context*       | Text, [Phrase](Phrase.md), [EmbeddingDefinition](EmbeddingDefinition.md), Text template, or `Null` | Provides phrase and/or model depending on *input*.                          |
| *model*         | Text                                                                                     | Optional explicit model name. Used when *context* does not carry one.      |
| Function result | 4D.Vector                                                                                | The embedding vector.                                                       |

Throws if no model can be determined.

```4d
var $vector: 4D.Vector
// Text + model
$vector:=$p.embed("some text"; "text-embedding-3-small")

// Text + definition (picks up def.model)
$vector:=$p.embed("some text"; $def)

// Entity + definition (uses def.phrase + def.model)
$vector:=$p.embed($student; $def)

// Entity + phrase + explicit model
$vector:=$p.embed($student; $phrase; "text-embedding-3-small")

// Entity + ad-hoc template + model
$vector:=$p.embed($student; "Profile: {firstName} {lastName}"; "text-embedding-3-small")

// Entity alone (auto-resolve, only when exactly one def matches the dataclass)
$vector:=$p.embed($student)
```

## See also

- [EmbeddingSettings](EmbeddingSettings.md)
- [EmbeddingDefinition](EmbeddingDefinition.md)
- [EmbeddingProcessor](EmbeddingProcessor.md)
- [EmbeddingProcessResult](EmbeddingProcessResult.md)
- [Phrase](Phrase.md)
