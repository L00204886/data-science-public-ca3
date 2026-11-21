# ============================================================
# CA3 Predictive Modelling - Airline passenger satisfaction
# Master runner: execute Scripts 01 to 05 in sequence and record
#                every section and result in output/run_log.txt
# Author: Eamon Foy (L00204886)
# Usage (from project root): Rscript scripts/run_all.R
# Reads:  scripts/01_data_preparation.R ... scripts/05_compare_and_forecast.R
# Writes: output/run_log.txt (plus all tables, figures and saved models)
# ============================================================

dir.create("output", showWarnings = FALSE)

# Widen print output so multi-column summary tables stay on single rows
# instead of wrapping across blocks in output/run_log.txt.
old_width <- options(width = 120)

# Mirror console output to output/run_log.txt so every diagnostic number
# and summary table can be audited without re-running the pipeline.
log_file <- file("output/run_log.txt", open = "wt")
sink(log_file, split = TRUE)

scripts <- c(
  "scripts/01_data_preparation.R",
  "scripts/02_assumptions.R",
  "scripts/03_logistic_regression.R",
  "scripts/04_random_forest.R",
  "scripts/05_compare_and_forecast.R"
)

# Run each script in a fresh local environment with echo = FALSE and
# print.eval = TRUE so the log shows section headings and results cleanly
# without echoing plumbing code, while preventing silent variable leakage.
for (s in scripts) {
  cat("\n============================================================\n")
  cat("Running", s, "\n")
  cat("============================================================\n")
  source(s, echo = FALSE, print.eval = TRUE, local = new.env())
}

cat("\nAll scripts finished. Tables are in output/tables, charts in output/figures.\n")
sink()
close(log_file)
options(old_width)
