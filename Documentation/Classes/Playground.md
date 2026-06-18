# Playground

The `Playground` class provides ad-hoc, non-persisting helpers for previewing rendered phrases and computing one-off embedding vectors. Useful for similarity search inputs, debugging, REPL experimentation, or previews.

For the full batch pipeline that persists vectors on entities, see [Process](Process.md).

## Properties

| Property Name | Type                                                    | Description                                              |
|---------------|---------------------------------------------------------|----------------------------------------------------------|
| `settings`    | [Settings](Settings.md)               | The settings (vectors, batch size, phrase validation options). |
| `embedder`    | [Embedder](Embedder.md)               | The API-calling engine. Stateless and swappable.         |
| `options`     | Object                                                  | Runtime options object. |

## Class constructor

| Argument Name | Type                                      | Description                                                         |
|---------------|-------------------------------------------|---------------------------------------------------------------------|
| *settings*    | [Settings](Settings.md) | Optional. If omitted, settings are loaded from the default `Settings/vectors.json`. |
| *options*     | Object                                    | Optional runtime options. Supports `embedder` for injection. |

```4d
var $pg:=cs.EmbeddingStudio.Playground.new()
var $pg:=cs.EmbeddingStudio.Playground.new($settings)
var $pg:=cs.EmbeddingStudio.Playground.new($settings; {embedder: $mockEmbedder})
```

## Functions

### render()

**render**(*entity* : 4D.Entity ; *definitionOrPhrase* : Variant) : Text

Render a phrase for an entity and return the resulting text. No API call, no persistence.

| Argument              | Type                                                                        | Description                                                                 |
|-----------------------|-----------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| *entity*              | 4D.Entity                                                                   | The entity to render against.                                               |
| *definitionOrPhrase*  | `Null`, [Phrase](Phrase.md), [Definition](Definition.md), or Text | `Null` → auto-resolve via settings (requires a unique match). Text → compiled as a throwaway `cs.EmbeddingStudio.Phrase`. |
| Function result       | Text                                                                        | The rendered text.                                                          |

```4d
var $pg:=cs.EmbeddingStudio.Playground.new()
var $text: Text
$text:=$pg.render($student; $def)                        // use def's phrase
$text:=$pg.render($student; cs.EmbeddingStudio.Phrase.new("Hi {firstName}"))
$text:=$pg.render($student; "Student: {lastName}")       // raw template
$text:=$pg.render($student)                              // auto-resolve
```

### embed()

**embed**(*input* : Variant ; *context* : Variant ; *model* : Text) : [cs.EmbeddingStudio.EmbedderResult](EmbedderResult.md)

Compute a vector for an arbitrary input, without persisting anywhere.

| Argument        | Type                                                                                     | Description                                                                 |
|-----------------|------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| *input*         | Text or 4D.Entity                                                                        | Text → embedded directly. Entity → phrase rendered then embedded.          |
| *context*       | Text, [Phrase](Phrase.md), [Definition](Definition.md), Text template, or `Null` | Provides phrase and/or model depending on *input*.                          |
| *model*         | Text                                                                                     | Optional explicit model name. Used when *context* does not carry one.      |
| Function result | [EmbedderResult](EmbedderResult.md)                                                      | The embedding result (use `.vector` to get the 4D.Vector).                 |

Throws if no model can be determined.

```4d
var $pg:=cs.EmbeddingStudio.Playground.new()
var $vector: 4D.Vector

// Text + model
$vector:=$pg.embed("some text"; "text-embedding-3-small").vector

// Text + definition (picks up def.modelAlias)
$vector:=$pg.embed("some text"; $def).vector

// Entity + definition (uses def.phrase + def.modelAlias)
$vector:=$pg.embed($student; $def).vector

// Entity + phrase + explicit model
$vector:=$pg.embed($student; $phrase; "text-embedding-3-small").vector

// Entity + ad-hoc template + model
$vector:=$pg.embed($student; "Profile: {firstName} {lastName}"; "text-embedding-3-small").vector

// Entity alone (auto-resolve, only when exactly one def matches the dataclass)
$vector:=$pg.embed($student).vector
```

## See also

- [Process](Process.md)
- [Settings](Settings.md)
- [Definition](Definition.md)
- [Embedder](Embedder.md)
- [EmbedderResult](EmbedderResult.md)
- [Phrase](Phrase.md)
