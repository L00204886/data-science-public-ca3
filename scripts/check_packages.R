# ============================================================
# CA3 Predictive Modelling - Check and install required R packages
# Usage: Rscript scripts/check_packages.R
#        (or on Windows: run.bat --check)
# ============================================================

command_args <- commandArgs(trailingOnly = FALSE)
file_argument <- grep("^--file=", command_args, value = TRUE)
if (length(file_argument) > 0) {
  script_path <- normalizePath(sub("^--file=", "", file_argument[[1]]))
  setwd(dirname(dirname(script_path)))
}

source("scripts/ensure_packages.R")

status <- data.frame(
  package = required_packages,
  installed = vapply(required_packages, requireNamespace, logical(1), quietly = TRUE),
  row.names = NULL
)

print(status, row.names = FALSE)

cat("\nAll required packages are installed.\n")
