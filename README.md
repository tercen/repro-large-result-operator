# repro-large-result-operator

sci#1685 stage repro harness producer. An ROperator (R 4.0.4, no container
image) that emits an OperatorResult of `n_cols` double columns per input
row — reproducing the #1659 incident shape end to end: whole-result TSON
encode in the operator pod → worker `/tmp` → sarno ComputationResult
ingestion (where the #1690/#1692 sizing + fail-fast wiring lives).

Platform cap: 1000 columns/table (schema.limit.columns) — point size is
driven by INPUT ROWS at n_cols=1000:
- dry-check: 125k rows ≈ 1.0 GB (worker-8; its booking ceiling is 5.07 GB)
- real point: 437.5k rows ≈ 3.5 GB (worker-16, post-roll)

renv note: activate.R pins renv 1.2.4 (what cran.tercen.com carries) so
the bootstrap never touches the api.github.com leg — the 0.9.2-era pin
401s there on a dead stored PAT (the customer failure the tercen/actions
repro harness diagnosed).

No analysis value. Runbook lives in tercen/sci `repro/1685/`.
