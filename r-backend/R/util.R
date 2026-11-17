# Errors -----------------------------------------------------------------------

#' JSON-RPC error codes shared with the Rust shell (src-tauri/src/rpc.rs).
SN_ERR <- list(
  r_error = -32001L,
  missing_package = -32002L,
  invalid_options = -32003L,
  cancelled = -32004L,
  not_found = -32601L,
  invalid_params = -32602L
)

sn_abort <- function(message, code = SN_ERR$r_error, hint = NULL, data = NULL) {
  cond <- structure(
    class = c("sn_error", "error", "condition"),
    list(message = message, call = NULL, code = code, hint = hint, data = data)
  )
  stop(cond)
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# Code generation helpers ------------------------------------------------------

#' Quote a variable name for use in a formula or as a bare symbol.
sn_name <- function(x) {
  ifelse(make.names(x) == x, x, paste0("`", gsub("`", "\\\\`", x), "`"))
}

#' Reference a column of a data frame object in generated code: d$x or d[["x y"]].
sn_ref <- function(df, x) {
  ifelse(make.names(x) == x, paste0(df, "$", x), paste0(df, "[[", sn_lit(x), "]]"))
}

#' Deparse an R value as a code literal ("a", 1.5, TRUE, c(...)).
sn_lit <- function(x) {
  if (is.null(x)) return("NULL")
  if (length(x) == 1L) return(paste(deparse(unname(x), width.cutoff = 500L), collapse = ""))
  paste0("c(", paste(vapply(x, sn_lit, ""), collapse = ", "), ")")
}

sn_libs <- function(pkgs) paste0("library(", pkgs, ")")

#' Code that turns a grouping variable into a labelled factor.
#' Uses the value labels from variable metadata when present.
sn_factor_code <- function(df, var, meta) {
  vm <- meta$variables[[var]]
  ref <- sn_ref(df, var)
  vl <- vm$value_labels
  if (length(vl) > 0) {
    vals <- vapply(vl, function(v) as.numeric(v$value), numeric(1))
    labs <- vapply(vl, function(v) v$label, character(1))
    return(paste0(ref, " <- factor(", ref, ", levels = ", sn_lit(vals),
                  ", labels = ", sn_lit(labs), ")"))
  }
  paste0(ref, " <- droplevels(factor(", ref, "))")
}

#' Join code fragments, dropping NULLs.
sn_code <- function(...) {
  parts <- unlist(list(...), use.names = FALSE)
  paste(parts[!is.na(parts) & nzchar(parts)], collapse = "\n")
}

# APA formatting ---------------------------------------------------------------

fmt_p <- function(p) {
  ifelse(is.na(p), "",
    ifelse(p < 0.001, "< .001", sub("^0\\.", ".", sprintf("%.3f", p))))
}

fmt_num <- function(x, digits = 2) {
  out <- formatC(round(x, digits), format = "f", digits = digits)
  out <- sub("^-", "−", out)
  ifelse(is.na(x), "", out)
}

fmt_ci <- function(lo, hi, digits = 2) paste0("[", fmt_num(lo, digits), ", ", fmt_num(hi, digits), "]")

#' "p = .012" or "p < .001" for running text.
apa_p <- function(p) {
  f <- fmt_p(p)
  ifelse(startsWith(f, "<"), paste0("p ", f), paste0("p = ", f))
}

effect_label_d <- function(d) {
  a <- abs(d)
  if (is.na(a)) return("")
  if (a < 0.2) "a negligible" else if (a < 0.5) "a small" else if (a < 0.8) "a medium" else "a large"
}

#' Variable label from metadata, or the name when unlabelled.
sn_label <- function(meta, var) {
  if (is.null(var)) return(NULL)
  l <- meta$variables[[var]]$label
  if (is.null(l) || !nzchar(l)) var else l
}
