# sci#1685 stage repro harness operator.
# Emits an OperatorResult of `n_cols` double columns per input row — the
# #1659 incident shape end to end: the operator TSON-encodes the whole
# result into its own RAM, the worker writes it to /tmp, and sarno ingests
# it through the ComputationResult path (where the #1690 sizing +
# fail-fast wiring lives).
#
# Size points (n_cols): 1250 -> ~1.0 GB on 100k input rows (dry-check,
# worker-8: 5.07 GB booking ceiling — measured via `system workers`,
# 2026-09-28 — so the operator peak must stay well under ~5 GB);
# 4375 -> ~3.5 GB (real point, worker-16 post-roll).
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
