# Code + table helpers shared by modules ------------------------------------------

#' Per-group descriptives in base R.
sn_group_desc_code <- function(obj, df, dv, group) {
  paste0(obj, " <- aggregate(", sn_name(dv), " ~ ", sn_name(group), ", data = ", df,
         ", FUN = function(x)\n  c(n = length(x), mean = mean(x), sd = sd(x), se = sd(x) / sqrt(length(x))))")
}

#' Rows for a group descriptives table from one or more aggregate() results.
#' @param items list of list(var = name, obj = aggregate result)
sn_tbl_group_desc <- function(items, id = "descriptives", title = "Group Descriptives") {
  rows <- do.call(rbind, lapply(items, function(it) {
    a <- it$obj
    m <- a[[ncol(a)]]
    data.frame(var = it$var, group = as.character(a[[1]]), n = as.integer(m[, "n"]),
               mean = m[, "mean"], sd = m[, "sd"], se = m[, "se"])
  }))
  sn_table(id, title, list(
    sn_col("var", "Variable", "text"), sn_col("group", "Group", "text"),
    sn_col("n", "N", "int"), sn_col("mean", "Mean"), sn_col("sd", "SD"), sn_col("se", "SE")
  ), rows)
}

#' Shapiro-Wilk per group: `obj` is the tapply() result.
sn_normality_code <- function(obj, df, dv, group = NULL) {
  if (is.null(group)) return(paste0(obj, " <- shapiro.test(", sn_ref(df, dv), ")"))
  paste0(obj, " <- tapply(", sn_ref(df, dv), ", ", sn_ref(df, group), ", shapiro.test)")
}

#' @param items list of list(var, obj) where obj is a list of htest (per group) or one htest.
sn_chk_normality <- function(items, alpha = 0.05) {
  rows <- do.call(rbind, lapply(items, function(it) {
    tests <- if (inherits(it$obj, "htest")) list(All = it$obj) else it$obj
    data.frame(var = it$var, group = names(tests),
               W = vapply(tests, function(t) unname(t$statistic), 0),
               p = vapply(tests, function(t) t$p.value, 0))
  }))
  bad <- rows$p < alpha
  sn_check("normality", "Shapiro-Wilk", if (any(bad)) "warn" else "ok",
    if (any(bad)) paste0("Normality is doubtful for ", paste(unique(ifelse(rows$group[bad] == "All", rows$var[bad],
                                                                      paste(rows$var[bad], rows$group[bad]))), collapse = ", "),
                         ". Consider the non-parametric test or check the Q-Q plot.")
    else "No evidence against normality.",
    sn_table("normality", "Test of Normality (Shapiro-Wilk)", list(
      sn_col("var", "Variable", "text"), sn_col("group", "Group", "text"),
      sn_col("W", "W", digits = 3), sn_col("p", "p", "pvalue")), rows))
}

sn_levene_code <- function(obj, df, dv, group) {
  paste0(obj, " <- leveneTest(", sn_name(dv), " ~ ", sn_name(group), ", data = ", df, ", center = median)")
}

#' @param items list of list(var, obj) with obj a car::leveneTest result.
#' @param welch whether the robust (Welch) test is already selected.
sn_chk_levene <- function(items, welch = TRUE, alpha = 0.05) {
  rows <- do.call(rbind, lapply(items, function(it) {
    a <- it$obj
    data.frame(var = it$var, F = a[["F value"]][1], df1 = a[["Df"]][1], df2 = a[["Df"]][2],
               p = a[["Pr(>F)"]][1])
  }))
  bad <- rows$p < alpha
  msg <- if (!any(bad)) "No evidence that group variances differ."
    else if (welch) "Group variances may differ; Welch's test (selected) does not assume equal variances."
    else "Group variances may differ; consider Welch's test."
  sn_check("levene", "Levene (median-centred)", if (any(bad)) "warn" else "ok", msg,
    sn_table("levene", "Test of Equality of Variances (Levene)", list(
      sn_col("var", "Variable", "text"), sn_col("F", "F"), sn_col("df1", "df1", "int"),
      sn_col("df2", "df2", "int"), sn_col("p", "p", "pvalue")), rows))
}

#' Object-name suffix: "" for a single variable, "_1", "_2", ... for several.
sn_suffix <- function(i, n) if (n == 1L) "" else paste0("_", i)

#' Value or NA when an object is absent from the evaluated environment.
sn_get <- function(env, name) get0(name, envir = env, inherits = FALSE)
