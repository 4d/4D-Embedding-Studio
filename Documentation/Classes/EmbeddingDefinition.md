# EmbeddingDefinition

The `EmbeddingDefinition` class describes how a single vector field on a dataclass should be computed: which dataclass, which vector field, which model, and which text template ([Phrase](Phrase.md)) to render from each entity.

A collection of these is what [EmbeddingSettings](EmbeddingSettings.md) persists.

## Properties

| Property Name   | Type              | Description                                                                 |
|-----------------|-------------------|-----------------------------------------------------------------------------|
| `version`       | Integer           | Monotonic version. `-1` means the definition has never been computed. Bumped by the UI whenever the phrase or model changes. Default: `-1`. |
| `dataclassName` | Text              | Name of the target dataclass.                                               |
| `vectorName`    | Text              | Name of the `4D.Vector` field on that dataclass.                            |
| `model`         | Text              | Embedding model identifier (e.g. `"text-embedding-3-small"`).              |
| `phrase`        | [Phrase](Phrase.md) | Compiled template used to build the text that will be embedded.           |

## Class constructor

Create a definition.

| Argument Name     | Type | Description                                                                 |
|-------------------|------|-----------------------------------------------------------------------------|
| *dataclassName*   | Text | Name of the target dataclass.                                               |
| *vectorName*      | Text | Name of the target vector field.                                            |
| *model*           | Text | Embedding model identifier.                                                 |
| *phraseTemplate*  | Text | Phrase template with `{field}` placeholders — compiled into a [Phrase](Phrase.md). |

```4d
var $def:=cs.EmbeddingDefinition.new(\
	"Students"; \
	"student_vector_1"; \
	"text-embedding-3-small"; \
	"Student {firstName} {lastName}")
```

## Functions

### toObject()

**toObject**() : Object

Returns a plain object suitable for JSON persistence. The phrase is flattened to its template text.

| Argument        | Type   | Description                                                                 |
|-----------------|--------|-----------------------------------------------------------------------------|
| Function result | Object | `{version, dataclassName, vectorName, model, phrase}` where `phrase` is the template string. |

```4d
$def.toObject()
// → { version: 0; dataclassName: "Students"; vectorName: "student_vector_1";
//     model: "text-embedding-3-small"; phrase: "Student {firstName} {lastName}" }
```

## Dirty flag convention

The pipeline in [EmbeddingProcess](EmbeddingProcess.md) will recompute an entity whenever the target vector is `Null`, or when a sibling field `<vectorName>_dirty` exists on the dataclass and is `True`.

Declaring the dirty flag is optional — when absent, only the null-vector case triggers recomputation. When present, it is cleared automatically on successful save.

## See also

- [EmbeddingSettings](EmbeddingSettings.md)
- [EmbeddingProcess](EmbeddingProcess.md)
- [Phrase](Phrase.md)
