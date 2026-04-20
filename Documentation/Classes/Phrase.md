# Phrase

The `Phrase` class is a lightweight template engine: a template with `{variable}` placeholders is compiled once, then rendered efficiently against different data objects.

Dot-notation is supported for nested fields and related attributes: `{relation.field}` or `{a.b.c}`.

## Properties

| Property Name | Type | Description                                                                 |
|---------------|------|-----------------------------------------------------------------------------|
| `template`    | Text | Computed — returns the original template string.                            |
| `keys`        | Collection | Computed — returns the variable names found in the template, dot-notation keys joined back to strings. |

## Class constructor

Compile a template. Compilation walks the template once and extracts static parts and variable paths.

| Argument Name | Type | Description                                 |
|---------------|------|---------------------------------------------|
| *template*    | Text | Template string with `{variable}` markers.  |

```4d
var $tpl:=cs.Phrase.new("Hello {firstName}, you study at {school.name}.")
$tpl.keys // → ["firstName"; "school.name"]
```

## Functions

### render()

**render**(*data* : Object) : Text

Render the compiled template by replacing variables with values from *data*. Missing keys produce an empty string.

| Argument        | Type   | Description                                                                 |
|-----------------|--------|-----------------------------------------------------------------------------|
| *data*          | Object | A plain object or a 4D.Entity whose fields supply the variable values.      |
| Function result | Text   | The rendered text.                                                          |

```4d
$tpl.render({firstName: "Alice"; school: {name: "MIT"}})
// → "Hello Alice, you study at MIT."

// Works directly on entities
$tpl.render(ds.Students.first())
```

### validate()

**validate**(*dataclass* : 4D.DataClass ; *options* : Object) : Object

Validate that all keys in the phrase can be resolved against the given dataclass. Walks dot-notation paths through N:1 / 1:1 relations.

| Argument        | Type          | Description                                                                     |
|-----------------|---------------|---------------------------------------------------------------------------------|
| *dataclass*     | 4D.DataClass  | The dataclass to validate against.                                              |
| *options*       | Object        | Optional validation flags (see below). All default to `False` — storage kind only. |
| Function result | Object        | `{success: Boolean, errors: Collection of {key, message}}`.                     |

#### Options

| Field              | Type    | Default | Description                                                |
|--------------------|---------|---------|------------------------------------------------------------|
| `allowRelations`   | Boolean | `False` | Allow dot-notation paths through N:1 / 1:1 relations.      |
| `allowCalculated`  | Boolean | `False` | Allow calculated attributes.                               |
| `allowAlias`       | Boolean | `False` | Allow alias attributes.                                    |

```4d
var $tpl:=cs.Phrase.new("{firstName} at {school.name}")

// Storage-only validation — fails because {school.name} uses a relation
var $v:=$tpl.validate(ds.Students)
// $v.success → False
// $v.errors → [{key: "school.name"; message: "..."}]

// Allow relations
$v:=$tpl.validate(ds.Students; {allowRelations: True})
// $v.success → True
```

#### Rejected shapes

Regardless of options:

- Attributes that do not exist on the dataclass.
- Attributes whose class ID is `4D.Vector`.
- 1:N relations (`relatedEntities`) as the final key.
- Intermediate segments that are not relations (when dot-notation is used).

## See also

- [EmbeddingDefinition](EmbeddingDefinition.md) — holds a `Phrase`.
- [EmbeddingProcess.render()](EmbeddingProcess.md#render) — renders a phrase for an entity via the orchestrator.
