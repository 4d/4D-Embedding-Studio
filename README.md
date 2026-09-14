# 4D-Embedding-Studio

## Overview

4D Embedding Studio is a component for defining, processing, and maintaining AI embedding vectors directly in your 4D dataclass entities. Configure which fields to embed and with which model. 

Select attributes from your dataclasses to construct the sentences to be vectorized and specify the model to use. For each entity, the component calls the embedding API and stores the resulting `4D.Vector` values.

Configure the embedding scheduler to (re)calculate the vectors for your data at fixed intervals or on demand. Then use the ORDA [`query()` by vector feature](https://developer.4d.com/docs/API/DataClassClass#query-by-vector-similarity) to build a high-performance RAG (Retrieval Augmented Generation) into your 4D application.

The component offers an extensive API that allows you to control the scheduler, customize each step of the data vectorization process, and integrate .

## Requirements

- [4D-AIKit](https://github.com/4d/4D-AIKit) (loaded automatically as a dependency). 
- 4D project (>21 R3) with the following configuration:
  - at least a valid model alias 
  - at least a dataclass with a `4D.Vector` attribute (object field at the database level).


## Quick Start

When the 4D Embedding Studio is correctly installed in your 4D project, an . 

**1. Select **Embedding Studio...** in the **Design** menu to display the Embedding Studio window.
**2. For each `4D.Vector` attribute, write a descriptive phrase and select a model. 
Optionnally, you can check the Invalidate check box. 

**2. Configure your vectors** in your dataclass
**3. Configure your vectors** in your dataclass
**4. Configure your vectors** in your dataclass
**5. Configure your vectors** in your dataclass



### Dirty-flag support

Declare a Boolean field named `<vectorName>_dirty` on your dataclass. When the flag is `True`, the pipeline recomputes the vector even if one already exists. The flag is cleared automatically after a successful save.


## Using the API

### Quick start

**1. Configure your vectors** in `Settings/embeddings.json` (or via the built-in UI):

```json
{
  "batchSize": 50,
  "definitions": [
    {
      "dataclassName": "Students",
      "vectorName": "student_vector_1",
      "modelAlias": "text-embedding",
      "phrase": "Student {firstName} {lastName}, enrolled in {program}",
      "autoInvalidate": true
    }
  ]
}
```

**2. Run the full pipeline** (all definitions, all records):

```4d
var $p:=cs.EmbeddingStudio.Process.new()
var $r:=$p.process()

If ($r.success)
    ALERT("Updated "+String($r.entitiesUpdated)+" entities in "+String($r.duration)+" ms")
End if
```

**3. Process a single entity on save** (e.g. in a trigger or REST hook):

```4d
var $p:=cs.EmbeddingStudio.Process.new()
$p.processEntity($entity)
```



### Class reference

| Class | Description |
|---|---|
| [Process](Documentation/Classes/Process.md) | Main orchestrator — entry point for all batch and entity operations. |
| [Scheduler](Documentation/Classes/Scheduler.md) | Automated recalculation scheduler — background task, force/cancel, and runtime status. |
| [Playground](Documentation/Classes/Playground.md) | Ad-hoc, non-persisting helpers for rendering phrases and computing one-off vectors. |
| [Settings](Documentation/Classes/Settings.md) | Loads and saves the `embeddings.json` configuration file. |
| [Definition](Documentation/Classes/Definition.md) | Describes one vector field: dataclass, field name, model alias, and phrase template. |
| [Embedder](Documentation/Classes/Embedder.md) | Thin wrapper around the AIKit embeddings API with retry/backoff logic. |
| [EmbedderResult](Documentation/Classes/EmbedderResult.md) | Typed wrapper normalizing API responses — vectors, usage metrics, rate-limit state. |
| [ProcessResult](Documentation/Classes/ProcessResult.md) | Returned by every batch function — statistics and error breakdown. |
| [ProcessError](Documentation/Classes/ProcessError.md) | Typed entry in `ProcessResult.errors` — scope, severity, code, ref, message, retryable. |
| [ProcessErrorCode](Documentation/Classes/ProcessErrorCode.md) | Singleton catalogue of machine-readable error codes and their default severity/retryability. |
| [Phrase](Documentation/Classes/Phrase.md) | Lightweight `{variable}` template engine used to build text from entity attributes. |
