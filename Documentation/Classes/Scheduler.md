# Scheduler

The `Scheduler` class is the public entry point for the **automated embedding recalculation** service. It maintains a background task that runs the embedding pipeline (see [Process](Process.md)) at a configured interval or a fixed daily time, guarantees that **at most one** recalculation batch runs at a time, and exposes runtime status for administration and monitoring interfaces.

It is a **singleton**, accessed through `cs.EmbeddingStudio.Scheduler.me`.

The scheduler runs two named workers:

| Worker | Role |
|--------|------|
| `EmbeddingStudioScheduler` | Background loop that re-reads the config each cycle, computes the next run and fires when due. |
| `EmbeddingStudio` | Execution worker that runs one recalculation batch (shared with the Studio UI, so scheduled and manual runs are serialized). |

## Configuration

The configuration lives under the `scheduler` key of `Settings/embeddings.json`:

```json
{
  "scheduler": {
    "mode": "interval",
    "intervalHours": 3,
    "startFrom": "lastExecution",
    "dailyTime": "00:00"
  }
}
```

| Key             | Type    | Values / range                     | Description                                                                 |
|-----------------|---------|------------------------------------|-----------------------------------------------------------------------------|
| `mode`          | Text    | `"disabled"` \| `"interval"` \| `"daily"` | Scheduling mode. Absent/unknown ⇒ `disabled` (no automatic run).      |
| `intervalHours` | Integer | `1`..`24`                          | Interval mode only. Out-of-range ⇒ default `3`.                             |
| `startFrom`     | Text    | `"now"` \| `"lastExecution"`       | Interval mode only. Anchor of the interval (see below). Default `now`.       |
| `dailyTime`     | Text    | `"HH:MM"`                          | Daily mode only. Time of day for the recalculation. Default `"00:00"`.       |

**Interval anchoring (`startFrom`)**

- `now` — the interval is anchored on the moment the scheduler is armed (`start()`), including after a server restart.
- `lastExecution` — the interval is anchored on the last completed recalculation. If the elapsed time since the last run already exceeds the interval (e.g. after a restart), the run is triggered immediately. If there is no prior run, it runs immediately.

The effective configuration is read from the file on **every loop cycle**, so changes take effect without restarting the scheduler.

## Starting the scheduler

Configuring a `mode` is **not enough**: nothing runs until the scheduler is started. There are two ways to get there, and which one applies depends on a single option of your host database.

### 1. Automatic — let the host database start it

In the host database, open **Settings > Security** and check **"Execute 'On Host Database Event' method of the components"** (it is *unchecked* by default, for security reasons).

With this option on, 4D Embedding Studio starts the scheduler by itself when the host database opens, and stops it when the host database closes. There is nothing else to write.

Use [`autoStart()`](#autostart) to check whether the option is on:

```4d
If (Not(cs.EmbeddingStudio.Scheduler.me.autoStart()))
	// the option is off — I must start the scheduler myself
	cs.EmbeddingStudio.Scheduler.me.start()
End if
```

### 2. Manual — start it from your own code

If you prefer to leave the option off, the scheduler never starts on its own. Call [`start()`](#start) from wherever it suits you — typically the host `On Startup` or `On Server Startup` database method — and [`stop()`](#stop) when the database closes (`On Exit` / `On Server Shutdown`):

```4d
// Host "On Server Startup"
cs.EmbeddingStudio.Scheduler.me.start()

// Host "On Server Shutdown"
cs.EmbeddingStudio.Scheduler.me.stop()
```

`start()` is idempotent, so calling it from several places is harmless.

### Checking that it really runs

[`isStarted()`](#isstarted) tells you whether the background loop is alive right now — the answer to "is my schedule actually being watched?":

```4d
var $s:=cs.EmbeddingStudio.Scheduler.me.status()
If ($s.enabled && Not($s.started))
	ALERT("A schedule is configured but the scheduler is not started.")
End if
```

## Functions

### start()

**start**() : Boolean

Arms the scheduler and starts the background loop worker if it is not already running. Idempotent — calling it again while already armed simply refreshes the "start from now" anchor.

| Result  | Type    | Description        |
|---------|---------|--------------------|
| result  | Boolean | Always `True`.     |

```4d
cs.EmbeddingStudio.Scheduler.me.start()
```

### stop()

**stop**()

Disarms the scheduler and stops the background loop worker. A recalculation batch already in progress is **not** interrupted — it finishes normally (use [`cancel()`](#cancel) to request an early stop).

```4d
cs.EmbeddingStudio.Scheduler.me.stop()
```

### cancel()

**cancel**()

Requests a **cooperative** cancel of the batch currently running. The running batch is never force-killed; it stops gracefully between two chunks. Has no effect if no batch is running.

```4d
cs.EmbeddingStudio.Scheduler.me.cancel()
```

### force()

**force**() : Object

Forces a recalculation **now**, regardless of the schedule. It honors the single-batch rule: if a batch is already running, the forced trigger is skipped (and logged). Non-blocking — the run happens on the execution worker.

| Result  | Type   | Description                                  |
|---------|--------|----------------------------------------------|
| result  | Object | The current [status](#status) object.        |

```4d
var $status:=cs.EmbeddingStudio.Scheduler.me.force()
```

### status()

**status**() : Object

Returns the current scheduler status, without any input parameter — suitable for administration and monitoring displays.

| Result  | Type   | Description                              |
|---------|--------|------------------------------------------|
| result  | Object | See [Status object](#status-object).     |

```4d
var $s:=cs.EmbeddingStudio.Scheduler.me.status()
If ($s.running)
	ALERT("A recalculation is running since "+$s.batchStart)
End if
```

#### Status object

| Key             | Type          | Description                                                                     |
|-----------------|---------------|---------------------------------------------------------------------------------|
| `enabled`       | Boolean       | `False` when `mode = "disabled"`.                                                |
| `mode`          | Text          | Effective mode (`disabled` \| `interval` \| `daily`).                            |
| `armed`         | Boolean       | `True` when the background loop is armed (after `start()`, until `stop()`).      |
| `running`       | Boolean       | `True` while a recalculation batch is in progress.                              |
| `batchStart`    | Text \| Null  | ISO timestamp of the running batch start (`Null` when idle).                    |
| `lastExecution` | Text \| Null  | ISO timestamp of the last completed run (`Null` if none yet).                   |
| `nextRun`       | Text \| Null  | ISO timestamp of the next scheduled run (`Null` when disabled).                 |
| `lastResult`    | Text \| Null  | Result of the last trigger: `started` \| `skipped` \| `completed` \| `failed`.  |
| `error`         | Text \| Null  | Error summary when the last run failed (safe for admin display), else `Null`.   |
| `started`       | Boolean       | `True` when the background loop is really alive (see [`isStarted()`](#isstarted)). |
| `autoStart`     | Boolean       | `True` when the host database starts the scheduler by itself (see [`autoStart()`](#autostart)). |

### isStarted()

**isStarted**() : Boolean

Tells whether the scheduler is **effectively running**, i.e. whether its background loop is alive at this very moment. Unlike the `armed` flag of the [status](#status-object), it reflects reality: if the loop was never started, or was killed, the result is `False`.

| Result  | Type    | Description                                    |
|---------|---------|------------------------------------------------|
| result  | Boolean | `True` when the background loop is alive.      |

```4d
If (Not(cs.EmbeddingStudio.Scheduler.me.isStarted()))
	cs.EmbeddingStudio.Scheduler.me.start()
End if
```

### autoStart()

**autoStart**() : Boolean

Tells whether the host database authorizes 4D Embedding Studio to start itself, i.e. whether the **"Execute 'On Host Database Event' method of the components"** option is checked in the host **Settings > Security** (see [Starting the scheduler](#starting-the-scheduler)).

- `True` — the scheduler starts with the host database and stops with it. You have nothing to call.
- `False` — nothing starts automatically: your code must call [`start()`](#start) and [`stop()`](#stop).

The answer is read from the host structure settings. When they cannot be read, the result is `False` — the safe answer, since starting an already-started scheduler is harmless.

| Result  | Type    | Description                                                       |
|---------|---------|-------------------------------------------------------------------|
| result  | Boolean | `True` when the host starts the scheduler by itself.              |

```4d
var $auto:=cs.EmbeddingStudio.Scheduler.me.autoStart()
```

### config()

**config**() : Object

Returns the effective scheduler configuration with defaults applied (as resolved from `embeddings.json`).

| Result  | Type   | Description                                                        |
|---------|--------|--------------------------------------------------------------------|
| result  | Object | `{mode; intervalHours; startFrom; dailyTime}` (see [Configuration](#configuration)). |

```4d
var $cfg:=cs.EmbeddingStudio.Scheduler.me.config()
```

### nextRun()

**nextRun**() : Object

Computes the next scheduled run from the current configuration and state.

| Result  | Type          | Description                                                                          |
|---------|---------------|--------------------------------------------------------------------------------------|
| result  | Object \| Null | `{date : Date; time : Time; timestamp : Text; immediate : Boolean}`, or `Null` when disabled. |

```4d
var $next:=cs.EmbeddingStudio.Scheduler.me.nextRun()
```

### reload()

**reload**() : Object

No-op convenience: the configuration is re-read automatically on each loop cycle, so this simply returns the current [status](#status). Provided for callers that want an explicit "config changed, give me the up-to-date status" call.

| Result  | Type   | Description                          |
|---------|--------|--------------------------------------|
| result  | Object | The current [status](#status) object.|

## Concurrency & logging

- **Single batch** — at any time, at most one recalculation batch runs. A trigger (scheduled or forced) fired while a batch is running is **skipped**, not queued.
- **Skip traceability** — skipped triggers are logged with their timestamp in the execution history (`Logs/embeddingHistory.json`).
- **Cooperative cancel** — `cancel()` stops a running batch gracefully between chunks; it is never force-killed.
- **History** — each run records start/end timestamps, status, token usage and the computed next run date in `Logs/embeddingHistory.json` (see [ProcessResult](ProcessResult.md) for per-run details).

## Lifecycle

| Host setting | What happens | What you must do |
|--------------|--------------|------------------|
| **"Execute 'On Host Database Event' method of the components"** checked | The scheduler starts when the host database opens and stops when it closes. | Nothing. |
| Option unchecked (default) | The scheduler never starts by itself. | Call [`start()`](#start) at startup and [`stop()`](#stop) at shutdown. |

Ask [`autoStart()`](#autostart) which case you are in, and [`isStarted()`](#isstarted) whether the loop is currently alive. Stopping the scheduler never interrupts a batch in progress — it finishes normally.

## Example

```4d
// --- Start at server startup, unless the host does it for us ---
If (Not(cs.EmbeddingStudio.Scheduler.me.autoStart()))
	cs.EmbeddingStudio.Scheduler.me.start()
End if

// --- Admin panel: force a recalculation and read status ---
var $status:=cs.EmbeddingStudio.Scheduler.me.force()

// --- Monitoring: display last / next run and current state ---
$status:=cs.EmbeddingStudio.Scheduler.me.status()
var $info:="Mode: "+$status.mode\
	+" — Last: "+String($status.lastExecution)\
	+" — Next: "+String($status.nextRun)\
	+" — "+($status.running ? "running" : String($status.lastResult))

// --- Cancel a long-running batch ---
cs.EmbeddingStudio.Scheduler.me.cancel()

// --- Disable automatic runs ---
cs.EmbeddingStudio.Scheduler.me.stop()
```
