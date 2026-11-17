# Repeated measures / mixed ANOVA from wide data via a multivariate lm() + car::Anova()

codegen_anova_rm <- function(o, meta, ctx) {
  m <- o$measures; b <- o$between
  w <- make.names(if (nzchar(trimws(o$within_name))) trimws(o$within_name) else "Time")
  need_long <- o$posthoc != "none" || o$plot != "none"
  g <- if (length(b)) b[1]
  code <- sn_code(
    sn_libs(c("car", if (o$plot != "none") ctx$plot_engine)),
    "",
    paste0("# Repeated measures ANOVA: ", paste(m, collapse = ", "), if (length(b)) paste0(" by ", paste(b, collapse = ", "))),
    sn_prep_code("d", ctx$data, c(m, b), meta),
    paste0("measures <- ", sn_lit(m)),
    if (o$descriptives) paste0("desc <- sapply(d[measures], function(v) c(n = length(v), mean = mean(v), sd = sd(v)))"),
    paste0("within <- data.frame(", w, " = factor(measures, levels = measures))"),
    paste0("fit <- lm(cbind(", paste(sn_name(m), collapse = ", "), ") ~ ", if (length(b)) paste(sn_name(b), collapse = " * ") else "1", ", data = d",
           if (length(b)) paste0(",\n  contrasts = list(", paste0(sn_name(b), " = contr.sum", collapse = ", "), ")"), ")"),
    paste0("rm_anova <- Anova(fit, idata = within, idesign = ~", w, ", type = 3)"),
    "rm_summary <- summary(rm_anova, multivariate = FALSE)",
    if (need_long) paste0("long <- data.frame(", w, " = factor(rep(measures, each = nrow(d)), levels = measures), value = unlist(d[measures], use.names = FALSE)",
                          if (!is.null(g)) paste0(",\n  ", sn_name(g), " = rep(", sn_ref("d", g), ", times = length(measures))"), ")"),
    if (o$posthoc != "none") paste0("posthoc <- pairwise.t.test(long$value, long$", w, ", paired = TRUE, p.adjust.method = ", sn_lit(o$posthoc), ")"),
    if (o$plot != "none") c(
      paste0("cells <- aggregate(value ~ ", paste(c(w, if (!is.null(g)) sn_name(g)), collapse = " + "), ", data = long, FUN = function(v)\n",
             "  c(mean = mean(v), half = qt(0.975, length(v) - 1) * sd(v) / sqrt(length(v))))"),
      paste0("cells <- data.frame(cells[", sn_lit(c(w, g)), "], mean = cells$value[, \"mean\"],\n",
             "  lower = cells$value[, \"mean\"] - cells$value[, \"half\"], upper = cells$value[, \"mean\"] + cells$value[, \"half\"])"),
      sn_gg(ctx$plot_engine,
            paste0("cells, aes(", w, ", mean", if (!is.null(g)) paste0(", color = ", sn_name(g), ", group = ", sn_name(g)) else ", group = 1", ")"),
            c("geom_line()", "geom_point()", "geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.1)"),
            paste("Means by", w), w, "Mean", "p"))
  )
  list(code = code, assemble = function(env, o, ctx) assemble_anova_rm(env, o, ctx, w))
}

assemble_anova_rm <- function(env, o, ctx, w) {
  s <- env$rm_summary
  u <- unclass(s$univariate.tests)
  u <- u[rownames(u) != "(Intercept)", , drop = FALSE]
  adj <- s$pval.adjustments; sph <- s$sphericity.tests
  has_adj <- length(adj) > 0 && nrow(adj) > 0
  within_row <- grepl(w, rownames(u), fixed = TRUE)
  rows <- data.frame(source = rownames(u), ss = u[, "Sum Sq"], df1 = u[, "num Df"], ss_err = u[, "Error SS"], df2 = u[, "den Df"],
                     F = u[, "F value"], p = u[, "Pr(>F)"], row.names = NULL)
  rows$type <- ifelse(within_row, "Within subjects", "Between subjects")
  cols <- list(sn_col("type", "Effect type", "text"), sn_col("source", "Source", "text"), sn_col("ss", "Sum of squares"), sn_col("df1", "df", "int"),
               sn_col("ss_err", "Error SS"), sn_col("df2", "Error df", "int"), sn_col("F", "F"), sn_col("p", "p", "pvalue"))
  rows$df1 <- as.integer(rows$df1); rows$df2 <- as.integer(rows$df2)
  if (has_adj) {
    idx <- match(rows$source, rownames(adj))
    rows$p_gg <- adj[idx, "Pr(>F[GG])"]; rows$p_hf <- adj[idx, "Pr(>F[HF])"]
    cols <- c(cols, list(sn_col("p_gg", "p (Greenhouse-Geisser)", "pvalue"), sn_col("p_hf", "p (Huynh-Feldt)", "pvalue")))
  }
  if (o$effect_size) { rows$eta <- rows$ss / (rows$ss + rows$ss_err); cols <- c(cols, list(sn_col("eta", "η²p", digits = 3))) }
  rows <- rows[order(rows$type != "Within subjects"), vapply(cols, function(c) c$id, ""), drop = FALSE]
  tables <- list()
  if (o$descriptives) {
    m <- t(env$desc)
    tables$desc <- sn_table("descriptives", "Descriptives", list(sn_col("var", "Measurement", "text"), sn_col("n", "N", "int"),
      sn_col("mean", "Mean"), sn_col("sd", "SD")), data.frame(var = rownames(m), n = as.integer(m[, "n"]), mean = m[, "mean"], sd = m[, "sd"], row.names = NULL))
  }
  tables$anova <- sn_table("anova", "Repeated Measures ANOVA", cols, rows, notes = "Type III sums of squares.")
  if (has_adj) tables$eps <- sn_table("epsilon", "Sphericity Corrections", list(sn_col("source", "Source", "text"),
    sn_col("gg", "Greenhouse-Geisser ε", digits = 3), sn_col("hf", "Huynh-Feldt ε", digits = 3)),
    data.frame(source = rownames(adj), gg = adj[, "GG eps"], hf = pmin(adj[, "HF eps"], 1), row.names = NULL))
  ph <- sn_get(env, "posthoc")
  if (!is.null(ph)) {
    pv <- ph$p.value; idx <- which(!is.na(pv), arr.ind = TRUE)
    tables$posthoc <- sn_table("posthoc", paste0("Pairwise Comparisons: ", w, " (", tools::toTitleCase(o$posthoc), ")"),
      list(sn_col("comparison", "Comparison", "text"), sn_col("p", "p (adjusted)", "pvalue")),
      data.frame(comparison = paste(rownames(pv)[idx[, 1]], "−", colnames(pv)[idx[, 2]]), p = pv[idx], row.names = NULL),
      notes = "Paired t-tests.")
  }
  checks <- list()
  if (length(sph) > 0 && nrow(sph) > 0) {
    bad <- sph[, "p-value"] < 0.05
    checks$sph <- sn_check("sphericity", "Mauchly's test of sphericity", if (any(bad)) "warn" else "ok",
      if (any(bad)) "Sphericity is violated; report the Greenhouse-Geisser or Huynh-Feldt corrected p-value." else "No evidence against sphericity.",
      sn_table("sphericity", "Mauchly's Test of Sphericity", list(sn_col("source", "Source", "text"), sn_col("w", "Mauchly's W", digits = 3), sn_col("p", "p", "pvalue")),
               data.frame(source = rownames(sph), w = sph[, "Test statistic"], p = sph[, "p-value"], row.names = NULL)))
  }
  main <- rows[rows$source == w, ]
  pm <- if (has_adj && length(checks) && checks$sph$status == "warn") main$p_gg else main$p
  text <- paste0("The within-subject effect of ", w, " was ", if (pm < 0.05) "" else "not ", "significant, F(", main$df1, ", ", main$df2, ") = ",
    fmt_num(main$F), ", ", apa_p(pm), if (has_adj && length(checks) && checks$sph$status == "warn") " (Greenhouse-Geisser corrected)",
    if (o$effect_size) paste0(", η²p = ", fmt_num(main$eta, 2)), ".")
  p <- sn_get(env, "p")
  sn_result(tables = unname(tables), assumptions = unname(checks),
            plots = list(if (!is.null(p)) ctx$plot(p, paste("Means by", w))), interpretation = text)
}
