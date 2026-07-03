#!/usr/bin/env bash
#
# sweep_ratelimit.sh — run the rate-limit benchmark across a matrix of server
# configurations (rpm / tpm / fault-rate-limit) and aggregate every run into a
# single comparison table (printed + saved as sweep summary.md).
#
# Each matrix row re-launches the mock server with different limits via
# run_bench_ratelimit.sh, using the same scenario set (bench/sweep_ratelimit.config.json
# by default — moderate entity counts so the whole sweep stays reasonable).
#
# Usage:
#   bench/sweep_ratelimit.sh [options passed through to run_bench_ratelimit.sh]
#
# Useful pass-through options: --headless --fourd PATH --mock-dir PATH --python PATH
#
# The matrix itself is defined in the MATRIX array below — edit it to taste.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/run_bench_ratelimit.sh"
SWEEP_CONFIG="$SCRIPT_DIR/sweep_ratelimit.config.json"
PYTHON="${PYTHON:-python3}"

# Matrix rows: "label|rpm|tpm|latency_ms|fault_rate_limit"
MATRIX=(
    "unthrottled|0|0|2|0"
    "throttle-600rpm|600|100000|2|0"
    "throttle-300rpm|300|40000|2|0"
    "throttle-120rpm|120|15000|2|0"
    "faults-10pct|0|0|2|0.10"
    "faults-25pct|0|0|2|0.25"
    "throttle+faults|600|100000|2|0.15"
)

PASSTHRU=("$@")

RUN_TS="$(date +%Y%m%d_%H%M%S)"
SWEEP_DIR="$SCRIPT_DIR/sweep/$RUN_TS"
mkdir -p "$SWEEP_DIR"

info() { printf '\033[1;36m[sweep]\033[0m %s\n' "$*"; }

MANIFEST="$SWEEP_DIR/manifest.tsv"
: >"$MANIFEST"

for row in "${MATRIX[@]}"; do
    IFS='|' read -r label rpm tpm lat fault <<<"$row"
    info "=== $label (rpm=$rpm tpm=$tpm latency=${lat}ms fault=$fault) ==="

    out="$("$RUNNER" \
        --config "$SWEEP_CONFIG" \
        --rpm "$rpm" --tpm "$tpm" --latency-ms "$lat" --fault-rate-limit "$fault" \
        --kill-after 3600 \
        "${PASSTHRU[@]}" 2>&1 | tee "$SWEEP_DIR/${label}.console.log")"

    run_dir="$(printf '%s\n' "$out" | sed -n 's/.*results saved to: //p' | tail -1)"
    if [[ -z "$run_dir" || ! -d "$run_dir" ]]; then
        info "WARNING: could not locate results dir for '$label' — skipping"
        continue
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$label" "$rpm" "$tpm" "$lat" "$fault" "$run_dir" >>"$MANIFEST"
done

# ---------------------------------------------------------------------------
# Aggregate every run into one comparison table.
# ---------------------------------------------------------------------------
"$PYTHON" - "$MANIFEST" "$SWEEP_DIR" <<'PY'
import json, os, re, sys

manifest, sweep_dir = sys.argv[1], sys.argv[2]
rows = []
for line in open(manifest):
    line = line.rstrip("\n")
    if not line:
        continue
    label, rpm, tpm, lat, fault, run_dir = line.split("\t")
    rows.append((label, rpm, tpm, lat, fault, run_dir))

def read(p):
    return open(p, encoding="utf-8", errors="replace").read() if os.path.exists(p) else ""

def load(p):
    try:
        return json.load(open(p))
    except Exception:
        return None

out = []
out.append("# Rate-limit sweep — " + os.path.basename(sweep_dir) + "\n")
out.append("Same scenario set per row; only the mock server limits/faults change.\n")
out.append("| config | rpm | tpm | fault | records | API calls | srv 429 | srv 500 | retries | waits | wall (s) | verdict |")
out.append("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|:--:|")

for label, rpm, tpm, lat, fault, run_dir in rows:
    result = load(os.path.join(run_dir, "bench_ratelimit_result.json"))
    server = read(os.path.join(run_dir, "server.log"))
    diag   = read(os.path.join(run_dir, "4DDiagnosticLog.txt"))

    records = api = wall = 0
    all_ok = True
    if result:
        for sc in result.get("scenarios", []):
            r = sc.get("result", {}) or {}
            records += int(r.get("entitiesUpdated", 0) or 0)
            api     += int(r.get("apiCalls", 0) or 0)
            wall    += int(sc.get("wallMs", 0) or 0)
            all_ok = all_ok and bool(r.get("success")) and not sc.get("error")
    else:
        all_ok = False

    srv429 = len(re.findall(r'"POST /v1/embeddings HTTP/1.1" 429', server))
    srv500 = len(re.findall(r'"POST /v1/embeddings HTTP/1.1" 500', server))
    retries = diag.count("Rate limit hit")
    waits   = diag.count("Rate limiter waiting")

    out.append("| {} | {} | {} | {} | {} | {} | {} | {} | {} | {} | {:.1f} | {} |".format(
        label, rpm, tpm, fault, records, api, srv429, srv500, retries, waits,
        wall / 1000.0, "✅" if all_ok else "❌"))

report = "\n".join(out) + "\n"
open(os.path.join(sweep_dir, "summary.md"), "w").write(report)
print("\n" + report)
PY

info "sweep results saved to: $SWEEP_DIR"
