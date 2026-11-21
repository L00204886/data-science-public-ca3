# ============================================================
# CA3 Predictive Modelling - Airline passenger satisfaction
# Master runner: execute Scripts 01 to 05 in sequence and record
#                every section and result in output/run_log.txt
# Author: Eamon Foy (L00204886)
# Usage (from project root): Rscript scripts/run_all.R
# Reads:  scripts/01_data_preparation.R ... scripts/05_compare_and_forecast.R
# Writes: output/run_log.txt (plus all tables, figures and saved models)
# ============================================================

# Resolve paths relative to the project root when called with Rscript
# from another working directory.
command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)
if (length(file_argument) > 0) {
  script_path <- normalizePath(sub("^--file=", "", file_argument[[1]]))
  setwd(dirname(dirname(script_path)))
}

if (!file.exists("data/airline_passenger_satisfaction.csv")) {
  stop(
    "Could not find data/airline_passenger_satisfaction.csv from the current ",
    "working directory (", getwd(), "). Please run from the project root folder ",
    "(or open ca3.Rproj in RStudio).",
    call. = FALSE
  )
}

source("scripts/ensure_packages.R")

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
# Always restore sink() and options() even if a script raises an error.
tryCatch(
  {
    for (s in scripts) {
      cat("\n============================================================\n")
      cat("Running", s, "\n")
      cat("============================================================\n")
      source(s, echo = FALSE, print.eval = TRUE, local = new.env())
    }

    cat("\nAll scripts finished. Tables are in output/tables, charts in output/figures.\n")
  },
  finally = {
    if (sink.number() > 0) sink()
    if (isOpen(log_file)) close(log_file)
    options(old_width)
  }
)
