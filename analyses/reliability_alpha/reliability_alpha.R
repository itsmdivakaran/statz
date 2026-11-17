# Cronbach's alpha with Feldt confidence interval and item statistics

codegen_reliability_alpha <- function(o, meta, ctx) {
  it <- o$items; rv <- o$reverse
  code <- sn_code(
    paste0("# Scale reliability for ", length(it), " items"),
    paste0("items <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", sn_lit(it), "]), ", sn_lit(it), "]"),
    "items[] <- lapply(items, as.numeric)",
    if (length(rv)) c(
      "# Reverse-score: new value = (lowest + highest observed value) - old value",
      paste0("for (v in ", sn_lit(rv), ") items[[v]] <- min(items[[v]]) + max(items[[v]]) - items[[v]]")),
    "k <- ncol(items); n <- nrow(items)",
    "total <- rowSums(items)",
    "alpha <- k / (k - 1) * (1 - sum(apply(items, 2, var)) / var(total))",
    "r <- cor(items)",
    "mean_r <- mean(r[lower.tri(r)])",
    "alpha_std <- k * mean_r / (1 + (k - 1) * mean_r)",
    "# Feldt confidence interval",
    paste0("alpha_ci <- 1 - (1 - alpha) * qf(c(", sn_lit(1 - (1 - o$conf_level) / 2), ", ", sn_lit((1 - o$conf_level) / 2), "), n - 1, (n - 1) * (k - 1))"),
    if (o$item_stats) c(
      "alpha_without <- function(x) ncol(x) / (ncol(x) - 1) * (1 - sum(apply(x, 2, var)) / var(rowSums(x)))",
      "item_stats <- data.frame(",
      "  item = names(items), mean = colMeans(items), sd = apply(items, 2, sd),",
      "  item_rest = sapply(seq_len(k), function(i) cor(items[[i]], total - items[[i]])),",
      "  alpha_if_dropped = if (k > 2) sapply(seq_len(k), function(i) alpha_without(items[-i])) else NA)")
  )
  list(code = code, assemble = assemble_reliability_alpha)
}

assemble_reliability_alpha <- function(env, o, ctx) {
  a <- env$alpha
  rows <- data.frame(alpha = a, std = env$alpha_std, mean_r = env$mean_r, k = as.integer(env$k), n = as.integer(env$n))
  rows$ci <- I(list(env$alpha_ci))
  tables <- list(sn_table("reliability", "Scale Reliability", list(sn_col("alpha", "Cronbach's α", digits = 3), sn_col("ci", sn_pct(o$conf_level), "ci", 3),
    sn_col("std", "Standardized α", digits = 3), sn_col("mean_r", "Mean inter-item r", digits = 3), sn_col("k", "Items", "int"), sn_col("n", "N", "int")),
    rows[, c("alpha", "ci", "std", "mean_r", "k", "n")],
    notes = if (length(o$reverse)) paste0("Reverse-scored: ", paste(o$reverse, collapse = ", "), ".")))
  checks <- list()
  is <- sn_get(env, "item_stats")
  if (!is.null(is)) {
    tables <- c(tables, list(sn_table("items", "Item Statistics", list(sn_col("item", "Item", "text"), sn_col("mean", "Mean"), sn_col("sd", "SD"),
      sn_col("item_rest", "Item-rest r", digits = 3), sn_col("alpha_if_dropped", "α if item dropped", digits = 3)), data.frame(is, row.names = NULL))))
    neg <- is$item[is$item_rest < 0]; low <- is$item[is$item_rest >= 0 & is$item_rest < 0.3]
    checks <- list(sn_check("item_rest", "Item-rest correlations", if (length(neg) || length(low)) "warn" else "ok",
      if (length(neg)) paste0("Negative item-rest correlation for ", paste(neg, collapse = ", "), ". The item may need reverse scoring.")
      else if (length(low)) paste0("Weak item-rest correlation (below .30) for ", paste(low, collapse = ", "), ".")
      else "Every item correlates at least .30 with the rest of the scale."))
  }
  lab <- if (a >= 0.9) "excellent" else if (a >= 0.8) "good" else if (a >= 0.7) "acceptable" else if (a >= 0.6) "questionable" else "poor"
  text <- paste0("Internal consistency of the ", env$k, "-item scale was ", lab, ", Cronbach's α = ", fmt_num(a), ", ", sn_pct(o$conf_level), " ",
                 fmt_ci(env$alpha_ci[1], env$alpha_ci[2]), " (N = ", env$n, ").")
  sn_result(tables = tables, assumptions = checks, interpretation = text)
}
