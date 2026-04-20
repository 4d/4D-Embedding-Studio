# EmbeddingSettings

The `EmbeddingSettings` class is the persisted configuration for the embedding pipeline. It loads and saves a JSON file (default: `Settings/vectors.json`) containing a list of [EmbeddingDefinition](EmbeddingDefinition.md) entries, a batch size, and phrase-validation options.

Unknown top-level keys found in the JSON (e.g. `"models"`) are preserved on load and re-emitted on save.

## Properties

| Property Name | Type                                                     | Description                                                                 |
|---------------|----------------------------------------------------------|-----------------------------------------------------------------------------|
| `file`        | 4D.File                                                  | The backing JSON file.                                                      |
| `vectors`     | Collection of [EmbeddingDefinition](EmbeddingDefinition.md) | The configured definitions.                                                 |
| `batchSize`   | Integer                                                  | Chunk size used by [EmbeddingProcess.processEntitySelection](EmbeddingProcess.md#processentityselection). Default: `50`. |
| `phrase`      | Object                                                   | Phrase-validation options (see below).                                      |

### phrase options

Passed verbatim to [Phrase.validate()](Phrase.md#validate) whenever the pipeline validates a definition.

| Field              | Type    | Default | Description                                             |
|--------------------|---------|---------|---------------------------------------------------------|
| `allowRelations`   | Boolean | `False` | Allow dot-notation through N:1 / 1:1 relations.         |
| `allowCalculated`  | Boolean | `False` | Allow calculated attributes in phrases.                 |
| `allowAlias`       | Boolean | `False` | Allow alias attributes in phrases.                      |

## File format

```json
{
  "batchSize": 50,
  "phrase": {
    "allowRelations": false,
    "allowCalculated": false,
    "allowAlias": false
  },
  "vectors": [
    {
      "dataclassName": "Students",
      "vectorName": "student_vector_1",
      "model": "text-embedding-3-small",
      "phrase": "Student {firstName} {lastName}",
      "version": 0
    }
  ]
}
```

## Class constructor

Create a settings instance. The backing file is loaded immediately.

| Argument Name | Type    | Description                                                                  |
|---------------|---------|------------------------------------------------------------------------------|
| *file*        | 4D.File | Optional. Defaults to `<project>/Settings/vectors.json`.                    |

```4d
// Default location
var $settings:=cs.EmbeddingSettings.new()

// Custom file
var $settings:=cs.EmbeddingSettings.new(File("/some/path/custom.json"))
```

## Functions

### load()

**load**()

Reload the backing file into memory, overwriting in-memory state. Missing or malformed files reset to defaults without raising.

### save()

**save**()

Serialize the current in-memory state to the backing file. Preserves unknown top-level keys that were present on load.

```4d
$settings.vectors.push(cs.EmbeddingDefinition.new("Students"; "student_vector_1"; "text-embedding-3-small"; "{firstName}"))
$settings.batchSize:=100
$settings.save()
```

### find()

**find**(*dataclassName* : Text ; *vectorName* : Text) : [EmbeddingDefinition](EmbeddingDefinition.md)

Look up the saved definition for the given dataclass/vector pair.

| Argument        | Type                                          | Description                                         |
|-----------------|-----------------------------------------------|-----------------------------------------------------|
| *dataclassName* | Text                                          | Name of the dataclass.                              |
| *vectorName*    | Text                                          | Name of the vector field on that dataclass.         |
| Function result | [EmbeddingDefinition](EmbeddingDefinition.md) | The matching definition, or `Null` if none matches. |

```4d
var $def:=$settings.find("Students"; "student_vector_1")
```

## See also

- [EmbeddingDefinition](EmbeddingDefinition.md)
- [EmbeddingProcess](EmbeddingProcess.md)
- [Phrase](Phrase.md)
