# Descriptive statistics and frequency tables

SN_DESC_STATS <- c(
  n = "n = length(v)",
  missing = "missing = sum(is.na(x))",
  mean = "mean = mean(v)",
  sd = "sd = sd(v)",
  se = "se = sd(v) / sqrt(length(v))",
  median = "median = median(v)",
  iqr = "iqr = IQR(v)",
  min = "min = min(v)",
  max = "max = max(v)",
  skewness = "skewness = length(v) / ((length(v) - 1) * (length(v) - 2)) * sum(((v - mean(v)) / sd(v))^3)",
  kurtosis = paste0("kurtosis = { n <- length(v); n * (n + 1) / ((n - 1) * (n - 2) * (n - 3)) * ",
                    "sum(((v - mean(v)) / sd(v))^4) - 3 * (n - 1)^2 / ((n - 2) * (n - 3)) }")
)

codegen_descriptives <- function(o, meta, ctx) {
  measures <- vapply(o$vars, function(v) meta$variables[[v]]$measure, "")
  num <- o$vars[measures == "continuous"]
  cat <- o$vars[measures %in% c("nominal", "ordinal")]
  sp <- if (length(o$split)) o$split[[1]]
  stats <- o$stats
  num_sel <- paste0("d[", sn_lit(num), "]")
  code <- sn_code(
    sn_libs(if (o$plot != "none" && length(num)) ctx$plot_engine),
    "",
    "# Descriptive statistics",
    paste0("d <- ", ctx$data),
    if (!is.null(sp)) sn_factor_code("d", sp, meta),
    vapply(cat, function(v) sn_factor_code("d", v, meta), ""),
    if (length(num) && length(stats)) sn_code(
      paste0("desc_stats <- function(x) {\n  v <- x[!is.na(x)]\n  c(",
             paste(SN_DESC_STATS[stats], collapse = ",\n    "), ")\n}"),
      if (is.null(sp)) paste0("desc <- sapply(", if (length(num) == 1) paste0("d[", sn_lit(num), "]") else num_sel,
                              ", desc_stats)")
      else paste0("desc <- lapply(split(", num_sel, ", ", sn_ref("d", sp), "), function(g) sapply(g, desc_stats))")
    ),
    if (o$normality && length(num)) {
      if (is.null(sp)) paste0("normality <- lapply(", num_sel, ", function(x) shapiro.test(x[!is.na(x)]))")
      else paste0("normality <- lapply(split(", num_sel, ", ", sn_ref("d", sp),
                  "), function(g) lapply(g, function(x) shapiro.test(x[!is.na(x)])))")
    },
    if (o$frequencies && length(cat)) paste0("freq <- lapply(d[", sn_lit(cat), "], table, useNA = \"ifany\")"),
    if (o$plot != "none" && length(num)) paste(vapply(seq_along(num), function(i) {
      v <- num[i]
      type <- o$plot
      if (type == "box_jitter" && is.null(sp)) return(sn_code(
        paste0("p_", i, " <- ", ctx$plot_engine, "(d, aes(x = \"\", y = ", sn_name(v), ")) +\n  geom_boxplot() +\n  ",
               "geom_jitter(width = 0.1, alpha = 0.6) +\n  labs(title = ", sn_lit(v), ", x = NULL, y = ",
               sn_lit(sn_label(meta, v)), ") +\n  ", sn_plot_theme(ctx$plot_engine))))
      if (type == "box_jitter") return(sn_plot_code(ctx$plot_engine, type, "d", x = sp, y = v, obj = paste0("p_", i),
                                                    xlab = sn_label(meta, sp), ylab = sn_label(meta, v)))
      sn_plot_code(ctx$plot_engine, type, "d", x = v, obj = paste0("p_", i), title = v, xlab = sn_label(meta, v))
    }, ""), collapse = "\n")
  )
  list(code = code, assemble = function(env, o2, ctx2) assemble_descriptives(env, o2, ctx2, num, cat, sp))
}

assemble_descriptives <- function(env, o, ctx, num, cat, sp) {
  tables <- list()
  labels <- c(n = "N", missing = "Missing", mean = "Mean", sd = "SD", se = "SE", median = "Median",
              iqr = "IQR", min = "Minimum", max = "Maximum", skewness = "Skewness", kurtosis = "Kurtosis")
  desc <- sn_get(env, "desc")
  if (!is.null(desc)) {
    to_rows <- function(m, grp = NULL) {
      m <- as.matrix(m)
      df <- as.data.frame(t(m), optional = TRUE)
      out <- data.frame(var = colnames(m))
      if (!is.null(grp)) out$group <- grp
      cbind(out, df)
    }
    rows <- if (is.null(sp)) to_rows(desc) else do.call(rbind, Map(to_rows, desc, names(desc)))
    rows <- rows[order(match(rows$var, num)), , drop = FALSE]
    rownames(rows) <- NULL
    cols <- c(list(sn_col("var", "Variable", "text")), if (!is.null(sp)) list(sn_col("group", sp, "text")),
              lapply(o$stats, function(s) sn_col(s, labels[[s]], if (s %in% c("n", "missing")) "int" else "number",
                                                  if (s %in% c("skewness", "kurtosis")) 3 else 2)))
    for (s in intersect(c("n", "missing"), o$stats)) rows[[s]] <- as.integer(rows[[s]])
    tables$desc <- sn_table("descriptives", "Descriptive Statistics", cols, rows)
  }
  freq <- sn_get(env, "freq")
  for (v in names(freq)) {
    tb <- freq[[v]]
    lv <- ifelse(is.na(names(tb)), "Missing", names(tb))
    n <- as.integer(tb); valid <- !is.na(names(tb))
    pct <- 100 * n / sum(n)
    vpct <- ifelse(valid, 100 * n / sum(n[valid]), NA)
    tables[[paste0("freq_", v)]] <- sn_table(paste0("freq_", v), paste("Frequencies:", v), list(
      sn_col("level", "Level", "text"), sn_col("n", "Count", "int"), sn_col("pct", "%", digits = 1),
      sn_col("vpct", "Valid %", digits = 1), sn_col("cum", "Cumulative %", digits = 1)),
      data.frame(level = lv, n = n, pct = pct, vpct = vpct, cum = ifelse(valid, cumsum(ifelse(valid, vpct, 0)), NA)))
  }
  norm <- sn_get(env, "normality")
  chk <- if (!is.null(norm)) {
    items <- if (is.null(sp)) lapply(names(norm), function(v) list(var = v, obj = list(All = norm[[v]])))
      else unlist(lapply(names(norm), function(g) lapply(names(norm[[g]]), function(v)
        list(var = v, obj = stats::setNames(list(norm[[g]][[v]]), g)))), recursive = FALSE)
    sn_chk_normality(items)
  }
  plots <- lapply(seq_along(num), function(i) {
    p <- sn_get(env, paste0("p_", i))
    if (!is.null(p)) ctx$plot(p, num[i])
  })
  sn_result(tables = unname(tables), assumptions = list(chk), plots = plots)
}
