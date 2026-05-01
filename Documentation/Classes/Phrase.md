# Phrase

The `Phrase` class is a lightweight template engine: a template with `{variable}` placeholders is compiled once, then rendered efficiently against different data objects.

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
var $tpl:=cs.embed.Phrase.new("Hello {firstName}, you study at {schoolName}.")
$tpl.keys // → ["firstName"; "schoolName"]
```

### Default values

Each placeholder may declare an inline default after a `|`:

```
{field|default text}
```

The default is rendered when the resolved value is `Null`, missing, or an empty string. Otherwise the value is rendered as usual.

```4d
var $tpl:=cs.embed.Phrase.new("Customer {firstName|Anonymous} from {city|unknown city}, registered {signupDate|recently}.")
$tpl.render({firstName: ""; city: Null})
// → "Customer Anonymous from unknown city, registered recently."
```

Notes:

- Only the first `|` is the separator; subsequent `|` characters are part of the default text.
- The default text is taken verbatim — surrounding whitespace is preserved (e.g. `{x| n/a }` renders ` n/a `).
- Whitespace around the field name is still trimmed (`{ name | X}` is the same key as `{name| X}`).
- Numeric `0` and boolean `False` are treated as present values, not as missing.
- Works with dot-notation: `{user.address.city|unknown}`.
- Defaults do not affect `keys` or `validate()` — they are render-only metadata.

## Functions

### render()

**render**(*data* : Object) : Text

Render the compiled template by replacing variables with values from *data*. Missing keys produce an empty string, unless an inline default was provided via `{field|default}` syntax (see [Default values](#default-values)).

| Argument        | Type   | Description                                                                 |
|-----------------|--------|-----------------------------------------------------------------------------|
| *data*          | Object | A plain object or a 4D.Entity whose fields supply the variable values.      |
| Function result | Text   | The rendered text.                                                          |

```4d
var $text:=$tpl.render({firstName: "Alice"; school: {name: "MIT"}})
// → "Hello Alice, you study at MIT."

// Works directly on entities
$text:=$tpl.render(ds.Students.first())
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
var $tpl:=cs.embed.Phrase.new("{firstName} at {school.name}")

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

- [Definition](Definition.md) — holds a `Phrase`.
- [Process.render()](Process.md#render) — renders a phrase for an entity via the orchestrator.
