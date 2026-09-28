# repro-large-result-operator

sci#1685 stage repro harness producer. An ROperator (R 4.0.4, no container
image) that emits an OperatorResult of `n_cols` double columns per input
row — reproducing the #1659 incident shape end to end: whole-result TSON
encode in the operator pod → worker `/tmp` → sarno ComputationResult
ingestion (where the #1690/#1692 sizing + fail-fast wiring lives).

Size points (on the 100k-row harness table): dry-check 125k input rows x 1000 cols ≈ 1.0 GB
(dry-check, worker-8 — its booking ceiling is 5.07 GB); rows-driven; see main.R — dry 125k×1000 ≈ 1.0 GB, real 437.5k×1000 ≈ 3.5 GB
(real point, worker-16, post-roll).

No analysis value. Runbook lives in tercen/sci `repro/1685/`.
