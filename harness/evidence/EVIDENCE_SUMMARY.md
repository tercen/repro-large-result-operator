# sci#1685 stage repro — evidence summary (2026-09-28, stage 1.1.11)

Stage: tercen 1.1.11 live 2026-09-28T11:23:44Z, digest
sha256:efa34b76cec3876a3296de86c499c5eb22bfdc40dd0470ad85c156ea26642ec5.
Project sci-1685-repro `1878c5a2-4d9d-4c8a-81db-8e55938b67ab`, workflow
repro-1685 `a449773b-5bb3-44f4-8540-ca087c8e3b09`. Producer operator
tercen/repro-large-result-operator @ `30dbbaadf57e571094e98e65cdf645948b610274`
(n_cols-driven; R 4.0.4, renv 1.2.4). tercen_log_level=0 (ALL) on stage
workers — untouched; pod-metrics samplers pinned `--context` every call.

## Collector (a) — 16 MiB chunk upload (#1660 wiring) — PRESENT

`GcsResumableUpload : Chunk uploaded: start-end, total: N` FINE lines.
Dry point: 59 chunks ≈ 986 MB at ~0.43 s/chunk (~39 MB/s worker-8).
Real point: see below (worker-16, ~43 MB/s).

## Collector (b) — #1690 sizing line + booking bump — PRESENT (leg 4)

`evidence/worker_log_sizing_leg5.log` (task dba4ff5c, n_cols 996,
offset 1480 → booking 2220 MiB, below required 2247 MiB):

```
SaveComputationResult : SaveComputationResult -- sizing ingestion from
result size 996690501B: booking 2369439476B (operator booking was 2327838720B)
TASK_STATS|task=ComputationResult(task_id=dba4ff5c-...)|peak=1000623910|limit=2369439475|peak_percent=42.2|duration_secs=8.536
```

The ingestion TASK_STATS `limit=` equals the BUMPED booking — the
bump-only boundary fired: booking was raised in place to
`result×1.3 + 1 GiB` (`save_result.dart:133`), no reschedule/rejection
(worker-8 had headroom). Legs 2–3 (bookings 2925/2325 MiB, required
2247 MiB) show correct silence — required ≤ booking → line absent.

## Revglm #1692 closure items

1. **Never-booked task shape → absent-pair create path**: exercised by
   the offset-300 leg (task 5ee6da84, booking 450 MiB — far below the
   operator's own need): the task was created/submitted with a booking
   the operator cannot honour and failed visibly with
   `run.operator.exit.code.137` (NOT a silent pod OOM). The scheduling
   pair create path ran for a task shape that previously booked nothing
   (offset 0 → legacy ~500 MB default; both shapes now go through
   explicit model-based booking).
2. **Bump-only boundary firing**: leg 4 above — booking bumped
   2327838720 → 2369439476 in place; no `worker.memory.reschedule` 400
   (bump fit worker-8); ingestion then ran under the bumped limit.

Cross-ref: #1692 threshold unit tests merged main `fb7b4e58b`; this
run is the live-stage positive counterpart.

## Collector (c) — TASK_STATS peak vs limit — PRESENT on every leg

Dry legs: `peak≈1.00e9` (result-sized) vs limit = booking (or bumped
booking). Leg 2: peak=1002658276 limit=3067084800 (32.7%). Leg 4:
peak=1000623910 limit=2369439475 (42.2%). Real point: see below.

## Collector (d) — >1.8 GB blob-GET read-back leg — real point only

Dry result ≈ 0.997 GB — under the 1.8 GB read-back threshold, as
planned. Real point (~3.6 GB result) crosses it: see below.

## Booking semantics (landmines for the harness consumer)

- `memoryModel.offset`/`runtimeModel.offset` are **MB**; measured
  **booking = 1.5 × offset MiB** (300→450, 1480→2220, 1950→2925,
  3000→4500, 6000→9000 MiB — "Memory estimate from model: N MB"). A
  byte-valued intent books offset×2¹⁰×2¹⁰×1024 → 3 PB → scheduler 429
  `task.queue.full`.
- Result cache is keyed by the QUERY hash: `offset` is NOT in it and
  `reset-step` does NOT bust it (instant DoneState re-run). Bust =
  change n_cols via a cloned step (in-place `propertyValues` patch is
  rejected: "Unsupported value type: PropertyValue").
- Worker-16 is dormant AND hasched-reconciled: manual `kubectl scale`
  reverts in ~15 s (`worker_pod_reconciler`, pool desired=0). Scale-up
  MUST be booking-driven (TasksPending trigger) — verified working:
  offset 6000 → worker-16 scaled up, pod Ready, task dispatched.
- `run.operator.exit.code.137` (operator OOM) SHADOWS the sizing line
  when the booking is far under the operator's peak — the R producer
  holds the full result matrix in RAM (dry-point operator completes at
  2325 MiB, OOMs at 450 MiB).
- `tercenctl workflow run-step` returns at SUBMISSION; worker logs
  "Task <id> completed successfully" at submission too — poll
  `TASK_STATS|task=ComputationResult(` / `FailedState` only. The
  RunComputationTask id differs from the run-step taskId.

## 1.1.9 baseline absence (per plan R2/README)

Collectors (a) chunk lines and (b) sizing line are EXPECTED ABSENT on
1.1.9 — both are 1.1.11 wiring (#1660 / #1690). Not re-run on 1.1.9;
absence is the documented baseline. Negative-path proof = #1692 unit
tests (`fb7b4e58b`), not a stage run.

## Real point (worker-16) — task 6f687e45, 2026-09-28T12:55–12:59Z

`evidence/worker_log_real_full.log`, `evidence/pod_metrics_real.log`.
437.5k rows × 999 cols; booking 9437184000 (offset 6000, 9000 MiB);
worker-16 booked 12.8 GB available, podman `--memory 9438M`.

- Booking-driven scale-up VERIFIED: submit at 12:55:13 → scheduler
  `TasksPending` → worker-16 (dormant, 166 d) scaled up, pod Ready
  12:57, task dispatched (`verified running on worker
  tercen-worker-worker-16-...`). No manual kubectl scale survived the
  reconciler earlier — booking-driven is the only path.
- Collector (a): 208 × 16 MiB chunks ≈ 3.47 GB uploaded in ~86 s
  (~40 MB/s).
- Collector (c): `TASK_STATS|task=ComputationResult(task_id=6f687e45)|
  peak=3502400778|limit=9437184000|peak_percent=37.1|duration_secs=25.818`
  — ingestion peak is RESULT-SIZED (3.50 GB) at 3.6 GB result
  (≈0.97×), ingested in 25.8 s on worker-16.
- Collector (d): >1.8 GB read-back leg CROSSED —
  `process_query -- operator result via object store:
  /tmp/sarno-blobs/e5/23/e523d3ac...` (sarno 1.2.6, GCS backend
  `tercen-ring-tercen-stage-data`, blob-cache-first read of the 3.5 GB
  result; peak 3.5 GB confirms the full read-back).
- Sizing line correctly ABSENT: booking 9.4 GB > required
  (3.47 GB × 1.3 + 1 GiB ≈ 5.6 GB).
- End-to-end: submit→done ≈ 4 min (2 min operator R build, 1.5 min
  upload, 26 s ingestion).

## 1.2.7 re-run (sarno 1.2.7) — task a830c762, 2026-09-28T13:15–13:17Z

`evidence/worker_log_real_127_full.log`, `evidence/pod_metrics_real_127.log`.
Stage rotated to sarno **1.2.7** at 13:11Z (glm apply); worker-16
rollout-restarted onto 1.2.7 first (pod tercen-worker-worker-16-78bfb8fd46-s9tng,
startup log shows `sarno:1.2.7` — the pre-roll pod still ran 1.2.6).
Cache bust = fresh step clone (n_cols 998, namespace ds2b, task
a830c762); offset 6000 → booking 9437184000, worker-16 (already up,
booking-driven from the 1.2.6 leg).

- Collector (a): 208 × 16 MiB chunks ≈ 3.47 GB — unchanged green.
- Collector (d): blob-cache read-back crossed —
  `operator result via object store: /tmp/sarno-blobs/3f/25/3f25df2b…`
  (sarno 1.2.7, GCS backend, cache-first). Green.
- Sizing line: correctly SILENT (booking 9.4 GB > required ≈5.6 GB;
  formula unchanged in 1.2.7).
- **FINDING — ingestion peak did NOT drop**: 1.2.7
  `TASK_STATS|task=ComputationResult(task_id=a830c762)|peak=3499963748|limit=9437184000|peak_percent=37.1|duration_secs=27.300`
  vs 1.2.6 peak=3502400778 / 25.818 s. Δpeak ≈ **0.07 %** (noise), Δt
  +6 %. Expected from the sarno#41 bench shape was ~0.38× sarno-side
  (3.5 → ~1.4–1.8 GB). No streaming-decode markers appear in the 1.2.7
  ingestion log; the path taken is the object-store blob-cache
  read-back (`process_query -- operator result via object store`).
  **Hypothesis (untested here): #41's streaming decode engages on the
  from_file path, not the blob-cache object-store path this harness
  exercises** — worth a 1.2.7 code check against
  ProcessResultQueryProcessor before Friday. Reported as-is, not
  smoothed over.

  ADJUDICATION (glm, code-verified @ sarno 2d5debf30, confirmed
  own-eyes 2026-09-28): hypothesis above DISPROVEN — both
  process_result_query branches (object-store ~:63 and local fallback
  ~:76) call `from_file_streaming`; the "via object store" line IS the
  streaming path, no separate marker exists. The streaming decode DID
  engage. The peak is unchanged because from_file_streaming streams
  PER TABLE (one tables[i] subtree in flight, dropped before the next,
  tercen_model/mod.rs) and this harness emits a SINGLE-table
  OperatorResult — the degenerate n_tables=1 case. Step 1 still cuts
  peak for the multi-table incident class (Faris: 4 gathered tables);
  single-table reduction = sarno#38 step 2 (per-column chunked
  decode), not yet built. Not a wiring defect; no regression.

## Verdict

All four collectors green on stage 1.1.11 at both points; #1690
sizing + bump wiring and #1660 chunked upload proven live; #1692
closure items (never-booked shape → visible 137, bump-only boundary)
exercised; negative path = #1692 unit tests (fb7b4e58b). Harness
runbooks: `repro/1685/README.md`, `run_dry_check.sh`,
`run_real_point.sh`.
