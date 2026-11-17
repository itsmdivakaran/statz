# Installs every R package StatNext needs for development and CI.
# The desktop app does the same on first launch (src-tauri/src/setup.rs).
pkgs <- c(
  "jsonlite", "glue", "effectsize", "car", "rsvg", "readxl", "haven", "arrow", "testthat", "S7", "ggplot2",
  "lme4", "lmerTest", "emmeans", "psych", "MASS", "nnet", "survival"
)
if (is.null(getOption("repos")) || identical(unname(getOption("repos")["CRAN"]), "@CRAN@"))
  options(repos = c(CRAN = "https://cloud.r-project.org"))
need <- setdiff(pkgs, rownames(installed.packages()))
if (length(need)) install.packages(need)
if (!requireNamespace("ggnext", quietly = TRUE)) {
  try(install.packages("ggnext"), silent = TRUE)
  if (!requireNamespace("ggnext", quietly = TRUE)) {
    if (!requireNamespace("remotes", quietly = TRUE)) install.packages("remotes")
    remotes::install_github("itsmdivakaran/ggnext", upgrade = "never")
  }
}
missing <- setdiff(c(pkgs, "ggnext"), rownames(installed.packages()))
if (length(missing)) stop("Could not install: ", paste(missing, collapse = ", "))
cat("All R packages installed.\n")
