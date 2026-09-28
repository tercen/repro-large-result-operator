# sci#1685 stage repro harness operator.
# Emits an OperatorResult of `n_cols` double columns per input row — the
# #1659 incident shape end to end: the operator TSON-encodes the whole
# result into its own RAM, the worker writes it to /tmp, and sarno ingests
# it through the ComputationResult path (where the #1690 sizing +
# fail-fast wiring lives).
#
# Platform cap: 1000 columns per table (schema.limit.columns) — output
# width is capped there, so the point size is driven by INPUT ROWS:
#   dry-check: 125k rows x 1000 cols = ~1.0 GB (worker-8: 5.07 GB booking
#     ceiling, measured via `system workers` 2026-09-28 — operator peak
#     must stay well under ~5 GB)
#   real point: 437.5k rows x 1000 cols = ~3.5 GB (worker-16 post-roll)
suppressPackageStartupMessages({
  library(tercen)
  library(dplyr)
})

ctx <- tercenCtx()

nCols <- as.integer(ctx$op.value('n_cols'))
if (is.na(nCols) || nCols < 1) {
  stop("n_cols must be a positive integer, got ", nCols)
}

# row count comes from the input crosstab (100k-row harness table: 1 row
# factor, 1 y column -> a 100k x 1 matrix)
m <- ctx$as.matrix()
nRows <- nrow(m)
rm(m)

message(sprintf("repro-large-result: %d rows x %d cols (~%.2f GB of doubles)",
                nRows, nCols, 8 * as.double(nRows) * as.double(nCols) / 1e9))

out <- matrix(0.1, nrow = nRows, ncol = nCols)
colnames(out) <- paste0("v", seq_len(nCols))

as_tibble(out) %>%
  mutate(.ci = as.integer(seq_len(nrow(.)) - 1)) %>%
  ctx$addNamespace() %>%
  ctx$save()
