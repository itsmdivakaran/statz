# Bayesian binomial test (BayesFactor::proportionBF, logistic prior on the log odds) for each level

codegen_bayes_binomial <- function(o, meta, ctx) {
  v <- o$vars
  iv <- sn_bf_interval(o$alternative, at = sn_lit(o$p0), lo = 0, hi = 1)
  code <- sn_code(
    sn_libs("BayesFactor"), "",
    paste0("# Bayesian binomial test: ", paste(v, collapse = ", "), " against p = ", o$p0),
    paste0("d <- ", ctx$data),
    vapply(v, function(x) sn_factor_code("d", x, meta), ""),
    paste0("rscale <- ", sn_bf_prior(o, "prop"), "   # scale of the logistic prior on the log odds"),
    unlist(lapply(seq_along(v), function(i) {
      s <- sn_suffix(i, length(v))
      c(paste0("counts", s, " <- table(", sn_ref("d", v[i]), ")"),
        paste0("bf", s, " <- lapply(counts", s, ", function(k) proportionBF(y = k, N = sum(counts", s, "), p = ", sn_lit(o$p0),
               ", rscale = rscale", iv, ")", if (nzchar(iv)) "[1]", ")"),
        if (isTRUE(o$posterior)) c(paste0("set.seed(", o$seed, ")"),
          paste0("post", s, " <- lapply(bf", s, ", function(b) as.numeric(posterior(b, iterations = 10000, progress = FALSE)[, \"p\"]))")))
    })))
  list(code = code, assemble = assemble_bayes_binomial)
}

assemble_bayes_binomial <- function(env, o, ctx) {
  lvl <- o$ci_level
  rows <- do.call(rbind, lapply(seq_along(o$vars), function(i) {
    s <- sn_suffix(i, length(o$vars))
    k <- sn_get(env, paste0("counts", s)); bf <- sn_get(env, paste0("bf", s)); post <- sn_get(env, paste0("post", s))
    bf10 <- vapply(bf, function(b) BayesFactor::extractBF(b)$bf[1], 0)
    err <- vapply(bf, function(b) BayesFactor::extractBF(b)$error[1], 0)
    q <- lapply(names(k), function(l) if (is.null(post)) c(NA, NA, NA) else
      unname(stats::quantile(post[[l]], c(0.5, (1 - lvl) / 2, 1 - (1 - lvl) / 2))))
    data.frame(var = o$vars[i], level = names(k), count = as.integer(k), total = sum(k), prop = as.numeric(k) / sum(k),
               bf = sn_bf_show(bf10, o$bf_type), bf10 = bf10, err = sn_bf_error(err), evidence = sn_bf_evidence(bf10),
               med = vapply(q, `[`, 0, 1), cri = I(lapply(q, `[`, 2:3)), row.names = NULL)
  }))
  cols <- c(list(sn_col("var", "Variable", "text"), sn_col("level", "Level", "text"), sn_col("count", "Count", "int"),
                 sn_col("total", "Total", "int"), sn_col("prop", "Proportion", digits = 3),
                 sn_col("bf", sn_bf_label(o$bf_type), "text"), sn_col("err", "Error", "text"), sn_col("evidence", "Evidence", "text")),
            if (isTRUE(o$posterior)) list(sn_col("med", "Median p", digits = 3), sn_col("cri", paste0(round(100 * lvl), "% CrI"), "ci", 3)))
  r <- rows[1, ]
  out <- rows; out$bf10 <- NULL
  if (!isTRUE(o$posterior)) { out$med <- NULL; out$cri <- NULL }
  sn_result(
    tables = list(sn_table("bayes_binomial", "Bayesian Binomial Test", cols, out,
      notes = c(paste0("Tested against a proportion of ", o$p0, ". Prior: logistic on the log odds with scale r = ",
                       fmt_num(sn_bf_prior_value(o, "prop"), 3), "."),
                sn_bf_hyp_note(o$alternative, "the proportion", o$p0), "Evidence labels follow Lee & Wagenmakers (2013)."))),
    interpretation = paste0("For ", r$var, ", the proportion of '", r$level, "' was ", fmt_num(r$prop, 2), " (", r$count, " of ", r$total,
      "). Against a test value of ", o$p0, ", ", sn_bf_sentence(r$bf10, paste("the proportion", switch(o$alternative, greater = "is above", less = "is below", "differs from"), o$p0),
                                                         paste("it equals", o$p0)),
      ": BF₁₀ = ", fmt_bf(r$bf10), ", ", sn_lcfirst(sn_bf_evidence(r$bf10)), ".",
      if (!is.na(r$med)) paste0(" The posterior median proportion is ", fmt_num(r$med, 3), ", ", round(100 * lvl), "% credible interval ",
                                fmt_ci(r$cri[[1]][1], r$cri[[1]][2], 3), ".")))
}
