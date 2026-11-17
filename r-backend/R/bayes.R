# Bayesian analyses (BayesFactor) ------------------------------------------------
# Shared helpers: prior widths, directional hypotheses, Bayes factor display and
# evidence labels, and the t-test family (one-sample, paired, independent).

#' Prior scale as an R expression. Each family has its own named widths (BayesFactor defaults).
sn_bf_prior <- function(o, family = c("t", "cor", "prop", "anova", "reg")) {
  family <- match.arg(family)
  if (identical(o$prior, "custom")) return(sn_lit(o$prior_r))
  w <- list(t = c(medium = "sqrt(2) / 2", wide = "1", ultrawide = "sqrt(2)"),
            cor = c(medium = "1 / 3", wide = "1 / sqrt(3)", ultrawide = "1"),
            prop = c(medium = "0.5", wide = "sqrt(2) / 2", ultrawide = "1"),
            anova = c(medium = "0.5", wide = "sqrt(2) / 2", ultrawide = "1"),
            reg = c(medium = "sqrt(2) / 4", wide = "0.5", ultrawide = "sqrt(2) / 2"))[[family]]
  w[[o$prior %||% "medium"]]
}

#' Numeric value of the prior scale (for notes and interpretation).
sn_bf_prior_value <- function(o, family = "t") eval(parse(text = sn_bf_prior(o, family)))

#' `, nullInterval = c(lo, hi)` for a one-sided hypothesis, empty for two-sided.
sn_bf_interval <- function(alt, at = 0, lo = -Inf, hi = Inf) {
  switch(alt %||% "two.sided",
         greater = paste0(", nullInterval = c(", at, ", ", hi, ")"),
         less = paste0(", nullInterval = c(", lo, ", ", at, ")"),
         "")
}

#' Bayes factor as text: 3 significant digits, scientific when very large or small.
fmt_bf <- function(x) {
  vapply(x, function(v) {
    if (is.na(v)) return("")
    if (!is.finite(v)) return(if (v > 0) "∞" else "0")
    if (abs(v) >= 1e4 || (abs(v) < 1e-3 && v != 0)) {
      s <- formatC(v, format = "e", digits = 2)
      parts <- regmatches(s, regexec("^(.*)e\\+?(-?)0*(\\d+)$", s))[[1]]
      sup <- chartr("-0123456789", "\u207b\u2070\u00b9\u00b2\u00b3\u2074\u2075\u2076\u2077\u2078\u2079", paste0(parts[3], parts[4]))
      return(paste0(parts[2], " \u00d7 10", sup))
    }
    sub("\\.$", "", formatC(signif(v, 3), format = "fg", digits = 3, flag = "#"))
  }, "")
}

#' Evidence category (Lee & Wagenmakers, 2013, after Jeffreys, 1961).
sn_bf_evidence <- function(bf10) {
  vapply(bf10, function(b) {
    if (is.na(b)) return("")
    k <- if (b >= 1) b else 1 / b
    side <- if (b >= 1) "H₁" else "H₀"
    lab <- if (k > 100) "Extreme" else if (k > 30) "Very strong" else if (k > 10) "Strong"
           else if (k > 3) "Moderate" else if (k > 1) "Anecdotal" else return("No evidence either way")
    paste0(lab, " evidence for ", side)
  }, "")
}

#' Column label and display values for the chosen Bayes factor form.
sn_bf_label <- function(type) switch(type %||% "bf10", bf01 = "BF₀₁", log_bf10 = "log(BF₁₀)", "BF₁₀")
sn_bf_show <- function(bf10, type) {
  switch(type %||% "bf10", bf01 = fmt_bf(1 / bf10), log_bf10 = fmt_num(log(bf10), 2), fmt_bf(bf10))
}
sn_bf_error <- function(err) ifelse(is.na(err), "", ifelse(err < 1e-5, "< 0.001%", paste0(signif(100 * err, 2), "%")))

#' Plain-language sentence for a Bayes factor.
sn_bf_sentence <- function(bf10, h1, h0) {
  if (is.na(bf10)) return("")
  if (bf10 >= 1) paste0("the data are ", fmt_bf(bf10), " times more likely under H₁ (", h1,
                        ") than under H₀ (", h0, ")")
  else paste0("the data are ", fmt_bf(1 / bf10), " times more likely under H₀ (", h0,
              ") than under H₁ (", h1, ")")
}

sn_bf_hyp_note <- function(alt, what = "effect size δ", at = 0) {
  switch(alt %||% "two.sided",
         greater = paste0("One-sided test: H₁ says ", what, " > ", at, "."),
         less = paste0("One-sided test: H₁ says ", what, " < ", at, "."),
         NULL)
}

# T-test family ------------------------------------------------------------------

#' Code for one Bayesian t-test. `bf_call(data, r)` returns the ttestBF() call as text;
#' `min_ok(data)` an R condition that the first k rows can be tested (sequential plot).
sn_bayes_t_code <- function(o, ctx, s, prep, bf_call, min_ok, title) {
  r <- sn_bf_prior(o, "t")
  alt <- o$alternative
  plots <- unlist(o$plots)
  eng <- ctx$plot_engine
  truncate <- switch(alt %||% "two.sided", greater = " * 2 * (grid >= 0)", less = " * 2 * (grid <= 0)", "")
  sn_code(
    prep,
    paste0("rscale", s, " <- ", r, "   # Cauchy prior width on the effect size delta"),
    paste0("bf", s, " <- ", bf_call(paste0("d", s), paste0("rscale", s)), if (nzchar(sn_bf_interval(alt))) "[1]"),
    paste0("bf10", s, " <- extractBF(bf", s, ")$bf"),
    if (isTRUE(o$posterior) || "prior_posterior" %in% plots) sn_code(
      paste0("set.seed(", o$seed, ")"),
      paste0("delta", s, " <- as.numeric(posterior(bf", s, ", iterations = 10000, progress = FALSE)[, \"delta\"])")),
    if ("prior_posterior" %in% plots) sn_code(
      "# Prior and posterior density of delta",
      paste0("grid <- seq(min(-2, quantile(delta", s, ", 0.001)), max(2, quantile(delta", s, ", 0.999)), length.out = 400)"),
      paste0("dens <- density(delta", s, ")"),
      paste0("pp", s, " <- rbind(\n  data.frame(delta = grid, density = approx(dens$x, dens$y, grid, yleft = 0, yright = 0)$y, Distribution = \"Posterior\"),\n",
             "  data.frame(delta = grid, density = dcauchy(grid, 0, rscale", s, ")", truncate, ", Distribution = \"Prior\"))"),
      sn_gg(eng, paste0("pp", s, ", aes(delta, density, color = Distribution)"),
            c("geom_line()", sn_ref_line(eng, "v", 0)),
            paste0("Prior and posterior: ", title), "Effect size (δ)", "Density", paste0("p_pp", s))),
    if ("robustness" %in% plots) sn_code(
      "# Robustness check: the Bayes factor across prior widths",
      paste0("rob", s, " <- data.frame(r = seq(0.05, 1.5, by = 0.05))"),
      paste0("rob", s, "$bf10 <- sapply(rob", s, "$r, function(r) extractBF(", bf_call(paste0("d", s), "r"), ")$bf[1])"),
      paste0("rob_user", s, " <- data.frame(r = rscale", s, ", bf10 = bf10", s, ")"),
      sn_gg(eng, paste0("rob", s, ", aes(r, log10(bf10))"),
            c("geom_line()", paste0("geom_point(data = rob_user", s, ", size = 3)"), sn_ref_line(eng, "h", 0)),
            paste0("Bayes factor robustness: ", title), "Prior width (r)", "log10(BF₁₀)", paste0("p_rob", s))),
    if ("sequential" %in% plots) sn_code(
      "# Sequential analysis: the Bayes factor as the data accumulate (in row order)",
      paste0("seq_n <- unique(round(seq(3, nrow(d", s, "), length.out = min(60, nrow(d", s, ") - 2))))"),
      paste0("sq", s, " <- data.frame(n = seq_n, bf10 = sapply(seq_n, function(k) {\n  dk <- d", s, "[seq_len(k), , drop = FALSE]\n",
             "  if (!(", min_ok("dk"), ")) return(NA_real_)\n  extractBF(", bf_call("dk", paste0("rscale", s)), ")$bf[1]\n}))"),
      paste0("sq", s, " <- sq", s, "[!is.na(sq", s, "$bf10), ]"),
      sn_gg(eng, paste0("sq", s, ", aes(n, log10(bf10))"), c("geom_line()", "geom_point(size = 1.5)", sn_ref_line(eng, "h", 0)),
            paste0("Sequential analysis: ", title), "n", "log10(BF₁₀)", paste0("p_seq", s)))
  )
}

#' Rows of the Bayesian t-test table and the plots, for items list(label=, s=, desc=).
sn_bayes_t_assemble <- function(env, o, ctx, items, title, h1, h0, desc_table = NULL, desc_note = NULL) {
  rows <- list(); plots <- list(); txt <- character()
  lvl <- o$ci_level %||% 0.95
  for (it in items) {
    s <- it$s
    bf10 <- sn_get(env, paste0("bf10", s))
    err <- extractBF_error(sn_get(env, paste0("bf", s)))
    delta <- sn_get(env, paste0("delta", s))
    q <- if (!is.null(delta) && isTRUE(o$posterior)) stats::quantile(delta, c(0.5, (1 - lvl) / 2, 1 - (1 - lvl) / 2)) else c(NA, NA, NA)
    rows[[length(rows) + 1L]] <- data.frame(
      var = it$label, bf = sn_bf_show(bf10, o$bf_type), err = sn_bf_error(err),
      evidence = sn_bf_evidence(bf10), med = unname(q[1]), cri = I(list(unname(q[2:3]))))
    for (k in c("pp", "rob", "seq")) {
      p <- sn_get(env, paste0("p_", k, s))
      if (!is.null(p)) plots[[length(plots) + 1L]] <- ctx$plot(p, paste0(
        c(pp = "Prior and posterior", rob = "Bayes factor robustness", seq = "Sequential analysis")[[k]], ": ", it$label))
    }
    txt <- c(txt, paste0("For ", it$label, ", ", sn_bf_sentence(bf10, h1(it), h0(it)), ": BF₁₀ = ", fmt_bf(bf10),
      ", ", sn_lcfirst(sn_bf_evidence(bf10)), ".",
      if (!is.na(q[1])) paste0(" The posterior median effect size is δ = ", fmt_num(q[1]), ", ",
                                round(100 * lvl), "% credible interval ", fmt_ci(q[2], q[3]), ".")))
  }
  cri <- paste0(round(100 * lvl), "% CrI")
  r <- sn_bf_prior_value(o, "t")
  main <- sn_table("bayes_ttest", title, c(
    list(sn_col("var", "Variable", "text"), sn_col("bf", sn_bf_label(o$bf_type), "text"),
         sn_col("err", "Error", "text"), sn_col("evidence", "Evidence", "text")),
    if (isTRUE(o$posterior)) list(sn_col("med", "Median δ"), sn_col("cri", cri, "ci"))),
    do.call(rbind, rows),
    notes = c(paste0("Prior: Cauchy on effect size δ with scale r = ", fmt_num(r, 3), "."),
              sn_bf_hyp_note(o$alternative),
              "Evidence labels follow Lee & Wagenmakers (2013)."))
  if (!isTRUE(o$posterior)) main$rows$med <- NULL
  if (!isTRUE(o$posterior)) main$rows$cri <- NULL
  intro <- paste0("A ", title, " used a Cauchy prior with scale r = ", fmt_num(r, 3), " on the standardized effect size.")
  sn_result(tables = c(list(desc_table), list(main)), plots = plots,
            interpretation = paste(c(intro, txt), collapse = "\n\n"))
}

extractBF_error <- function(bf) if (is.null(bf)) NA_real_ else BayesFactor::extractBF(bf)$error[1]

#' Code: data frame `models` of every model in BayesFactor object `bf` plus the null model,
#' with BF10 against the null and the posterior model probability under equal prior odds.
sn_bf_models_code <- function(bf = "bf") {
  sn_code(
    paste0("x <- extractBF(", bf, ")"),
    "models <- data.frame(model = c(\"Null model\", rownames(x)), bf10 = c(1, x$bf), error = c(NA, x$error))",
    "models$p_post <- models$bf10 / sum(models$bf10)   # P(M|data), all models equally likely a priori",
    "models <- models[order(-models$bf10), ]")
}

#' Adds P(M), BF_M and BF against the best model to `models`.
sn_bf_models <- function(d, top = Inf) {
  d$prior <- 1 / nrow(d)
  d$post <- d$p_post
  d$bfm <- (d$post / (1 - d$post)) / (d$prior / (1 - d$prior))
  d$vs_best <- d$bf10 / d$bf10[1]
  d$err <- d$error
  utils::head(d, top)
}

sn_tbl_bf_models <- function(d, title = "Model Comparison", notes = NULL) {
  rows <- data.frame(model = d$model, prior = d$prior, post = d$post, bfm = fmt_bf(d$bfm),
                     bf10 = fmt_bf(d$bf10), best = fmt_bf(d$vs_best), err = sn_bf_error(d$err))
  sn_table("models", title, list(
    sn_col("model", "Model", "text"), sn_col("prior", "P(M)", digits = 3), sn_col("post", "P(M|data)", digits = 3),
    sn_col("bfm", "BFₘ", "text"), sn_col("bf10", "BF₁₀ vs null", "text"),
    sn_col("best", "BF vs best", "text"), sn_col("err", "Error", "text")),
    rows, notes = c("All models have equal prior probability. BFₘ = posterior odds / prior odds of the model.", notes))
}

sn_tbl_bf_inclusion <- function(inc) {
  rows <- data.frame(effect = rownames(inc), prior = inc$p_prior, post = inc$p_posterior,
                     bf = fmt_bf(exp(inc$log_BF)))
  sn_table("inclusion", "Analysis of Effects (model averaged)", list(
    sn_col("effect", "Effect", "text"), sn_col("prior", "P(incl)", digits = 3),
    sn_col("post", "P(incl|data)", digits = 3), sn_col("bf", "BF inclusion", "text")),
    rows, notes = "BF inclusion compares all models with the effect against all models without it (bayestestR::bayesfactor_inclusion).")
}

#' Posterior summary table from an mcmc object: mean, SD, credible interval.
sn_tbl_posterior <- function(post, lvl = 0.95, keep = NULL, title = "Posterior Summary", labels = NULL) {
  m <- as.matrix(post)
  if (!is.null(keep)) m <- m[, intersect(keep, colnames(m)), drop = FALSE]
  a <- (1 - lvl) / 2
  par <- gsub(".&.", " \u00d7 ", colnames(m), fixed = TRUE)
  if (!is.null(labels)) par <- ifelse(par %in% names(labels), unname(labels[par]), par)
  rows <- data.frame(par = par,
                     mean = colMeans(m), sd = apply(m, 2, stats::sd),
                     cri = I(lapply(seq_len(ncol(m)), function(j) unname(stats::quantile(m[, j], c(a, 1 - a))))))
  sn_table("posterior", title, list(sn_col("par", "Parameter", "text"), sn_col("mean", "Mean", digits = 3),
    sn_col("sd", "SD", digits = 3), sn_col("cri", paste0(round(100 * lvl), "% CrI"), "ci", digits = 3)),
    rows, notes = "Summaries of posterior samples (MCMC).")
}

#' Descriptives table from a data frame with variable, n, mean, sd.
sn_tbl_simple_desc <- function(d) {
  sn_table("descriptives", "Descriptives", list(sn_col("variable", "Variable", "text"), sn_col("n", "N", "int"),
    sn_col("mean", "Mean"), sn_col("sd", "SD")), d)
}

sn_lcfirst <- function(x) paste0(tolower(substr(x, 1, 1)), substring(x, 2))
