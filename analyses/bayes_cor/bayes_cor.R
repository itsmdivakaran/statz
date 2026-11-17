# Bayesian correlation (BayesFactor::correlationBF, stretched beta prior on rho)

codegen_bayes_cor <- function(o, meta, ctx) {
  v <- unlist(o$vars)
  pairs <- utils::combn(v, 2, simplify = FALSE)
  iv <- sn_bf_interval(o$alternative, lo = -1, hi = 1)
  eng <- ctx$plot_engine
  blocks <- lapply(seq_along(pairs), function(i) {
    a <- pairs[[i]][1]; b <- pairs[[i]][2]
    s <- paste0("_", i)
    sn_code(
      paste0("# ", a, " and ", b),
      paste0("d", s, " <- ", ctx$data, "[complete.cases(", ctx$data, "[, ", sn_lit(c(a, b)), "]), ", sn_lit(c(a, b)), "]"),
      paste0("bf", s, " <- correlationBF(", sn_ref(paste0("d", s), a), ", ", sn_ref(paste0("d", s), b), ", rscale = rscale", iv, ")",
             if (nzchar(iv)) "[1]"),
      if (isTRUE(o$posterior) || (i == 1 && o$plot == "prior_posterior")) sn_code(
        paste0("set.seed(", o$seed, ")"),
        paste0("rho", s, " <- as.numeric(posterior(bf", s, ", iterations = 10000, progress = FALSE)[, \"rho\"])")))
  })
  a <- v[1]; b <- v[2]
  trunc <- switch(o$alternative, greater = " * 2 * (grid >= 0)", less = " * 2 * (grid <= 0)", "")
  plot <- switch(o$plot,
    scatter = sn_gg(eng, paste0("d_1, aes(", sn_name(a), ", ", sn_name(b), ")"), c("geom_point(alpha = 0.8)", "geom_smooth(method = \"lm\")"),
                    paste(a, "and", b), sn_label(meta, a), sn_label(meta, b), "p"),
    prior_posterior = sn_code(
      "# Prior (stretched beta) and posterior density of rho for the first pair",
      "grid <- seq(-0.999, 0.999, length.out = 400)",
      "dens <- density(rho_1, from = -1, to = 1)",
      paste0("pp <- rbind(\n  data.frame(rho = grid, density = approx(dens$x, dens$y, grid)$y, Distribution = \"Posterior\"),\n",
             "  data.frame(rho = grid, density = dbeta((grid + 1) / 2, 1 / rscale, 1 / rscale) / 2", trunc, ", Distribution = \"Prior\"))"),
      sn_gg(eng, "pp, aes(rho, density, color = Distribution)", c("geom_line()", sn_ref_line(eng, "v", 0)),
            paste("Prior and posterior:", a, "and", b), "Correlation (ρ)", "Density", "p")),
    NULL)
  list(code = sn_code(sn_libs(c("BayesFactor", if (o$plot != "none") eng)), "",
                      paste0("rscale <- ", sn_bf_prior(o, "cor"), "   # width of the stretched beta prior on rho"), "",
                      paste(unlist(blocks), collapse = "\n\n"), if (!is.null(plot)) c("", plot)),
       assemble = assemble_bayes_cor)
}

assemble_bayes_cor <- function(env, o, ctx) {
  v <- unlist(o$vars)
  pairs <- utils::combn(v, 2, simplify = FALSE)
  lvl <- o$ci_level
  rows <- list(); txt <- character()
  for (i in seq_along(pairs)) {
    s <- paste0("_", i)
    d <- sn_get(env, paste0("d", s))
    bf10 <- BayesFactor::extractBF(sn_get(env, paste0("bf", s)))$bf[1]
    err <- BayesFactor::extractBF(sn_get(env, paste0("bf", s)))$error[1]
    r <- stats::cor(d[[1]], d[[2]])
    rho <- sn_get(env, paste0("rho", s))
    q <- if (isTRUE(o$posterior) && !is.null(rho)) stats::quantile(rho, c(0.5, (1 - lvl) / 2, 1 - (1 - lvl) / 2)) else c(NA, NA, NA)
    rows[[i]] <- data.frame(pair = paste(pairs[[i]], collapse = " – "), n = nrow(d), r = r,
      bf = sn_bf_show(bf10, o$bf_type), err = sn_bf_error(err), evidence = sn_bf_evidence(bf10),
      med = unname(q[1]), cri = I(list(unname(q[2:3]))))
    txt <- c(txt, paste0(pairs[[i]][1], " and ", pairs[[i]][2], " (r = ", fmt_num(r), ", n = ", nrow(d), "): BF₁₀ = ",
                         fmt_bf(bf10), ", ", sn_lcfirst(sn_bf_evidence(bf10)), "."))
  }
  cols <- c(list(sn_col("pair", "Pair", "text"), sn_col("n", "n", "int"), sn_col("r", "Pearson r", digits = 3),
                 sn_col("bf", sn_bf_label(o$bf_type), "text"), sn_col("err", "Error", "text"), sn_col("evidence", "Evidence", "text")),
            if (isTRUE(o$posterior)) list(sn_col("med", "Median ρ", digits = 3), sn_col("cri", paste0(round(100 * lvl), "% CrI"), "ci", digits = 3)))
  rows <- do.call(rbind, rows)
  if (!isTRUE(o$posterior)) { rows$med <- NULL; rows$cri <- NULL }
  p <- sn_get(env, "p")
  sn_result(
    tables = list(sn_table("bayes_cor", "Bayesian Pearson Correlations", cols, rows,
      notes = c(paste0("Prior: stretched beta on ρ with width ", fmt_num(sn_bf_prior_value(o, "cor"), 3), "."),
                sn_bf_hyp_note(o$alternative, "ρ"), "Evidence labels follow Lee & Wagenmakers (2013)."))),
    plots = if (!is.null(p)) list(ctx$plot(p, if (o$plot == "scatter") "Scatter plot" else "Prior and posterior")),
    interpretation = paste(c("Bayesian correlation tests (Ly, Verhagen & Wagenmakers, 2016):", txt), collapse = "\n\n"))
}
