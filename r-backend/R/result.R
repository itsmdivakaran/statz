# Standard result object -------------------------------------------------------
# Shape is defined by schemas/result.schema.json; keep both in sync.

sn_col <- function(id, label = id, type = c("number", "int", "text", "pvalue", "ci"),
                   digits = 2L) {
  type <- match.arg(type)
  col <- list(id = id, label = label, type = type)
  if (type %in% c("number", "ci")) col$digits <- as.integer(digits)
  col
}

#' @param rows data.frame; "ci" columns are list-columns of length-2 numerics.
sn_table <- function(id, title, columns, rows, notes = character()) {
  stopifnot(is.data.frame(rows))
  list(id = id, title = title, columns = columns, rows = rows, notes = as.list(notes))
}

#' @param status "ok", "warn" or "fail".
sn_check <- function(id, test, status = c("ok", "warn", "fail"), message = NULL,
                     table = NULL) {
  list(id = id, test = test, status = match.arg(status), message = message, table = table)
}

sn_result <- function(tables = list(), assumptions = list(), plots = list(),
                      interpretation = NULL, notes = character()) {
  structure(
    list(
      tables = unname(Filter(Negate(is.null), tables)),
      assumptions = unname(Filter(Negate(is.null), assumptions)),
      plots = unname(Filter(Negate(is.null), plots)),
      interpretation = if (!is.null(interpretation))
        list(auto_generated = TRUE, text = interpretation),
      notes = as.list(notes)
    ),
    class = "sn_result"
  )
}

sn_to_json <- function(x, pretty = FALSE) {
  jsonlite::toJSON(unclass_deep(x), auto_unbox = TRUE, dataframe = "rows",
                   null = "null", na = "null", digits = NA, pretty = pretty,
                   force = TRUE)
}

unclass_deep <- function(x) {
  if (is.data.frame(x)) return(x)
  if (is.list(x)) {
    attrs <- attributes(x)
    x <- lapply(unclass(x), unclass_deep)
    if (!is.null(attrs$names)) names(x) <- attrs$names
    return(x)
  }
  x
}
