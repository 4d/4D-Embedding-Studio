# ProcessResult

The `ProcessResult` class is the return value of every batch entry point of [Process](Process.md) (`process`, `processEntity`, `processEntitySelection`). It accumulates statistics, per-error breakdowns, and wall-clock duration.

The orchestrator never throws out of its public batch API — failures are recorded here and the job continues. The caller decides what to do with them.

## Properties

| Property Name           | Type       | Description                                                              |
|-------------------------|------------|--------------------------------------------------------------------------|
| `definitionsProcessed`  | Integer    | Number of [Definition](Definition.md) entries processed. |
| `entitiesConsidered`    | Integer    | Number of entities that passed the "needs recompute" filter.             |
| `entitiesUpdated`       | Integer    | Number of entities whose vector was successfully written and saved.      |
| `entitiesSkipped`       | Integer    | Number of entities that could not be processed: individual embed or save errors, or whole-chunk API failures (those entities are left unchanged for the next run). |
| `apiCalls`              | Integer    | Number of embeddings API calls made.                                     |
| `durationMs`            | Integer    | Total duration of the job in milliseconds.                               |
| `errors`                | Collection | List of `{scope, ref, message}` entries recorded during the run.         |

### Computed properties

| Property  | Type    | Description                                       |
|-----------|---------|---------------------------------------------------|
| `success` | Boolean | `True` when `errors.length = 0`.                  |

### Error entry shape

| Field     | Type    | Description                                                                  |
|-----------|---------|------------------------------------------------------------------------------|
| `scope`   | Text    | One of `"definition"` (validation failure), `"chunk"` (whole-batch API failure), `"entity"` (individual embed or save failure), `"selection"` (null selection passed). |
| `ref`     | Variant | Scope-dependent reference — dataclass/vector name, chunk tag, or entity key. |
| `message` | Text    | Human-readable error message.                                                |

## Functions

### toObject()

**toObject**() : Object

Returns a plain object suitable for logging or JSON serialization.

| Argument        | Type   | Description                                 |
|-----------------|--------|---------------------------------------------|
| Function result | Object | A JSON-friendly snapshot of the report.     |

```4d
var $r:=$p.process()
LOG EVENT(Into 4D log file; JSON Stringify($r.toObject()))
```

## Example

```4d
var $r:=$p.processEntitySelection(ds.Students.all(); $def)

If ($r.success)
	ALERT("Updated "+String($r.entitiesUpdated)+" students in "+String($r.durationMs)+" ms")
Else
	var $err : Object
	For each ($err; $r.errors)
		ALERT("[" + $err.scope + "] " + String($err.ref) + " — " + $err.message)
	End for each
End if
```

## See also

- [Process](Process.md)
