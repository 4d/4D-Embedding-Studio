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

## Access

```4d
// From a host database, e.g. its "On Server Startup" method:
cs.EmbeddingStudio.Scheduler.me.start()
```

The component does not arm itself inside a host; the host is responsible for calling `start()` (see [Lifecycle](#lifecycle)).

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

The scheduler is armed explicitly. When 4D Embedding Studio runs standalone (or as the host), its `On Server Startup` database method arms it automatically. When loaded as a **component** inside another host, that host must arm it from its own startup code:

```4d
// Host "On Server Startup"
cs.EmbeddingStudio.Scheduler.me.start()
```

## Example

```4d
// --- Arm at server startup ---
cs.EmbeddingStudio.Scheduler.me.start()

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
