# ROC curve analysis (pROC)

codegen_roc <- function(o, meta, ctx) {
  y <- o$outcome; m <- o$markers; e <- ctx$plot_engine
  cl <- sn_lit(o$conf_level)
  dir <- c(auto = "auto", higher = "<", lower = ">")[[o$direction]]
  lev <- if (o$event_level == "first") paste0("rev(levels(", sn_ref("d", y), "))") else paste0("levels(", sn_ref("d", y), ")")
  code <- sn_code(
    if (o$plot != "none") sn_libs(e),
    "",
    paste0("# ROC analysis of ", paste(m, collapse = ", "), " for ", y),
    sn_prep_code("d", ctx$data, c(y, m), meta, factors = y),
    paste0("markers <- ", sn_lit(m)),
    paste0("outcome_levels <- ", lev, "   # negative, positive"),
    paste0("roc_list <- lapply(markers, function(m) pROC::roc(", sn_ref("d", y), ", d[[m]], levels = outcome_levels, direction = ", sn_lit(dir), ", quiet = TRUE))"),
    "names(roc_list) <- markers",
    "auc_tbl <- do.call(rbind, lapply(markers, function(m) {",
    "  r <- roc_list[[m]]",
    paste0("  ci <- pROC::ci.auc(r, conf.level = ", cl, ", method = \"delong\")"),
    "  se <- sqrt(pROC::var(r, method = \"delong\"))",
    "  data.frame(marker = m, auc = ci[2], se = se, lower = ci[1], upper = ci[3], z = (ci[2] - 0.5) / se,",
    "             p = 2 * pnorm(abs(ci[2] - 0.5) / se, lower.tail = FALSE), direction = r$direction)",
    "}))",
    if (o$cutoff) c(
      "# Cut-off that maximises the Youden index (sensitivity + specificity - 1)",
      "best <- do.call(rbind, lapply(markers, function(m) {",
      "  b <- pROC::coords(roc_list[[m]], \"best\", best.method = \"youden\", ret = c(\"threshold\", \"sensitivity\", \"specificity\", \"ppv\", \"npv\"))[1, ]",
      "  data.frame(marker = m, b, youden = b$sensitivity + b$specificity - 1)",
      "}))"),
    if (o$coords) c(
      "coords_tbl <- do.call(rbind, lapply(markers, function(m)",
      "  data.frame(marker = m, pROC::coords(roc_list[[m]], \"all\", ret = c(\"threshold\", \"sensitivity\", \"specificity\")))))",
      "coords_tbl <- coords_tbl[is.finite(coords_tbl$threshold), ]"),
    if (o$compare && length(m) > 1) c(
      "# DeLong test for each pair of correlated ROC curves",
      "pairs <- t(combn(markers, 2))",
      "comparison <- do.call(rbind, lapply(seq_len(nrow(pairs)), function(i) {",
      "  rt <- pROC::roc.test(roc_list[[pairs[i, 1]]], roc_list[[pairs[i, 2]]], method = \"delong\", paired = TRUE)",
      "  data.frame(marker1 = pairs[i, 1], marker2 = pairs[i, 2], difference = unname(rt$estimate[1] - rt$estimate[2]), z = unname(rt$statistic), p = rt$p.value)",
      "}))"),
    if (o$plot == "roc") {
      if (e == "ggnext") c(
        "# Long format; markers where lower values indicate a positive outcome are reversed",
        "roc_long <- do.call(rbind, lapply(markers, function(m) data.frame(marker = m, truth = as.integer(", paste0(sn_ref("d", y), " == outcome_levels[2]),"),
        "  score = if (roc_list[[m]]$direction == \">\") -d[[m]] else d[[m]])))",
        sn_gg(e, "roc_long, aes(truth = truth, score = score, color = marker)", "geom_roc()", "ROC curves", "1 − Specificity", "Sensitivity"))
      else c(
        "roc_df <- do.call(rbind, lapply(markers, function(m) {",
        "  r <- roc_list[[m]]",
        "  df <- data.frame(marker = m, fpr = 1 - r$specificities, tpr = r$sensitivities)",
        "  df[order(df$fpr, df$tpr), ]",
        "}))",
        sn_gg(e, "roc_df, aes(fpr, tpr, color = marker)", c("geom_path()", sn_ref_line(e, "ab", c(0, 1))), "ROC curves", "1 − Specificity", "Sensitivity"))
    }
  )
  list(code = code, assemble = assemble_roc)
}

assemble_roc <- function(env, o, ctx) {
  a <- env$auc_tbl; pct <- sn_pct(o$conf_level)
  r1 <- env$roc_list[[1]]
  rows <- data.frame(marker = a$marker, auc = a$auc, se = a$se, z = a$z, p = a$p,
                     direction = ifelse(a$direction == "<", "Higher = positive", "Lower = positive"), stringsAsFactors = FALSE)
  rows$ci <- I(lapply(seq_len(nrow(a)), function(i) c(a$lower[i], a$upper[i])))
  tables <- list(sn_table("auc", "Area Under the ROC Curve",
    list(sn_col("marker", "Marker", "text"), sn_col("auc", "AUC", digits = 3), sn_col("se", "SE", digits = 3), sn_col("ci", pct, "ci", 3),
         sn_col("z", "z"), sn_col("p", "p", "pvalue"), sn_col("direction", "Direction", "text")),
    rows[, c("marker", "auc", "se", "ci", "z", "p", "direction")],
    notes = c(sprintf("N = %d (%d positive: %s; %d negative: %s).", length(r1$cases) + length(r1$controls), length(r1$cases), env$outcome_levels[2], length(r1$controls), env$outcome_levels[1]),
              "DeLong standard errors and confidence intervals. The z test compares the AUC with 0.5.")))
  b <- sn_get(env, "best")
  if (!is.null(b)) tables <- c(tables, list(sn_table("cutoff", "Optimal Cut-off (Youden Index)",
    list(sn_col("marker", "Marker", "text"), sn_col("threshold", "Cut-off", digits = 3), sn_col("sensitivity", "Sensitivity", digits = 3), sn_col("specificity", "Specificity", digits = 3),
         sn_col("ppv", "PPV", digits = 3), sn_col("npv", "NPV", digits = 3), sn_col("youden", "Youden J", digits = 3)),
    b[, c("marker", "threshold", "sensitivity", "specificity", "ppv", "npv", "youden")],
    notes = "The cut-off is the midpoint between two neighbouring observed values. It is optimistic when applied to the same sample.")))
  cmp <- sn_get(env, "comparison")
  if (!is.null(cmp)) tables <- c(tables, list(sn_table("comparison", "Comparison of AUCs (DeLong)",
    list(sn_col("marker1", "Marker 1", "text"), sn_col("marker2", "Marker 2", "text"), sn_col("difference", "AUC difference", digits = 3), sn_col("z", "z"), sn_col("p", "p", "pvalue")), cmp,
    notes = "Paired test: both markers were measured on the same subjects.")))
  co <- sn_get(env, "coords_tbl")
  if (!is.null(co)) tables <- c(tables, list(sn_table("coords", "Coordinates of the ROC Curve",
    list(sn_col("marker", "Marker", "text"), sn_col("threshold", "Cut-off", digits = 3), sn_col("sensitivity", "Sensitivity", digits = 3), sn_col("specificity", "Specificity", digits = 3)),
    utils::head(co, 500), notes = if (nrow(co) > 500) sprintf("First 500 of %d cut-offs shown.", nrow(co)))))
  top <- a[which.max(a$auc), ]
  grade <- function(x) if (x >= 0.9) "outstanding" else if (x >= 0.8) "excellent" else if (x >= 0.7) "acceptable" else if (x >= 0.6) "poor" else "no better than chance"
  text <- sprintf("%s discriminated %s from %s with an AUC of %s, %s [%s, %s], which is %s discrimination.", top$marker, env$outcome_levels[2], env$outcome_levels[1],
    fmt_num(top$auc, 3), pct, fmt_num(top$lower, 3), fmt_num(top$upper, 3), grade(top$auc))
  if (!is.null(b)) { bb <- b[b$marker == top$marker, ]; text <- paste0(text, sprintf(" The optimal cut-off of %s gave a sensitivity of %.1f%% and a specificity of %.1f%%.", fmt_num(bb$threshold, 3), 100 * bb$sensitivity, 100 * bb$specificity)) }
  if (!is.null(cmp)) text <- paste0(text, sprintf(" The AUCs of %s and %s %s, z = %s, %s.", cmp$marker1[1], cmp$marker2[1], if (cmp$p[1] < 0.05) "differed significantly" else "did not differ significantly", fmt_num(cmp$z[1]), apa_p(cmp$p[1])))
  p <- sn_get(env, "p")
  small <- min(length(r1$cases), length(r1$controls))
  chk <- sn_check("group_size", "Group sizes", if (small < 30) "warn" else "ok",
    if (small < 30) sprintf("The smaller outcome group has only %d subjects; the AUC and cut-off are imprecise.", small) else "Both outcome groups have at least 30 subjects.")
  sn_result(tables = tables, assumptions = list(chk), plots = list(if (!is.null(p)) ctx$plot(p, "ROC curves")), interpretation = text)
}
