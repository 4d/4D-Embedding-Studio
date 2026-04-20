# 4D-Embedding-Studio

A 4D component for defining, computing, and maintaining AI embedding vectors directly on your 4D dataclass entities. Configure which fields to embed and with which model; the pipeline renders text phrases, calls the embeddings API, and persists the resulting `4D.Vector` values on your records.

## Requirements

- [4D-AIKit](https://github.com/4d/4D-AIKit) (loaded automatically as a dependency) with model aliases. (>21R3)

## Quick start

**1. Configure your vectors** in `Settings/vectors.json` (or via the built-in UI):

```json
{
  "batchSize": 50,
  "vectors": [
    {
      "dataclassName": "Students",
      "vectorName": "student_vector_1",
      "model": "text-embedding",
      "phrase": "Student {firstName} {lastName}, enrolled in {program}",
      "version": 0
    }
  ]
}
```

**2. Run the full pipeline** (all definitions, all records):

```4d
var $p:=cs.EmbeddingProcess.new()
var $r:=$p.process()

If ($r.success)
    ALERT("Updated "+String($r.entitiesUpdated)+" entities in "+String($r.durationMs)+" ms")
End if
```

**3. Process a single entity on save** (e.g. in a trigger or REST hook):

```4d
var $p:=cs.EmbeddingProcess.new()
$p.processEntity($entity)
```

## Dirty-flag support

Declare a Boolean field named `<vectorName>_dirty` on your dataclass. When the flag is `True`, the pipeline recomputes the vector even if one already exists. The flag is cleared automatically after a successful save.

## Class reference

| Class | Description |
|---|---|
| [EmbeddingProcess](Documentation/Classes/EmbeddingProcess.md) | Main orchestrator — entry point for all batch and entity operations. |
| [EmbeddingSettings](Documentation/Classes/EmbeddingSettings.md) | Loads and saves the `vectors.json` configuration file. |
| [EmbeddingDefinition](Documentation/Classes/EmbeddingDefinition.md) | Describes one vector field: dataclass, field name, model, and phrase template. |
| [EmbeddingProcessor](Documentation/Classes/EmbeddingProcessor.md) | Thin wrapper around the AIKit embeddings API with retry/backoff logic. |
| [EmbeddingProcessResult](Documentation/Classes/EmbeddingProcessResult.md) | Returned by every batch function — statistics and error breakdown. |
| [Phrase](Documentation/Classes/Phrase.md) | Lightweight `{variable}` template engine used to build text from entity attributes. |
