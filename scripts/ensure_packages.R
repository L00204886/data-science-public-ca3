# ============================================================
# Install the R packages required by the analysis when needed.
# Works non-interactively on Windows (without admin rights or
# Rtools) as well as macOS and Linux.
# ============================================================

required_packages <- c(
  "caret", "randomForest", "car", "e1071", "psych"
)

is_dir_writable <- function(path) {
  if (!nzchar(path) || !dir.exists(path)) {
    return(FALSE)
  }
  probe <- file.path(path, paste0(".r_write_test_", Sys.getpid()))
  ok <- tryCatch(
    {
      con <- file(probe, open = "wb")
      close(con)
      unlink(probe)
      TRUE
    },
    error = function(e) FALSE,
    warning = function(w) FALSE
  )
  isTRUE(ok)
}

add_lib_path <- function(lib_dir) {
  if (!nzchar(lib_dir) || !dir.exists(lib_dir)) {
    return(invisible(FALSE))
  }
  norm_dir <- normalizePath(lib_dir, winslash = "/", mustWork = FALSE)
  existing <- normalizePath(.libPaths(), winslash = "/", mustWork = FALSE)
  if (!(norm_dir %in% existing)) {
    .libPaths(c(norm_dir, .libPaths()))
  }
  invisible(TRUE)
}

get_writable_lib <- function() {
  for (lib_dir in .libPaths()) {
    if (is_dir_writable(lib_dir)) {
      return(lib_dir)
    }
  }

  candidates <- c(
    Sys.getenv("R_LIBS_USER", unset = ""),
    file.path(getwd(), ".r-library")
  )
  candidates <- candidates[nzchar(candidates)]

  for (lib_dir in candidates) {
    if (!dir.exists(lib_dir)) {
      dir.create(lib_dir, recursive = TRUE, showWarnings = FALSE)
    }
    if (is_dir_writable(lib_dir)) {
      add_lib_path(lib_dir)
      return(normalizePath(lib_dir, winslash = "/", mustWork = FALSE))
    }
  }

  stop(
    "Could not find or create a writable R package library. ",
    "Tried: ", paste(c(.libPaths(), candidates), collapse = ", "),
    call. = FALSE
  )
}

ensure_required_packages <- function() {
  # Include existing personal/project library directories before checking packages
  add_lib_path(Sys.getenv("R_LIBS_USER", unset = ""))
  add_lib_path(file.path(getwd(), ".r-library"))

  is_installed <- vapply(
    required_packages,
    requireNamespace,
    logical(1),
    quietly = TRUE
  )
  missing_packages <- required_packages[!is_installed]

  if (length(missing_packages) > 0) {
    target_lib <- get_writable_lib()
    cat(
      "\nInstalling missing R packages into", target_lib, ":\n ",
      paste(missing_packages, collapse = ", "),
      "\n"
    )

    old_opts <- options(install.packages.compile.from.source = "never")
    on.exit(options(old_opts), add = TRUE)

    pkg_type <- if (.Platform$OS.type == "windows") "binary" else getOption("pkgType")

    install.packages(
      missing_packages,
      lib = target_lib,
      repos = "https://cloud.r-project.org",
      dependencies = NA,
      type = pkg_type
    )

    # On Windows, fall back once to "both" (never compiling C/C++ from source)
    # in case a pure-R package only has a source tarball for a brand-new R release.
    if (.Platform$OS.type == "windows") {
      remaining <- required_packages[
        !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
      ]
      if (length(remaining) > 0) {
        install.packages(
          remaining,
          lib = target_lib,
          repos = "https://cloud.r-project.org",
          dependencies = NA,
          type = "both"
        )
      }
    }
  }

  still_missing <- required_packages[
    !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(still_missing) > 0) {
    stop(
      "The following R packages could not be installed: ",
      paste(still_missing, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}

ensure_required_packages()
