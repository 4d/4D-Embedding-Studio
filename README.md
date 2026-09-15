# 4D-Embedding-Studio

## Overview

4D Embedding Studio is a component for defining, processing, and maintaining AI embedding vectors directly in your 4D dataclass entities. 

You can use the component without writing a single line of code: select attributes from your dataclasses to construct the sentences to be vectorized and specify the model to use. For each entity, the component calls the embedding API and stores the resulting `4D.Vector` values. Configure the embedding scheduler to (re)calculate the vectors for your data at fixed intervals or on demand. 

You can then use the ORDA [`query()` by vector feature](https://developer.4d.com/docs/API/DataClassClass#query-by-vector-similarity) to request your data using semantics.

If you want to have more control over your embeddings, the component offers an extensive API that allows you to customize each step of the data vectorization process, manage the scheduler, and integrate high-performance RAG (*Retrieval Augmented Generation*) features into your 4D application.


## Requirements

- [4D-AIKit](https://github.com/4d/4D-AIKit) (loaded automatically as a dependency). 
- 4D project (>21 R3) with the following configuration:
  - a valid model alias 
  - a dataclass with a `4D.Vector` attribute (object field at the database level).


## Quick Start

**1. Add a field of type Object to the table and associate it with the `4D.Vector` class.**  
**2. Select **Embedding Studio...** in the **Design** menu to display the Embedding Studio window.**  
**3. For each listed `4D.Vector` attribute, write a descriptive phrase based upon attributes of the dataclass.**  
Use the contextual menu to insert appropriate attributes.  
This phrase will be vectorized for every entity.
**4. Select a model alias (or create a new one).**   
**5. Select "Execute now" to launch the vectorization of your data or configure the scheduler.**   


## User Guide

### Configuring the dataclass

To use the 4D Embedding Studio interface, you need to create at least one object attribute associated to a `4D.Vector` class in your datastore. This must be done at the database level.

In the Structure editor, add a `<vectorName>` Object field to the dataclass (table) whose entities you want to query using AI and [enter "4D.Vector" as class](https://developer.4d.com/docs/Develop/field-properties#class). 


### Dirty-flag support

In a production application, data is rarely static. If an embedding is based on a value that has changed, it becomes obsolete and could no longer be relevant. In this case, 4D automatically invalidates and flags for recalculation affected embeddings.

By default, if you do not use a dirty-flag field, 4D simply replace any invalidated vector by `Null`. It is therefore no longer used in searches until its next calculation. This option is suitable for applications that prioritize strict consistency: it is better to return no results than to rely on an embedding that no longer matches the current data.

You can You can also add a Boolean field named <vector_name>_dirty to the structure. When an update is required, this field is set to true, and the existing vector is retained until it is recalculated. However, certain changes—such as a model change—require the vector to be replaced immediately.

Your application can then choose to continue using this vector temporarily or exclude it using a filter on `dirty = false`.

This strategy promotes service continuity while allowing you to precisely identify vectors awaiting recalculation.

If your business logic requires full control, you can also disable automatic invalidation and manage this lifecycle yourself.


4D Embedding Studio takes a more targeted approach. 

This means you do not have to develop or maintain your own change-detection logic.


When an update is required, this field is set to true, and the existing vector is retained until it is recalculated. However, certain changes—such as a model change—require the vector to be replaced immediately.

Your application can then choose to continue using this vector temporarily or exclude it using a filter on `dirty = false`.

This strategy promotes service continuity while allowing you to precisely identify vectors awaiting recalculation.

If your business logic requires full control, you can also disable automatic invalidation and manage this lifecycle yourself


#### Dirty-flag support



Declare a Boolean field named `<vectorName>_dirty` in the same dataclass (table) as the embedding attribute, so that it is automatically processed as a flag for embedding maintenance. Default is `False`.

When an update is required for the embedding, this field is set to `False`, and the existing vector is retained until it is recalculated. However, certain changes—such as a model change—require the vector to be replaced immediately.

* When the flag is `True` for an entity, the pipeline recomputes the embedding even if one already exists. The flag is cleared automatically after a successful save.


### Creating an embedding



### Using the scheduler

### Building queries with vectors



successful save.


## API Guide

### Quick start

**1. Configure your vectors** in `Settings/embeddings.json`:

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
