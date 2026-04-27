# Processor

The `Processor` class is a thin wrapper around [cs.embed.AIKit.OpenAI](https://github.com/4d/4D-AIKit/blob/main/Documentation/Classes/OpenAI.md) focused on embeddings. It exposes two functions — one for a single text, one for a batch — and handles retries with exponential backoff (respecting the `Retry-After` header when present).

It is stateless beyond configuration and safe to share between processes.

## Properties

| Property Name | Type                    | Description                                                  |
|---------------|-------------------------|--------------------------------------------------------------|
| `client`      | cs.embed.AIKit.OpenAI         | The underlying AIKit client used for HTTP requests.          |
| `maxRetries`  | Integer                 | Maximum number of retries on transient errors. Default: `3`. |
| `backoffMs`   | Integer                 | Base delay (ms) between retries. Doubled each attempt.       |

## Class constructor

Create a processor. All options are optional.

| Argument Name | Type   | Description                                                                 |
|---------------|--------|-----------------------------------------------------------------------------|
| *options*     | Object | `{client, maxRetries, backoffMs}` — any field may be omitted.               |

```4d
// Default — uses cs.embed.AIKit.OpenAI.new() internally
var $proc:=cs.embed.Processor.new()

// Provide a pre-configured AIKit client (custom API key, base URL, etc.)
var $client:=cs.embed.AIKit.OpenAI.new({apiKey: "…"; baseURL: "https://server.ai"})
var $proc:=cs.embed.Processor.new({client: $client; maxRetries: 5; backoffMs: 1000})
```

## Functions

### embed()

**embed**(*text* : Text ; *model* : Text) : 4D.Vector

Embed a single text. Returns a `4D.Vector`.

| Argument        | Type      | Description                                                                 |
|-----------------|-----------|-----------------------------------------------------------------------------|
| *text*          | Text      | The text to vectorize.                                                      |
| *model*         | Text      | The embedding model to use (e.g. `"text-embedding-3-small"`).              |
| Function result | 4D.Vector | The embedding vector.                                                       |

Throws if retries are exhausted or the API returns a non-retryable error.

```4d
var $vec:=$proc.embed("it rains cats and dogs"; "text-embedding-3-small")
```

### embedBatch()

**embedBatch**(*texts* : Collection ; *model* : Text) : Collection

Embed a collection of texts in a single API call. Returns a collection of `4D.Vector` preserving the input order.

| Argument        | Type       | Description                                                                 |
|-----------------|------------|-----------------------------------------------------------------------------|
| *texts*         | Collection | Collection of Text to vectorize. Empty or `Null` returns `[]`.              |
| *model*         | Text       | The embedding model to use.                                                 |
| Function result | Collection | Collection of `4D.Vector`, same order and length as *texts*.               |

```4d
var $vectors:=$proc.embedBatch(["hello"; "world"]; "text-embedding-3-small")
// $vectors[0] is the vector for "hello"
// $vectors[1] is the vector for "world"
```

## Retry policy

Transient errors (HTTP 408, 409, 429, 5xx) are retried up to `maxRetries` times.

- If the response carries a `Retry-After` or `retry-after-ms` header, the processor waits that long.
- Otherwise, it waits `backoffMs * 2^attempt`.

Non-retryable errors are thrown immediately — see [OpenAIError](https://github.com/4d/4D-AIKit/blob/main/Documentation/Classes/OpenAIError.md) for the thrown shape.

## See also

- [Process](Process.md)
- [OpenAIEmbeddingsAPI](https://github.com/4d/4D-AIKit/blob/main/Documentation/Classes/OpenAIEmbeddingsAPI.md) (AIKit)
