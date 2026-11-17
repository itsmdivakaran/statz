# Bayesian contingency table test (BayesFactor::contingencyTableBF, Gunel & Dickey Bayes factors)

codegen_bayes_contingency <- function(o, meta, ctx) {
  r <- o$rows; c <- o$cols
  samp <- sub("_(rows|cols)$", "", o$sampling)
  margin <- if (grepl("_rows$", o$sampling)) "rows" else if (grepl("_cols$", o$sampling)) "cols"
  eng <- ctx$plot_engine
  code <- sn_code(
    sn_libs(c("BayesFactor", if (o$plot != "none") eng)), "",
    paste0("# Bayesian contingency table: ", r, " by ", c),
    paste0("d <- subset(", ctx$data, ", !is.na(", sn_name(r), ") & !is.na(", sn_name(c), "))"),
    sn_factor_code("d", r, meta), sn_factor_code("d", c, meta),
    paste0("tab <- table(", sn_ref("d", r), ", ", sn_ref("d", c), ", dnn = ", sn_lit(c(r, c)), ")"),
    paste0("bf <- contingencyTableBF(tab, sampleType = ", sn_lit(samp),
           if (!is.null(margin)) paste0(", fixedMargin = ", sn_lit(margin)), ", priorConcentration = ", sn_lit(o$prior_a), ")"),
    "bf10 <- extractBF(bf)$bf",
    if (isTRUE(o$expected)) "expected <- outer(rowSums(tab), colSums(tab)) / sum(tab)",
    if (isTRUE(o$posterior) && samp != "poisson") sn_code(
      "# Posterior log odds ratio (2 x 2 tables): from the posterior cell probabilities",
      "if (all(dim(tab) == 2)) {",
      paste0("  set.seed(", o$seed, ")"),
      "  post <- posterior(bf, iterations = 10000, progress = FALSE)",
      "  cell <- function(i, j) as.numeric(post[, paste0(\"pi[\", i, \",\", j, \"]\")])",
      "  log_or <- log(cell(1, 1)) + log(cell(2, 2)) - log(cell(1, 2)) - log(cell(2, 1))",
      "}"),
    sn_plot_code(eng, o$plot, "d", x = r, fill = c, title = paste(r, "by", c), obj = "p", xlab = sn_label(meta, r)))
  list(code = code, assemble = assemble_bayes_contingency)
}

assemble_bayes_contingency <- function(env, o, ctx) {
  tab <- sn_get(env, "tab")
  bf10 <- sn_get(env, "bf10")
  err <- BayesFactor::extractBF(sn_get(env, "bf"))$error
  ex <- sn_get(env, "expected")
  counts <- as.data.frame.matrix(tab)
  ct <- data.frame(row = rownames(tab), counts, total = rowSums(tab), check.names = FALSE)
  ct <- rbind(ct, data.frame(row = "Total", as.list(colSums(tab)), total = sum(tab), check.names = FALSE))
  cols <- c(list(sn_col("row", o$rows, "text")),
            lapply(colnames(tab), function(k) sn_col(k, k, "int")), list(sn_col("total", "Total", "int")))
  tables <- list(sn_table("counts", paste("Contingency Table:", o$rows, "×", o$cols), cols, ct))
  if (!is.null(ex)) {
    e <- data.frame(row = rownames(tab), as.data.frame.matrix(ex), check.names = FALSE)
    tables[[2]] <- sn_table("expected", "Expected Counts", c(list(sn_col("row", o$rows, "text")),
      lapply(colnames(tab), function(k) sn_col(k, k))), e)
  }
  lvl <- o$ci_level
  lor <- sn_get(env, "log_or")
  q <- if (!is.null(lor)) stats::quantile(lor, c(0.5, (1 - lvl) / 2, 1 - (1 - lvl) / 2))
  samp_label <- c(jointMulti = "joint multinomial (total fixed)", indepMulti_rows = "independent multinomial (row totals fixed)",
                  indepMulti_cols = "independent multinomial (column totals fixed)", poisson = "Poisson (nothing fixed)")[[o$sampling]]
  main <- data.frame(test = "Independence", n = sum(tab), bf = sn_bf_show(bf10, o$bf_type), err = sn_bf_error(err),
                     evidence = sn_bf_evidence(bf10))
  mcols <- list(sn_col("test", "Hypothesis H₀", "text"), sn_col("n", "N", "int"), sn_col("bf", sn_bf_label(o$bf_type), "text"),
                sn_col("err", "Error", "text"), sn_col("evidence", "Evidence", "text"))
  if (!is.null(q)) {
    main$med <- unname(q[1]); main$cri <- I(list(unname(q[2:3])))
    mcols <- c(mcols, list(sn_col("med", "Median log OR", digits = 3), sn_col("cri", paste0(round(100 * lvl), "% CrI"), "ci", digits = 3)))
  }
  tables[[length(tables) + 1L]] <- sn_table("bayes_contingency", "Bayesian Contingency Table Test", mcols, main,
    notes = c(paste0("Sampling plan: ", samp_label, ". Prior concentration a = ", fmt_num(o$prior_a), "."),
              "BF₁₀ compares association (H₁) with independence (H₀) (Gunel & Dickey, 1974).",
              if (!is.null(q)) "Log odds ratio = log(n11 · n22 / n12 · n21) on the posterior cell probabilities."))
  p <- sn_get(env, "p")
  sn_result(tables = tables, plots = if (!is.null(p)) list(ctx$plot(p, paste(o$rows, "by", o$cols))),
    interpretation = paste0("A Bayesian test of association between ", o$rows, " and ", o$cols, " (", samp_label, ") found that ",
      sn_bf_sentence(bf10, "the variables are associated", "they are independent"), ": BF₁₀ = ", fmt_bf(bf10), ", ",
      sn_lcfirst(sn_bf_evidence(bf10)), ".",
      if (!is.null(q)) paste0(" The posterior median log odds ratio is ", fmt_num(q[1]), ", ", round(100 * lvl),
                              "% credible interval ", fmt_ci(q[2], q[3]), " (odds ratio ", fmt_num(exp(q[1])), ").")))
}
