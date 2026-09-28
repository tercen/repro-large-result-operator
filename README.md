# repro-large-result-operator

sci#1685 stage repro harness producer. An ROperator (R 4.0.4, no container
image) that emits an OperatorResult of `n_cols` double columns per input
row — reproducing the #1659 incident shape end to end: whole-result TSON
encode in the operator pod → worker `/tmp` → sarno ComputationResult
ingestion (where the #1690/#1692 sizing + fail-fast wiring lives).

Size points (on the 100k-row harness table): `n_cols` 1880 ≈ 1.5 GB
(dry-check, worker-8); 4375 ≈ 3.5 GB (real point, worker-16, post-roll).

No analysis value. Runbook lives in tercen/sci `repro/1685/`.
