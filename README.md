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

To use the 4D Embedding Studio interface, you need to create at least one object attribute associated to a `4D.Vector` class in your datastore. This must be done at the database level (only storage attributes can be embeddings).

In the Structure editor, add an Object field (e.g. "myVector") to the dataclass (table) whose entities you want to query using AI and enter ["4D.Vector" as class](https://developer.4d.com/docs/Develop/field-properties#class). 

#### Dirty-flag support

In a production application, data is rarely static. If an embedding is based on an attribute value that has changed (e.g. a product description), it becomes obsolete and could no longer be relevant. In this case, 4D automatically invalidates and flags for recalculation affected embeddings.

By default, if you do not use a dirty-flag field, 4D simply replaces any invalidated vector by `Null`. It is therefore no longer used in searches until its next calculation. This option is suitable for applications that prioritize strict consistency: it is better to return no results than to rely on an embedding that no longer matches the current data.

Or, you can add a Boolean field named `<vectorName>_dirty` (e.g. "myVector_dirty") to the structure. In this case, when an update is required, this field is set to `True`, and the associated vector is retained until it is recalculated. Your application can then choose to continue using this vector temporarily or exclude it using a filter on `dirty = False`. The flag is cleared automatically after a successful save.
This strategy promotes service continuity while allowing you to precisely identify vectors awaiting recalculation. If your business logic requires full control, you can also disable automatic invalidation and manage this lifecycle yourself.

*Note: Certain modifications, such as a model changes, require vectors to be replaced immediately.* 


### Creating an embedding

When you select **Embedding Studio...** in the **Design** menu, the Embedding Studio window is displayed. 

The list on the left side shows all `4D.Vector` class attributes defined in the datastore. You can add as many vector attributes as you want per dataclass. 

**Note:** Any change in the database structure will require that you restart the 4D application so that the 4D Embedding Studio lists up-to-date values.

To create or edit an embedding, select the attribute to configure in this list and write the embedding definition in the "Descriptive sentence" area on the right side. Use the associated menu to build the sentence and to add references to dataclass available attributes with the `{attribute_name}` syntax. 


#### How to write the descriptive sentence?

The sentence must build a text that describes the entity just like a human would do it. The embedding could then capturate the semantics and not only attribute values. 

For example, for a `Product` dataclass with many attributes such as name and category, you could write: 
"The {name} product is a {category} from the {brand} brand. Description: {description}. Key features: {features}."


### Selecting a model

Once you have defined your vector attribute, choose the model to use for generating the embedding. The list of models includes the **model aliases** you defined in the [Project Settings](https://developer.4d.com/docs/settings/ai#model-aliases). 

The choice of model is important because it determines the relevance and quality of your embeddings. You’ll also need to provide this model with every query on the dataclass data so that the comparison is performed using the same model. 


### Calculating embeddings

Embedding attributes must be calculated by sending requests to the AI model. New embeddings must be calculated while obsolete embeddings must be recalculated. This can be done automatically by the 4D Embedding Studio, according to your dirty-flag configuration. 

Warninf



### Building queries with vectors




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
