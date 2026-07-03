#!/usr/bin/env bash
#
# run_bench_ratelimit.sh — end-to-end rate-limit benchmark driver.
#
# 1. (re)launches the SimpleEmbeddingMock server with rate limiting enabled,
#    capturing its timestamped log,
# 2. runs the 4D `_bench_rateLimit` startup method headlessly against it
#    (creating/vectorizing entities), then
# 3. collects and correlates all logs:
#      - mock server log (request timestamps + 429s)
#      - 4D diagnostic log  (rate-limit / retry / adaptive-batch events)
#      - 4D vectors execution log (Logs/vectors_execution.json)
#      - the benchmark result (Logs/bench_ratelimit_result.json)
#
# Everything is copied into bench/results/<timestamp>/ with a summary.md.
#
# Usage:
#   bench/run_bench_ratelimit.sh [options]
#
# Options (all optional — sensible defaults below):
#   --port N               mock server port                 (default 8080)
#   --rpm N                requests-per-minute budget        (default 60)
#   --tpm N                tokens-per-minute budget          (default 10000)
#   --latency-ms N         artificial per-request latency    (default 0)
#   --fault-rate-limit F   probability [0..1] of random 429  (default 0)
#   --config PATH          bench config JSON to use          (default bench/bench_ratelimit.example.json)
#   --kill-after N         kill 4D after N seconds if stuck  (default 900)
#   --fourd PATH           path to the 4D binary             (default /Applications/4D.app/Contents/MacOS/4D)
#   --mock-dir PATH        SimpleEmbeddingMock checkout      (default sibling ../SimpleEmbeddingMock)
#   --python PATH          python interpreter                (default python3)
#   --headless             run 4D in headless mode           (default off)
#   --keep-server          leave the mock server running afterwards
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/Project/4D Embedding Studio.4DProject"
LOGS_DIR="$PROJECT_ROOT/Logs"
SETTINGS_DIR="$PROJECT_ROOT/Settings"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
PORT=8080
RPM=60
TPM=10000
LATENCY_MS=0
FAULT_RATE_LIMIT=0
CONFIG_SRC="$SCRIPT_DIR/bench_ratelimit.example.json"
KILL_AFTER=900
FOURD_BIN="/Applications/4D.app/Contents/MacOS/4D"
MOCK_DIR="$(cd "$PROJECT_ROOT/.." && pwd)/SimpleEmbeddingMock"
PYTHON="python3"
HEADLESS=0
KEEP_SERVER=0

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port) PORT="$2"; shift 2 ;;
        --rpm) RPM="$2"; shift 2 ;;
        --tpm) TPM="$2"; shift 2 ;;
        --latency-ms) LATENCY_MS="$2"; shift 2 ;;
        --fault-rate-limit) FAULT_RATE_LIMIT="$2"; shift 2 ;;
        --config) CONFIG_SRC="$2"; shift 2 ;;
        --kill-after) KILL_AFTER="$2"; shift 2 ;;
        --fourd) FOURD_BIN="$2"; shift 2 ;;
        --mock-dir) MOCK_DIR="$2"; shift 2 ;;
        --python) PYTHON="$2"; shift 2 ;;
        --headless) HEADLESS=1; shift ;;
        --keep-server) KEEP_SERVER=1; shift ;;
        -h|--help) sed -n '2,41p' "$0"; exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

BASE_URL="http://127.0.0.1:${PORT}/v1/"
RUN_TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$SCRIPT_DIR/results/$RUN_TS"
mkdir -p "$OUT_DIR"
SERVER_LOG="$OUT_DIR/server.log"

info()  { printf '\033[1;34m[bench]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[bench]\033[0m %s\n' "$*" >&2; }
die()   { printf '\033[1;31m[bench]\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
[[ -f "$PROJECT_FILE" ]]          || die "4D project not found: $PROJECT_FILE"
[[ -x "$FOURD_BIN" ]]             || die "4D binary not found/executable: $FOURD_BIN (use --fourd)"
[[ -f "$MOCK_DIR/server.py" ]]    || die "mock server.py not found in: $MOCK_DIR (use --mock-dir)"
[[ -f "$CONFIG_SRC" ]]            || die "bench config not found: $CONFIG_SRC (use --config)"
command -v "$PYTHON" >/dev/null   || die "python interpreter not found: $PYTHON"

# ---------------------------------------------------------------------------
# 1. Write the bench config the 4D method will read, injecting the live baseURL.
# ---------------------------------------------------------------------------
mkdir -p "$SETTINGS_DIR"
BENCH_CONFIG="$SETTINGS_DIR/bench_ratelimit.json"
"$PYTHON" - "$CONFIG_SRC" "$BENCH_CONFIG" "$BASE_URL" <<'PY'
import json, sys
src, dst, base_url = sys.argv[1], sys.argv[2], sys.argv[3]
cfg = json.load(open(src))
cfg["baseURL"] = base_url
json.dump(cfg, open(dst, "w"), indent=2)
print("[bench] wrote", dst)
PY

# ---------------------------------------------------------------------------
# 2. (Re)launch the mock server.
# ---------------------------------------------------------------------------
info "stopping any previous mock server on port $PORT ..."
pkill -f "server.py --port $PORT" 2>/dev/null || true
# Also free the port if something else grabbed it (best effort, only our python).
if command -v lsof >/dev/null; then
    for pid in $(lsof -ti "tcp:$PORT" 2>/dev/null || true); do
        if ps -p "$pid" -o command= 2>/dev/null | grep -q "server.py"; then
            kill "$pid" 2>/dev/null || true
        fi
    done
fi
sleep 1

info "launching mock server on port $PORT (rpm=$RPM tpm=$TPM latency=${LATENCY_MS}ms fault-rate-limit=$FAULT_RATE_LIMIT) ..."
(
    cd "$MOCK_DIR"
    exec "$PYTHON" server.py \
        --host 127.0.0.1 \
        --port "$PORT" \
        --rate-limit-rpm "$RPM" \
        --rate-limit-tpm "$TPM" \
        --latency-ms "$LATENCY_MS" \
        --fault-rate-limit "$FAULT_RATE_LIMIT" \
        --fault-seed 42 \
        --debug
) >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

cleanup() {
    if [[ "$KEEP_SERVER" -eq 0 ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
        info "stopping mock server (pid $SERVER_PID) ..."
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT

# Wait until the server answers its health endpoint.
info "waiting for mock server to become ready ..."
ready=0
for _ in $(seq 1 50); do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        cat "$SERVER_LOG" >&2 || true
        die "mock server exited during startup — see $SERVER_LOG"
    fi
    if curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
        ready=1; break
    fi
    sleep 0.2
done
[[ "$ready" -eq 1 ]] || die "mock server did not become ready — see $SERVER_LOG"
info "mock server ready (pid $SERVER_PID)"

# ---------------------------------------------------------------------------
# 3. Snapshot existing diagnostic logs so we can identify the new one.
# ---------------------------------------------------------------------------
mkdir -p "$LOGS_DIR"
BEFORE_DIAG="$(ls -1 "$LOGS_DIR"/4DDiagnosticLog*.txt 2>/dev/null || true)"

# ---------------------------------------------------------------------------
# 4. Run the 4D benchmark method headlessly. The method calls QUIT 4D itself;
#    a watchdog kills the process if it ever hangs.
# ---------------------------------------------------------------------------
FOURD_ARGS=(--project="$PROJECT_FILE" --startup-method=_bench_rateLimit --skip-onstartup)
if [[ "$HEADLESS" -eq 1 ]]; then
    FOURD_ARGS+=(--headless)
    info "running 4D _bench_rateLimit (headless) ..."
else
    info "running 4D _bench_rateLimit ..."
fi
FOURD_STDOUT="$OUT_DIR/4d_stdout.log"
"$FOURD_BIN" "${FOURD_ARGS[@]}" >"$FOURD_STDOUT" 2>&1 &
FOURD_PID=$!

waited=0
while kill -0 "$FOURD_PID" 2>/dev/null; do
    sleep 1
    waited=$((waited + 1))
    if [[ "$waited" -ge "$KILL_AFTER" ]]; then
        warn "4D still running after ${KILL_AFTER}s — killing pid $FOURD_PID"
        kill "$FOURD_PID" 2>/dev/null || true
        break
    fi
done
wait "$FOURD_PID" 2>/dev/null || true
info "4D finished after ${waited}s"

# ---------------------------------------------------------------------------
# 5. Collect logs.
# ---------------------------------------------------------------------------
info "collecting logs into $OUT_DIR ..."

# New diagnostic log = whichever 4DDiagnosticLog*.txt was not present before,
# falling back to the most-recently-modified one.
NEW_DIAG=""
while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    if ! grep -Fxq "$f" <<<"$BEFORE_DIAG"; then NEW_DIAG="$f"; fi
done < <(ls -1t "$LOGS_DIR"/4DDiagnosticLog*.txt 2>/dev/null || true)
if [[ -z "$NEW_DIAG" ]]; then
    NEW_DIAG="$(ls -1t "$LOGS_DIR"/4DDiagnosticLog*.txt 2>/dev/null | head -1 || true)"
fi

[[ -n "$NEW_DIAG" && -f "$NEW_DIAG" ]] && cp "$NEW_DIAG" "$OUT_DIR/4DDiagnosticLog.txt"
[[ -f "$LOGS_DIR/vectors_execution.json" ]] && cp "$LOGS_DIR/vectors_execution.json" "$OUT_DIR/vectors_execution.json"
[[ -f "$LOGS_DIR/bench_ratelimit_result.json" ]] && cp "$LOGS_DIR/bench_ratelimit_result.json" "$OUT_DIR/bench_ratelimit_result.json"
cp "$BENCH_CONFIG" "$OUT_DIR/bench_ratelimit.config.json" 2>/dev/null || true

# ---------------------------------------------------------------------------
# 6. Analyse & correlate. Produces summary.md and prints it.
# ---------------------------------------------------------------------------
"$PYTHON" - "$OUT_DIR" <<'PY'
import json, os, re, sys

out = sys.argv[1]
def path(n): return os.path.join(out, n)
def read(n):
    p = path(n)
    return open(p, encoding="utf-8", errors="replace").read() if os.path.exists(p) else ""

server = read("server.log")
diag   = read("4DDiagnosticLog.txt")
fourd  = read("4d_stdout.log")

def load(n):
    p = path(n)
    if not os.path.exists(p):
        return None
    try:
        return json.load(open(p))
    except Exception:
        return None

result = load("bench_ratelimit_result.json")
execlog = load("vectors_execution.json")

# --- server log stats ---
srv_requests = len(re.findall(r'"POST /v1/embeddings', server)) or server.count("POST /v1/embeddings")
srv_429 = len(re.findall(r"\b429\b", server))
srv_500 = len(re.findall(r"\b500\b", server))
# first / last timestamp like [03/Jul/2026 14:22:45]
srv_times = re.findall(r"\[([0-3]\d/\w{3}/\d{4} \d{2}:\d{2}:\d{2})\]", server)
srv_first = srv_times[0] if srv_times else "n/a"
srv_last  = srv_times[-1] if srv_times else "n/a"

# --- diagnostic log stats (events emitted by _Logger / Process) ---
def dcount(needle): return diag.count(needle)
diag_rate_limit_hit = dcount("Rate limit hit")
diag_wait_tokens    = dcount("Rate limiter waiting (tokens)")
diag_wait_requests  = dcount("Rate limiter waiting (requests)")
diag_batch_adapted  = dcount("Batch size adapted")
diag_critical       = dcount("Critical API error")

lines = []
lines.append(f"# Rate-limit benchmark — {os.path.basename(out)}\n")

if result:
    lines.append("## Benchmark run")
    lines.append(f"- baseURL: `{result.get('baseURL')}`  model: `{result.get('model')}`")
    lines.append(f"- maxRetries: {result.get('maxRetries')}  backoffMs: {result.get('backoffMs')}")
    lines.append(f"- started: {result.get('startedAt')}  finished: {result.get('finishedAt')}\n")
    lines.append("| scenario | entities | batch | wall (ms) | updated | apiCalls | tokens | success | errors |")
    lines.append("|---|---:|---:|---:|---:|---:|---:|:--:|---:|")
    all_ok = True
    for sc in result.get("scenarios", []):
        r = sc.get("result", {}) or {}
        ok = bool(r.get("success"))
        all_ok = all_ok and ok and not sc.get("error")
        lines.append("| {} | {} | {} | {} | {} | {} | {} | {} | {} |".format(
            sc.get("name"), sc.get("entities"), sc.get("batchSize"), sc.get("wallMs"),
            r.get("entitiesUpdated", "-"), r.get("apiCalls", "-"), r.get("totalTokens", "-"),
            "✅" if ok else "❌", len(r.get("errors", []) or [])))
    lines.append("")
    verdict = "PASS ✅ — all records processed without interruption" if all_ok \
        else "FAIL ❌ — at least one scenario reported an error"
    lines.append(f"**Verdict: {verdict}**\n")
else:
    lines.append("> No bench_ratelimit_result.json produced — check 4d_stdout.log\n")

lines.append("## Mock server log")
lines.append(f"- embedding requests: {srv_requests}")
lines.append(f"- 429 (rate limited): {srv_429}")
lines.append(f"- 500 (server error): {srv_500}")
lines.append(f"- window: {srv_first} → {srv_last}\n")

lines.append("## 4D diagnostic log — rate-limit behaviour")
lines.append(f"- retries after 429 ('Rate limit hit'): {diag_rate_limit_hit}")
lines.append(f"- pre-flight waits (token budget): {diag_wait_tokens}")
lines.append(f"- pre-flight waits (request budget): {diag_wait_requests}")
lines.append(f"- adaptive batch resizes: {diag_batch_adapted}")
lines.append(f"- critical API errors: {diag_critical}\n")

if execlog:
    lines.append("## Vectors execution log (Logs/vectors_execution.json)")
    lines.append(f"- status: {execlog.get('status')}")
    lines.append(f"- startTime: {execlog.get('startTime')}  endTime: {execlog.get('endTime')}")
    lines.append(f"- promptTokens: {execlog.get('promptTokens')}  totalTokens: {execlog.get('totalTokens')}\n")

lines.append("## Correlation")
observed = diag_rate_limit_hit + diag_wait_tokens + diag_wait_requests
lines.append(f"- server emitted **{srv_429}** 429 responses; 4D reacted with "
             f"**{diag_rate_limit_hit}** retries + **{diag_wait_tokens + diag_wait_requests}** pre-flight waits.")
if srv_429 > 0 and observed == 0:
    lines.append("- ⚠️ server rate-limited but 4D logged no waits/retries — check diagnostic log level / headers.")
elif srv_429 == 0:
    lines.append("- No 429s were emitted (budget high enough or latency absorbed load). "
                 "Lower --rpm/--tpm or raise --fault-rate-limit to force throttling.")
lines.append("")

report = "\n".join(lines)
open(path("summary.md"), "w").write(report)
print(report)
PY

echo
info "results saved to: $OUT_DIR"
